(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Server Main Process                                                --- *)
(* -------------------------------------------------------------------------- *)

module Senv = Server_parameters

let option f = function None -> () | Some x -> f x

(* -------------------------------------------------------------------------- *)
(* --- Registry                                                           --- *)
(* -------------------------------------------------------------------------- *)

type kind = [ `GET | `SET | `EXEC ]
let string_of_kind = function `GET -> "GET" | `SET -> "SET" | `EXEC -> "EXEC"
let pp_kind fmt kd = Format.pp_print_string fmt (string_of_kind kd)

let registry = Hashtbl.create 32

let register (kind : kind) request handler =
  if Hashtbl.mem registry request then
    Server_parameters.failure "Request '%s' already registered" request
  else
    Hashtbl.add registry request (kind,handler)

let find request =
  try Some (Hashtbl.find registry request)
  with Not_found -> None

let exec request data = (snd (Hashtbl.find registry request)) data

(* -------------------------------------------------------------------------- *)
(* --- Public API                                                         --- *)
(* -------------------------------------------------------------------------- *)

type json = Json.t

type 'a request = [
  | `Poll
  | `Request of 'a * string * json
  | `Kill of 'a
  | `Shutdown
]

type 'a response = [
  | `Data of 'a * json
  | `Error of 'a * string
  | `Killed of 'a
  | `Rejected of 'a
]

type 'a message = {
  requests : 'a request list ;
  callback : 'a response list -> unit ;
}

(* Private API: *)

type 'a exec = {
  id : 'a ;
  request : string ;
  data : json ;
  handler : json -> json ;
  yield : bool ;
  mutable killed : bool ;
}

type 'a server = {
  polling : int ;
  pretty : Format.formatter -> 'a -> unit ;
  equal : 'a -> 'a -> bool ;
  fetch : unit -> 'a message option ;
  q_in : 'a exec Queue.t ;
  q_out : 'a response Stack.t ;
  mutable daemon : Db.daemon option ;
  mutable shutdown : bool ;
  mutable running : 'a exec option ;
}

exception Killed

(* -------------------------------------------------------------------------- *)
(* --- Debug                                                              --- *)
(* -------------------------------------------------------------------------- *)

let pp_request pp fmt (r : _ request) =
  match r with
  | `Poll -> Format.fprintf fmt "Poll"
  | `Shutdown -> Format.fprintf fmt "Shutdown"
  | `Kill id -> Format.fprintf fmt "Kill %a" pp id
  | `Request(id,request,data) ->
    if Senv.debug_atleast 2 then
      Format.fprintf fmt "@[<hov 2>Request %s:%a@ %a@]"
        request pp id Data.pretty data
    else
      Format.fprintf fmt "Request %s:%a" request pp id

let pp_response pp fmt (r : _ response) =
  match r with
  | `Error(id,err) -> Format.fprintf fmt "Error %a: %s" pp id err
  | `Rejected id -> Format.fprintf fmt "Rejected %a" pp id
  | `Killed id -> Format.fprintf fmt "Killed %a" pp id
  | `Data(id,data) ->
    if Senv.debug_atleast 2 then
      Format.fprintf fmt "@[<hov 2>Response %a@ %a@]"
        pp id Data.pretty data
    else
      Format.fprintf fmt "Response %a" pp id

(* -------------------------------------------------------------------------- *)
(* --- Request Handling                                                   --- *)
(* -------------------------------------------------------------------------- *)

let execute exec : _ response =
  try
    let data = exec.handler exec.data in
    `Data(exec.id,data)
  with
  | Killed -> `Killed exec.id
  | Data.InputError msg -> `Error(exec.id,msg)
  | Sys.Break as exn -> raise exn (* Silently pass the exception *)
  | exn when Cmdline.catch_at_toplevel exn ->
    Senv.warning "[%s] Uncaught exception:@\n%s"
      exec.request (Cmdline.protect exn) ;
    `Error(exec.id,Printexc.to_string exn)


let delayed process =
  if Senv.debug_atleast 1 then
    Some (fun d -> Senv.debug "No yield since %dms during %s" d process)
  else None

let execute_debug server yield exec =
  Senv.debug "Trigger %s:%a" exec.request server.pretty exec.id ;
  Db.with_progress
    ~debounced:server.polling
    ?on_delayed:(delayed exec.request)
    yield execute exec

let reply_debug server resp =
  if Senv.debug_atleast 1 then
    Senv.debug "%a" (pp_response server.pretty) resp ;
  Stack.push resp server.q_out

(* -------------------------------------------------------------------------- *)
(* --- Processing Requests                                                --- *)
(* -------------------------------------------------------------------------- *)

let raise_if_killed = function { killed } -> if killed then raise Killed
let kill_exec e = e.killed <- true
let kill_request eq id e = if eq id e.id then e.killed <- true

