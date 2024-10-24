(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)


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

type 'a conversion_with_warning = [
  | `Success of 'a
  | `WithWarning of (Format.formatter -> unit) * 'a
]

type 'a conversion = [
  | `Success of 'a
  | `Failure of (Format.formatter -> unit)
]


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
                              Analysis.self) ();
;;

let mthread_h () =
  Mt_self.Share.get_file "mthread.h";;


let sanitize_filename ?(char='_') s =
  let is_invalid c =
    match c with
    | '&' | '+' | '[' | ']' | '.' -> true
    | _ -> false
  in
  String.map (fun c -> if is_invalid c then char else c) s

type threads_lib =
  | BuiltinsOnly
  | Pthreads
