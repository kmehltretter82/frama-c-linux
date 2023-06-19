(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(** {1 Auxiliary definitions and functions for pretty-printing } *)

(** Partially applied format-like function missing a "%a" argument *)
type poly_format_quote_a =
  { pf: 'a. (Format.formatter -> 'a -> unit) -> 'a -> unit }

(** Partially applied Log.pretty_printer value, missing its entire formatter
    (and the arguments) *)
type poly_pretty_printer =
  { ppp: 'a. ('a, Format.formatter, unit) format -> 'a }


let compare_tag (v1 : 'a) (v2 : 'a) =
  let o1 = Obj.repr v1 and o2 = Obj.repr v2 in
  match Obj.is_int o1, Obj.is_int o2 with
  | true, true -> Stdlib.compare o1 o2
  | false, false -> Stdlib.compare (Obj.tag o1) (Obj.tag o2)
  | true, false -> 1
  | false, true -> -1

let comp f1 v11 v12 f2 v21 v22 =
  let r = f1 v11 v12 in
  if r = 0 then f2 v21 v22 else r


(* -------------------------------------------------------------------------- *)
(* --- Misc                                                               --- *)
(* -------------------------------------------------------------------------- *)


let mem () =
  Gc.full_major ();
  let s = Gc.stat () in
  let size =  s.Gc.live_words  in
  size * 8 / 1048576


type 'a conversion_with_warning = [
  | `Success of 'a
  | `WithWarning of (Format.formatter -> unit) * 'a
]

type 'a conversion = [
  | 'a conversion_with_warning
  | `Failure of (Format.formatter -> unit)
]

let conv_map f = function
  | `Success v -> `Success (f v)
  | `WithWarning (m, v) -> `WithWarning (m, f v)
  | `Failure m -> `Failure m

exception FailMsg of (Format.formatter -> unit)


exception Found of int

let utf8_char_length c =
  if c < 0x80 then 1
  else
    try
      let mask = ref 0b10000000 in
      for i = 1 to 8 do
        mask := !mask lor (1 lsl (8-i));
        if (c land !mask) = !mask then
          raise (Found (i+1))
      done;
      failwith (Format.sprintf "incorrect utf-8 start %d" c)
    with Found i -> i

(*if c < 0b11100000 then 2
  else if c < 0b11110000 then 3
  else if c < 0b11111000 then 4
  else if c < 0b11111100 then 5
  else 6
*)

exception Escape_non_utf8 of string * int * int

let escape_char c =
  if c = '"' then "\\\""
  else Char.escaped c

let escape_non_utf8 s =
  let s' = Buffer.create (String.length s) in
  let rec aux i =
    if i < String.length s then
      let c = s.[i] in
      let utf8 = utf8_char_length (Char.code c) in
      if utf8 <> 1 then
        try
          let sub = String.sub s i utf8 in
          Buffer.add_string s' sub;
          aux (i+utf8)
        with _ -> raise (Escape_non_utf8 (s, i, utf8))
      else (
        Buffer.add_string s' (escape_char c);
        aux (i+1)
      )
  in
  aux 0;
  Buffer.contents s'


let clear_value_results () =
  Project.clear ~selection:(State_selection.with_dependencies
                              Eva.Analysis.self) ();
;;

let mthread_h () =
  MtOptions.MThread.Share.get_file "mthread.h";;