let process_request (server : 'a server) (request : 'a request) : unit =
  if Senv.debug_atleast 1 then
    Senv.debug "%a" (pp_request server.pretty) request ;
  match request with
  | `Poll -> ()
  | `Shutdown ->
    begin
      option kill_exec server.running ;
      Queue.clear server.q_in ;
      Stack.clear server.q_out ;
      server.shutdown <- true ;
    end
  | `Kill id ->
    begin
      let kill = kill_request server.equal id in
      Queue.iter kill server.q_in ;
      option kill server.running ;
    end
  | `Request(id,request,data) ->
    begin
      match find request with
      | None -> reply_debug server (`Rejected id)
      | Some( `GET , handler ) ->
        let exec = { id ; request ; handler ; data ;
                     yield = false ; killed = false } in
        reply_debug server (execute exec)
      | Some( `SET , handler ) ->
        let exec = { id ; request ; handler ; data ;
                     yield = false ; killed = false } in
        Queue.push exec server.q_in
      | Some( `EXEC , handler ) ->
        let exec = { id ; request ; handler ; data ;
                     yield = true ; killed = false } in
        Queue.push exec server.q_in
    end

(* -------------------------------------------------------------------------- *)
(* --- Fetching a Bunck of Messages                                       --- *)
(* -------------------------------------------------------------------------- *)

let communicate server =
  match server.fetch () with
  | None -> false
  | Some message ->
    let error =
      try List.iter (process_request server) message.requests ; None
      with exn -> Some exn in (* re-raised after message reply *)
    let pool = ref [] in
    Stack.iter (fun r -> pool := r :: !pool) server.q_out ;
    Stack.clear server.q_out ;
    message.callback !pool ;
    option raise error ; true

(* -------------------------------------------------------------------------- *)
(* --- Yielding                                                           --- *)
(* -------------------------------------------------------------------------- *)

let do_yield server () =
  begin
    option raise_if_killed server.running ;
    ignore ( communicate server );
  end

(* -------------------------------------------------------------------------- *)
(* --- One Step Process                                                   --- *)
(* -------------------------------------------------------------------------- *)

let rec fetch_exec q =
  if Queue.is_empty q then None
  else
    let e = Queue.pop q in
    if e.killed then fetch_exec q else Some e

let process server =
  match fetch_exec server.q_in with
  | None -> communicate server
  | Some exec ->
    server.running <- Some exec ;
    try
      reply_debug server (execute_debug server (do_yield server) exec) ;
      server.running <- None ;
      true
    with exn ->
      server.running <- None ;
      raise exn

(* -------------------------------------------------------------------------- *)
(* --- Server Main Loop                                                   --- *)
(* -------------------------------------------------------------------------- *)

let in_range ~min:a ~max:b v = min (max a v) b

let kill () = raise Killed

let demons = ref []
let on callback = demons := !demons @ [ callback ]
let signal activity =
  List.iter (fun f -> try f activity with _ -> ()) !demons

let create ~pretty ?(equal=(=)) ~fetch () =
  let polling = in_range ~min:1 ~max:200 (Senv.Polling.get ()) in
  {
    fetch ; polling ; equal ; pretty ;
    q_in = Queue.create () ;
    q_out = Stack.create () ;
    daemon = None ;
    running = None ;
    shutdown = false ;
  }

(* -------------------------------------------------------------------------- *)
(* --- Start / Stop                                                       --- *)
(* -------------------------------------------------------------------------- *)

let start server =
  match server.daemon with
  | Some _db -> ()
  | None ->
    begin
      Senv.feedback "Server enabled." ;
      let db = Db.on_progress
          ~debounced:server.polling
          ?on_delayed:(delayed "command line")
          (do_yield server) in
      server.daemon <- Some db ;
      signal true ;
    end

let stop server =
  match server.daemon with
  | None -> ()
  | Some db ->
    begin
      Senv.feedback "Server disabled." ;
      server.daemon <- None ;
      Db.off_progress db ;
      signal false ;
    end

let foreground server =
  match server.daemon with
  | None -> ()
  | Some db ->
    begin
      server.daemon <- None ;
      Db.off_progress db ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Main Loop                                                          --- *)
(* -------------------------------------------------------------------------- *)

let run server =
  try
    ( (* TODO: catch-break to be removed once Why3 signal handler is fixed *)
      Sys.catch_break true
    ) ;
    Senv.feedback "Server running." ;
    foreground server ;
    signal true ;
    begin try
        let idle = float_of_int server.polling /. 1000.0 in
        while not server.shutdown do
          let activity = process server in
          if not activity then
            begin
              Unix.sleepf idle ;
              Db.yield () ;
            end
        done ;
      with Sys.Break -> () (* Ctr+C, just leave the loop normally *)
    end;
    Senv.feedback "Server shutdown." ;
    signal false ;
  with
  | Killed -> ()
  | exn ->
    Senv.feedback "Server interruped (fatal error)." ;
    signal false ;
    raise exn

(* -------------------------------------------------------------------------- *)
