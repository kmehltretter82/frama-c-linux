(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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
  | `SigOn of string
  | `SigOff of string
  | `Shutdown
]

type 'a response = [
  | `Data of 'a * json
  | `Error of 'a * string
  | `Killed of 'a
  | `Signal of string
  | `Rejected of 'a
]

type 'a message = {
  requests : 'a request list ;
  callback : 'a response list -> unit ;
}

(* Private API: *)

type 'a process = {
  id : 'a ;
  request : string ;
  data : json ;
  handler : json -> json ;
  yield : bool ;
  mutable killed : bool ;
}

module Sigs = Set.Make(String)

(* Server with request identifier (RqId) of type ['a] *)
type 'a server = {
  pretty : Format.formatter -> 'a -> unit ; (* RqId printer *)
  equal : 'a -> 'a -> bool ; (* RqId equality *)
  polling : int ; (* server polling, in milliseconds *)
  fetch : unit -> 'a message option ; (* fetch some client message *)
  q_in : 'a process Queue.t ; (* queue of pending jobs *)
  q_out : 'a response Queue.t ; (* queue of pending responses *)
  mutable daemon : Db.daemon option ; (* Db.yield daemon *)
  mutable s_active : Sigs.t ; (* signals the client is listening to *)
  mutable s_signal : Sigs.t ; (* emitted signals since last synchro *)
  mutable shutdown : bool ; (* server has been asked to shut down *)
  mutable running : 'a process option ; (* currently running EXEC request *)
}

exception Killed

(* -------------------------------------------------------------------------- *)
(* --- Debug                                                              --- *)
(* -------------------------------------------------------------------------- *)

let pp_request pp fmt (r : _ request) =
  match r with
  | `Poll -> Format.fprintf fmt "Poll"
  | `Shutdown -> Format.fprintf fmt "Shutdown"
  | `SigOn sg -> Format.fprintf fmt "Signal %S : on" sg
  | `SigOff sg -> Format.fprintf fmt "Signal %S : off" sg
  | `Kill id -> Format.fprintf fmt "Kill [%a]" pp id
  | `Request(id,request,data) ->
    if Senv.debug_atleast 2 then
      Format.fprintf fmt "@[<hov 2>Request [%a] %s@ %a@]"
        pp id request Data.pretty data
    else
      Format.fprintf fmt "Request [%a] %s" pp id request

let pp_process pp fmt (p : _ process) =
  Format.fprintf fmt "Execute %s:%a" p.request pp p.id

let pp_response pp fmt (r : _ response) =
  match r with
  | `Error(id,err) -> Format.fprintf fmt "Error %a: %s" pp id err
  | `Rejected id -> Format.fprintf fmt "Rejected %a" pp id
  | `Killed id -> Format.fprintf fmt "Killed %a" pp id
  | `Signal sg -> Format.fprintf fmt "Signal %S" sg
  | `Data(id,data) ->
    Format.fprintf fmt "@[<hov 2>Replies [%a]@ %a@]" pp id Data.pretty data

(* -------------------------------------------------------------------------- *)
(* --- Request Handling                                                   --- *)
(* -------------------------------------------------------------------------- *)

let run proc : _ response =
  try
    let data = proc.handler proc.data in
    `Data(proc.id,data)
  with
  | Killed -> `Killed proc.id
  | Data.InputError msg -> `Error(proc.id,msg)
  | Sys.Break as exn -> raise exn (* Silently pass the exception *)
  | exn when Cmdline.catch_at_toplevel exn ->
    Senv.warning "[%s] Uncaught exception:@\n%s"
      proc.request (Cmdline.protect exn) ;
    `Error(proc.id,Printexc.to_string exn)

let delayed process =
  if Senv.debug_atleast 1 then
    Some (fun d -> Senv.debug "No yield since %dms during %s" d process)
  else None

let execute server ?yield proc =
  Senv.debug ~level:2 "%a" (pp_process server.pretty) proc ;
  let resp = match yield with
    | Some yield when proc.yield ->
      Db.with_progress
        ~debounced:server.polling
        ?on_delayed:(delayed proc.request)
        yield run proc
    | _ -> run proc
  in
  Senv.debug ~level:2 "%a" (pp_response server.pretty) resp ;
  Queue.push resp server.q_out

(* -------------------------------------------------------------------------- *)
(* --- Signals                                                            --- *)
(* -------------------------------------------------------------------------- *)

type signal = string
let signal_name s = s
let signals = Hashtbl.create 32
let signal s =
  if Hashtbl.mem signals s then
    ( Server_parameters.failure "Signal '%s' already registered" s ; "" )
  else
    ( Hashtbl.add signals s [] ; s )

let () = Hashtbl.add signals "" []

let on_signal s callback =
  let ds = Hashtbl.find signals s in
  Hashtbl.replace signals s (callback :: ds)

let notify s a =
  match Hashtbl.find signals s with
  | ds -> List.iter (fun f -> f a) ds
  | exception Not_found -> ()

let nop _s = ()
let emitter = ref nop
let emit s = !emitter s

(* -------------------------------------------------------------------------- *)
(* --- Processing Requests                                                --- *)
(* -------------------------------------------------------------------------- *)

let raise_if_killed = function { killed } -> if killed then raise Killed
let kill_exec e = e.killed <- true
let kill_request eq id e = if eq id e.id then e.killed <- true

let process_request (server : 'a server) (request : 'a request) : unit =
  if Senv.debug_atleast 1 && (Senv.debug_atleast 3 || request <> `Poll) then
    Senv.debug "%a" (pp_request server.pretty) request ;
  match request with
  | `Poll -> ()
  | `Shutdown ->
    begin
      Option.iter kill_exec server.running ;
      Queue.clear server.q_in ;
      Queue.clear server.q_out ;
      server.shutdown <- true ;
    end
  | `SigOn sg ->
    begin
      server.s_active <- Sigs.add sg server.s_active ;
      notify sg true ;
    end
  | `SigOff sg ->
    begin
      server.s_active <- Sigs.remove sg server.s_active ;
      notify sg false ;
    end
  | `Kill id ->
    begin
      let set_killed = kill_request server.equal id in
      Queue.iter set_killed server.q_in ;
      Option.iter set_killed server.running ;
    end
  | `Request(id,request,data) ->
    begin
      match find request with
      | None ->
        Senv.debug "Rejected %a" server.pretty id ;
        Queue.push (`Rejected id) server.q_out
      | Some( `GET , handler ) ->
        let proc = { id ; request ; handler ; data ;
                     yield = false ; killed = false } in
        execute server proc ;
      | Some( `SET , handler ) ->
        let proc = { id ; request ; handler ; data ;
                     yield = false ; killed = false } in
        Queue.push proc server.q_in
      | Some( `EXEC , handler ) ->
        let proc = { id ; request ; handler ; data ;
                     yield = true ; killed = false } in
        Queue.push proc server.q_in
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
    Queue.iter (fun r -> pool := r :: !pool) server.q_out ;
    Queue.clear server.q_out ;
    server.s_signal <- Sigs.empty ;
    message.callback !pool ;
    Option.iter raise error ; true

