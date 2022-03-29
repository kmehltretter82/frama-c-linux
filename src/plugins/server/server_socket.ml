(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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
(* --- Socket Bytes Read & Write                                          --- *)
(* -------------------------------------------------------------------------- *)

type channel = {
  sock : Unix.file_descr ; (* Socket *)
  snd  : bytes ; (* SND bytes buffer, re-used for transport *)
  rcv  : bytes ; (* RCV bytes buffer, re-used for transport *)
  brcv : Buffer.t ; (* RCV data buffer, accumulated *)
  bsnd : Buffer.t ; (* SND data buffer, accumulated *)
}

let read_bytes { sock ; rcv ; brcv } =
  begin
    (* rcv buffer is only used locally *)
    let s = Bytes.length rcv in
    let rec scan p =
      (* try to fill RCV buffer *)
      if p < s then
        let n =
          try Unix.read sock rcv p (s-p)
          with Unix.Unix_error((EAGAIN|EWOULDBLOCK),_,_) -> 0
        in if n > 0 then scan (p+n) else p
      else p
    in
    let n = scan 0 in
    if n > 0 then Buffer.add_subbytes brcv rcv 0 n
  end

let send_bytes { sock ; snd ; bsnd } =
  begin
    (* snd buffer is only used locally *)
    let n = Buffer.length bsnd in
    if n > 0 then
      let s = Bytes.length snd in
      let rec send p =
        (* try to flush BSND buffer *)
        let w = min (n-p) s in
        Buffer.blit bsnd p snd 0 w ;
        let r =
          try Unix.single_write sock snd 0 w
          with Unix.Unix_error((EAGAIN|EWOULDBLOCK),_,_) -> 0
        in if r > 0 then send (p+r) else p
      in
      let p = send 0 in
      if p > 0 then
        let tail = Buffer.sub bsnd p (n-p) in
        Buffer.reset bsnd ;
        Buffer.add_string bsnd tail
  end

(* -------------------------------------------------------------------------- *)
(* --- Data Chunks Encoding                                               --- *)
(* -------------------------------------------------------------------------- *)

let read_data ch =
  try
    (* Try to read all the data.
       In case there is not enough bytes in the buffer,
       calls to Buffer.sub would raise Invalid_argument. *)
    let h = match Buffer.nth ch.brcv 0 with
      | 'S' -> 3
      | 'L' -> 7
      | 'W' -> 15
      | _ -> raise (Invalid_argument "Server_socket.read")
    in
    let hex = Buffer.sub ch.brcv 1 h in
    let len = int_of_string ("0x" ^ hex) in
    let data = Buffer.sub ch.brcv (1+h) len in
    let p = 1 + h + len in
    let n = Buffer.length ch.brcv - p in
    (* TODO[LC]: inefficient move. Requires a ring-buffer. *)
    let rest = Buffer.sub ch.brcv p n in
    Buffer.reset ch.brcv ;
    Buffer.add_string ch.brcv rest ;
    Some data
  with Invalid_argument _ -> None

let write_data ch data =
  begin
    let len = String.length data in
    let hex =
      if len < 0xFFF then Printf.sprintf "S%03x" len else
      if len < 0xFFFFFFF then Printf.sprintf "L%07x" len else
        Printf.sprintf "W%015x" len
    in
    Buffer.add_string ch.bsnd hex ;
    Buffer.add_string ch.bsnd data ;
  end

(* -------------------------------------------------------------------------- *)
(* --- Request Encoding                                                   --- *)
(* -------------------------------------------------------------------------- *)

let jfield fd js = Json.field fd js |> Json.string

let decode (data : string) : string Main.request =
  match data with
  | "\"POLL\"" -> `Poll
  | "\"SHUTDOWN\"" -> `Shutdown
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
    | _ ->
      Senv.debug ~level:2 "Invalid socket command:@ @[<hov 2>%a@]"
        Json.pp js ;
      raise Not_found

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
    | `CmdLineOn -> `String "CMDLINEON"
    | `CmdLineOff -> `String "CMDLINEOFF"
  in Yojson.Basic.to_string ~std:false js

let parse ch =
  let rec scan cmds ch =
    match read_data ch with
    | None -> List.rev cmds
    | Some data ->
      match decode data with
      | cmd -> scan (cmd::cmds) ch
      | exception _ -> scan cmds ch
  in scan [] ch

(* -------------------------------------------------------------------------- *)
(* --- Socket Messages                                                    --- *)
(* -------------------------------------------------------------------------- *)

let callback ch rs =
  List.iter
    (fun r ->
       match encode r with
       | data -> write_data ch data
       | exception err ->
         Senv.debug "Socket: encoding error %S@." (Printexc.to_string err)
    ) rs ;
  send_bytes ch

let commands ch =
  begin
    read_bytes ch ;
    match parse ch with
    | [] -> send_bytes ch ; None
    | requests -> Some Main.{ requests ; callback = callback ch }
  end

(* -------------------------------------------------------------------------- *)
(* --- Establish the Server                                               --- *)
(* -------------------------------------------------------------------------- *)

type socket = {
  socket : Unix.file_descr ;
  mutable channel : channel option ;
}

let close (s: socket) =
  match s.channel with None -> () | Some ch ->
    s.channel <- None ;
    Unix.close ch.sock

let channel (s: socket) =
  match s.channel with
  | Some _ as chan -> chan
  | None ->
    try
      let sock,_ = Unix.accept ~cloexec:true s.socket in
      let snd = Unix.getsockopt_int sock SO_SNDBUF in
      let rcv = Unix.getsockopt_int sock SO_RCVBUF in
      Senv.debug "Client connected" ;
      let ch = Some {
          sock ;
          snd = Bytes.create snd ;
          rcv = Bytes.create rcv ;
          bsnd = Buffer.create snd ;
          brcv = Buffer.create rcv ;
        } in
      s.channel <- ch ; ch
    with Unix.Unix_error(EAGAIN,_,_) -> None

let fetch (s:socket) () =
  try match channel s with
    | None -> None
    | Some ch -> commands ch
  with
  | Unix.Unix_error(EPIPE,_,_) ->
    Senv.debug "Client disconnected" ;
    close s ; None
  | exn ->
    Senv.warning "Socket: exn %s" (Printexc.to_string exn) ;
    close s ; None

let bind fd =
  let socket = { socket = fd ; channel = None } in
  try
    Unix.set_nonblock fd ;
    Unix.listen fd 1 ;
    Unix.set_nonblock fd ;
    ignore (Sys.signal Sys.sigpipe Signal_ignore) ;
    let pretty = Format.pp_print_string in
    let server = Main.create ~pretty ~fetch:(fetch socket) () in
    Extlib.safe_at_exit
      begin fun () ->
        Main.stop server ;
        close socket ;
      end ;
    Main.start server ;
    Cmdline.at_normal_exit
      begin fun () ->
        Main.run server ;
        close socket ;
      end;
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
