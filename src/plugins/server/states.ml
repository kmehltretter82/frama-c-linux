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
(* --- Values & States                                                    --- *)
(* -------------------------------------------------------------------------- *)

let register_value (type a) ~page ~name ~descr ?(details=[])
    ~(output : a Request.output) ~get =
  let open Markdown in
  let title =  Printf.sprintf "`VALUE` %s" name in
  let index = [ Printf.sprintf "%s (`VALUE`)" name ] in
  let description = [ Block [Text descr] ; Block details] in
  let h = Doc.publish ~page ~name ~title ~index description [] in
  let signal = Request.signal ~page ~name:(name ^ ".sig")
      ~descr:(plain "Signal for value " @ href h) () in
  Request.register ~page ~kind:`GET ~name:(name ^ ".get")
    ~descr:(plain "Getter for value " @ href h)
    ~input:(module Data.Junit) ~output get ;
  signal

let register_state (type a) ~page ~name ~descr ?(details=[])
    ~(data : a Data.data) ~get ~set =
  let open Markdown in
  let title =  Printf.sprintf "`STATE` %s" name in
  let index = [ Printf.sprintf "%s (`STATE`)" name ] in
  let description = [ Block [Text descr] ; Block details] in
  let h = Doc.publish ~page ~name ~title ~index description [] in
  let signal = Request.signal ~page ~name:(name ^ ".sig")
      ~descr:(plain "Signal for state " @ href h) () in
  Request.register ~page ~kind:`GET ~name:(name ^ ".get")
    ~descr:(plain "Getter for state " @ href h)
    ~input:(module Data.Junit) ~output:(module (val data)) get ;
  Request.register ~page ~kind:`SET ~name:(name ^ ".set")
    ~descr:(plain "Setter for state " @ href h)
    ~input:(module (val data)) ~output:(module Data.Junit) set ;
  signal

(* -------------------------------------------------------------------------- *)