(* -------------------------------------------------------------------------- *)
(* --- Yielding & Signaling                                               --- *)
(* -------------------------------------------------------------------------- *)

let do_yield server () =
  Option.iter raise_if_killed server.running ;
  ignore ( communicate server )

let do_signal server s =
  if Sigs.mem s server.s_active && not (Sigs.mem s server.s_signal) then
    begin
      server.s_signal <- Sigs.add s server.s_signal ;
      Queue.push (`Signal s) server.q_out ;
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
  | Some proc ->
    server.running <- Some proc ;
    try
      execute server ~yield:(do_yield server) proc ;
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

let daemons = ref []
let on callback = daemons := !daemons @ [ callback ]
let set_active activity =
  List.iter (fun f -> try f activity with _ -> ()) !daemons

let create ~pretty ?(equal=(=)) ~fetch () =
  let polling = in_range ~min:1 ~max:200 (Senv.Polling.get ()) in
  {
    fetch ; polling ; equal ; pretty ;
    q_in = Queue.create () ;
    q_out = Queue.create () ;
    s_active = Sigs.empty ;
    s_signal = Sigs.empty ;
    daemon = None ;
    running = None ;
    shutdown = false ;
  }

(* -------------------------------------------------------------------------- *)
(* --- Start / Stop                                                       --- *)
(* -------------------------------------------------------------------------- *)

let start server =
  emitter := do_signal server ;
  match server.daemon with
  | Some _ -> ()
  | None ->
    begin
      Senv.feedback "Server enabled." ;
      let daemon =
        Db.on_progress
          ~debounced:server.polling
          ?on_delayed:(delayed "command line")
          (do_yield server)
      in
      server.daemon <- Some daemon ;
      set_active true ;
    end

let stop server =
  emitter := nop ;
  match server.daemon with
  | None -> ()
  | Some daemon ->
    begin
      Senv.feedback "Server disabled." ;
      server.daemon <- None ;
      Db.off_progress daemon ;
      set_active false ;
    end

let foreground server =
  emitter := do_signal server ;
  match server.daemon with
  | None -> ()
  | Some daemon ->
    begin
      server.daemon <- None ;
      Db.off_progress daemon ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Main Loop                                                          --- *)
(* -------------------------------------------------------------------------- *)

let run server =
  try
    ( (* TODO: catch-break to be removed once Why3 signal handler is fixed *)
      Sys.catch_break true
    ) ;
    foreground server ;
    set_active true ;
    Senv.feedback "Server running." ;
    begin
      try
        while not server.shutdown do
          let activity = process server in
          if not activity then Db.sleep server.polling
        done ;
      with Sys.Break -> () (* Ctr+C, just leave the loop normally *)
    end;
    Senv.feedback "Server shutdown." ;
    emitter := nop ;
    set_active false ;
  with exn ->
    Senv.feedback "Server interruped (fatal error)." ;
    emitter := nop ;
    set_active false ;
    raise exn

(* -------------------------------------------------------------------------- *)
