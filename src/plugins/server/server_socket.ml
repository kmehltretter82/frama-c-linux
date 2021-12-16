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
(* --- Socket Server Options                                              --- *)
(* -------------------------------------------------------------------------- *)

module Senv = Server_parameters

let socket_group = Senv.add_group "Protocol Unix Sockets"

let () = Parameter_customize.set_group socket_group
module Socket = Senv.String
    (struct
      let option_name = "-server-socket"
      let arg_name = "url"
      let default = ""
      let help =
        "Launch the UnixSocket server (in background).\n\
         The server can handle GET requests during the\n\
         execution of the frama-c command line.\n\
         Finally, the server is executed until shutdown."
    end)

let _ = Server_doc.protocole
    ~title:"Unix Socket Protocol"
    ~readme:"server_socket.md"

(* -------------------------------------------------------------------------- *)
(* --- Low-level Messages                                                 --- *)
(* -------------------------------------------------------------------------- *)

let buffer_size = 65536

type channel = {
  mutable eof : bool ;
  inc : in_channel ;
  out : out_channel ;
  buffer : Buffer.t ;
}

let feed ch =
  if not ch.eof then
    try Buffer.add_channel ch.buffer ch.inc buffer_size
    with End_of_file -> ch.eof <- true

let read ch =
  try
    Format.printf "READ %S@." (Buffer.contents ch.buffer);
    let h = match Buffer.nth ch.buffer 0 with
      | 'S' -> 3
      | 'L' -> 7
      | 'W' -> 15
      | _ -> raise (Invalid_argument "Server_socket.read")
    in
    let hex = Buffer.sub ch.buffer 1 h in
    let len = int_of_string ("0x" ^ hex) in
    let data = Buffer.sub ch.buffer (1+h) len in
    let p = 1 + h + len in
    let n = Buffer.length ch.buffer - p in
    let rest = Buffer.sub ch.buffer p n in
    Buffer.reset ch.buffer ;
    Buffer.add_string ch.buffer rest ;
    Some data
  with Invalid_argument _ ->
    None

let write ch data =
  begin
    let len = String.length data in
    let hex =
      if len < 0xFFF then Printf.sprintf "S%03x" len else
      if len < 0xFFFFFFF then Printf.sprintf "L%07x" len else
        Printf.sprintf "W%015x" len
    in
    output_string ch.out hex ;
    output_string ch.out data ;
    flush ch.out ;
  end

(* -------------------------------------------------------------------------- *)
(* --- Request Encoding                                                   --- *)
(* -------------------------------------------------------------------------- *)

let jfield fd js = Json.field fd js |> Json.string

let decode (data : string) : string Main.request =
  match data with
  | "POLL" -> `Poll
  | "SHUTDOWN" -> `Shutdown
  | _ ->
    let js = Yojson.Basic.from_string data in
    match jfield "cmd" js with
    | "GET" | "SET" | "EXEC" ->
      let id = jfield "id" js in
      let request = jfield "request" js in
      let data = Json.field "data" js in
      `Request(id,request,data)
    | "SIGON" -> `SigOn (jfield "id" js)
    | "SIGOFF" -> `SigOff (jfield "id" js)
    | "KILL" -> `Kill (jfield "id" js)
    | _ -> raise Not_found

