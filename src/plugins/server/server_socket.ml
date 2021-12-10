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

let feed q =
  if not q.eof then
    try Buffer.add_channel q.buffer q.inc buffer_size
    with End_of_file -> q.eof <- true

let read q =
  try
    let h = match Buffer.nth q.buffer 0 with
      | 'S' -> 3
      | 'L' -> 7
      | 'W' -> 15
      | _ -> raise (Invalid_argument "Server_socket.read")
    in
    let hex = Buffer.sub q.buffer 1 h in
    let len = int_of_string ("0x" ^ hex) in
    let data = Buffer.sub q.buffer (1+h) len in
    let p = 1 + h + len in
    let n = Buffer.length q.buffer - p in
    let rest = Buffer.sub q.buffer p n in
    Buffer.reset q.buffer ;
    Buffer.add_string q.buffer rest ;
    Some data
  with Invalid_argument _ ->
    None

let write q data =
  begin
    let len = String.length data in
    let hex =
      if len < 0xFFF then Printf.sprintf "S%03x" len else
      if len < 0xFFFFFFF then Printf.sprintf "L%07x" len else
        Printf.sprintf "W%015x" len
    in
    output_string q.out hex ;
    output_string q.out data ;
    flush q.out ;
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

let commands q =
  begin
    feed q ;
    let rec scan cmds q =
      match read q with
      | None -> List.rev cmds
      | Some data ->
        match decode data with
        | cmd -> scan (cmd::cmds) q
        | exception _ -> scan cmds q
    in scan [] q
  end

(* -------------------------------------------------------------------------- *)
(* --- Socket Messages                                                    --- *)
(* -------------------------------------------------------------------------- *)

let callback q rs =
  List.iter
    (fun r ->
       match encode r with
       | data -> write q data
       | exception _ -> ()
    ) rs

let fetch q () =
  if q.eof then None else
    match commands q with
    | [] -> None
    | requests -> Some Main.{ requests ; callback = callback q }

(* -------------------------------------------------------------------------- *)
(* --- Establish the Server                                               --- *)
(* -------------------------------------------------------------------------- *)

let pretty = Format.pp_print_string
let server = ref None

let bind inc out =
  try
    Senv.debug "Client connected" ;
    let channel = {
      eof = false ; inc ; out ;
      buffer = Buffer.create buffer_size ;
    } in
    let srv = Main.create ~pretty ~fetch:(fetch channel) () in
    Extlib.safe_at_exit begin fun () ->
      Main.stop srv ;
      close_in inc ;
      close_out out ;
    end ;
    Main.start srv ;
    Cmdline.at_normal_exit (fun () -> Main.run srv) ;
  with exn ->
    close_in inc ;
    close_out out ;
    raise exn

let cmdline () =
  let url = Socket.get () in
  match !server with
  | Some url0 ->
    if url = url0 then
      Senv.feedback "Socket server already running"
    else
      Senv.warning "Socket server already running on [%s]" url0
  | None ->
    if url <> "" then
      try
        server := Some url ;
        if Sys.file_exists url then Unix.unlink url ;
        Senv.feedback "Socket server running on [%s]" url ;
        Unix.establish_server bind (ADDR_UNIX url) ;
      with exn ->
        Senv.fatal "Server socket failed@\nError: %s@"
          (Printexc.to_string exn)

let () = Db.Main.extend cmdline

(* -------------------------------------------------------------------------- *)