let encode (resp : string Main.response) : string =
  let js =
    match resp with
    | `Data(id,data) -> `Assoc [
        "res", `String "DATA" ;
        "id", `String id ;
        "data", data ]
    | `Error(id,msg) -> `Assoc [
        "res", `String "ERROR" ;
        "id", `String id ;
        "msg", `String msg ]
    | `Killed id -> `Assoc [
        "res", `String "KILLED" ;
        "id", `String id ]
    | `Rejected id -> `Assoc [
        "res", `String "REJECTED" ;
        "id", `String id ]
    | `Signal id -> `Assoc [
        "res", `String "SIGNAL" ;
        "id", `String id ]
  in Yojson.Basic.to_string ~std:false js

let parse ch =
  begin
    feed ch ;
    let rec scan cmds ch =
      match read ch with
      | None -> List.rev cmds
      | Some data ->
        match decode data with
        | cmd -> scan (cmd::cmds) ch
        | exception _ -> scan cmds ch
    in scan [] ch
  end

(* -------------------------------------------------------------------------- *)
(* --- Socket Messages                                                    --- *)
(* -------------------------------------------------------------------------- *)

let callback ch rs =
  List.iter
    (fun r ->
       match encode r with
       | data -> write ch data
       | exception _ -> ()
    ) rs

let commands ch =
  if ch.eof then None else
    match parse ch with
    | [] -> None
    | requests -> Some Main.{ requests ; callback = callback ch }

(* -------------------------------------------------------------------------- *)
(* --- Establish the Server                                               --- *)
(* -------------------------------------------------------------------------- *)

type socket = {
  socket : Unix.file_descr ;
  mutable channel : channel option ;
}

let fetch (s:socket) () =
  Format.printf "SOCKET-FETCH@." ;
  try
    match s.channel with
    | Some ch -> commands ch
    | None ->
      let fd,_ = Unix.accept ~cloexec:true s.socket in
      Unix.set_nonblock fd ;
      let inc = Unix.in_channel_of_descr fd in
      let out = Unix.out_channel_of_descr fd in
      Senv.debug "Client connected" ;
      let ch = {
        eof = false ; inc ; out ;
        buffer = Buffer.create buffer_size ;
      } in
      s.channel <- Some ch ;
      commands ch
  with
  | Unix.Unix_error(EAGAIN,_,_) -> None
  | Stdlib.Sys_error msg ->
    Senv.warning "SocketClient: sys %s" msg ;
    None
  | exn ->
    Senv.warning "SocketClient: exn %s" (Printexc.to_string exn) ;
    None

let close (s:socket) =
  Unix.shutdown s.socket SHUTDOWN_ALL ;
  match s.channel with None -> () | Some ch ->
    begin
      close_in ch.inc ;
      close_out ch.out ;
    end

let bind fd =
  let socket = { socket = fd ; channel = None } in
  try
    Unix.listen fd 1 ;
    Unix.set_nonblock fd ;
    ignore (Sys.signal Sys.sigpipe Signal_ignore) ;
    let pretty = Format.pp_print_string in
    let server = Main.create ~pretty ~fetch:(fetch socket) () in
    Extlib.safe_at_exit begin fun () ->
      Main.stop server ;
      close socket ;
    end ;
    Main.start server ;
    Cmdline.at_normal_exit (fun () ->
        Format.eprintf "SERVER-RUN@." ;
        Main.run server ;
        Format.eprintf "SERVER-OUT@." ;
      ) ;
  with exn ->
    close socket ;
    raise exn

(* -------------------------------------------------------------------------- *)
(* --- Synchronous Server                                                 --- *)
(* -------------------------------------------------------------------------- *)

let server = ref None

let cmdline () =
  let addr = Socket.get () in
  match !server with
  | Some addr0 ->
    if Senv.debug_atleast 1 && addr <> addr0 then
      Senv.warning "Socket server already running on [%s]." addr0
    else
      Senv.feedback "Socket server already running."
  | None ->
    if addr <> "" then
      try
        server := Some addr ;
        if Sys.file_exists addr then Unix.unlink addr ;
        let fd = Unix.socket PF_UNIX SOCK_STREAM 0 in
        Unix.bind fd (ADDR_UNIX addr) ;
        if Senv.debug_atleast 1 then
          Senv.feedback "Socket server running on [%s]." addr
        else
          Senv.feedback "Socket server running." ;
        bind fd
      with exn ->
        Senv.fatal "Server socket failed.@\nError: %s@"
          (Printexc.to_string exn)

let () = Db.Main.extend cmdline

(* -------------------------------------------------------------------------- *)
