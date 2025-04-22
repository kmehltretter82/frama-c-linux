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

type t = string


(* -------------------------------------------------------------------------- *)
(* --- Current Working dir                                                --- *)
(* -------------------------------------------------------------------------- *)

(* Note: the call to Unix.realpath prevents some issues with symbolic links
   in directory names. If you have problems with this, please contact us.
   For the same reason, Sys.getcwd should _not_ be called directly, but only
   via this function, to avoid conflicting results in case the user forgot
   to call Unix.realpath.
*)
let pwd () = Unix.(realpath (getcwd ()))

let cwd =
  Hpath.(insert dummy (pwd ()))


(* -------------------------------------------------------------------------- *)
(* --- Conversion from string                                             --- *)
(* -------------------------------------------------------------------------- *)

type existence =
  | Must_exist
  | Must_not_exist
  | Indifferent

exception No_file
exception File_exists

let of_string ?(existence=Indifferent) ?base path_name =
  let path =
    if path_name = ""
    then ""
    else
      let base =
        match base with
        | None -> cwd
        | Some (b : t) -> Hpath.insert cwd b
      in
      let norm_path_name = (Hpath.insert base path_name).path_name in
      if norm_path_name = ""
      then "/"
      else norm_path_name
  in
  match existence with
  | Indifferent ->
    path
  | Must_exist ->
    if Sys.file_exists path
    then path
    else raise No_file
  | Must_not_exist ->
    if Sys.file_exists path
    then raise File_exists
    else path

let to_string_list l = l

let to_quoted_string s =
  Filename.quote s


(* -------------------------------------------------------------------------- *)
(* --- Basic datatype functions                                           --- *)
(* -------------------------------------------------------------------------- *)

let equal = String.equal
let compare = String.compare
let hash = Hashtbl.hash (* String.hash only introduced in OCaml 5.0 *)
let copy = Fun.id


(* -------------------------------------------------------------------------- *)
(* --- Constant paths                                                     --- *)
(* -------------------------------------------------------------------------- *)

let empty = of_string ""
let is_empty fp = equal fp empty
let special_stdout = of_string "-"
let is_special_stdout fp = equal fp special_stdout


(* -------------------------------------------------------------------------- *)
(* --- Pretty printing                                                    --- *)
(* -------------------------------------------------------------------------- *)

let rec add_uri_path buffer path =
  let open Buffer in
  match path.Hpath.symbolic_name with
  | None ->
    begin
      match path.dir with
      | None -> add_string buffer path.path_name; None
      | Some d ->
        if d != cwd (* hconsed *) then begin
          let symb_base = add_uri_path buffer d in
          add_char buffer '/';
          add_string buffer path.base_name;
          symb_base
        end else begin
          add_string buffer path.base_name;
          Some "PWD"
        end
    end
  | Some sn -> Some sn

let add_path path =
  let buf = Buffer.create 80 in
  match add_uri_path buf path with
  | None -> Buffer.contents buf
  | Some "PWD" -> Buffer.contents buf
  | Some symb -> symb ^ Buffer.contents buf

let rec skip_dot file_name =
  if String.starts_with ~prefix:"./" file_name then
    skip_dot (String.sub file_name 2 (String.length file_name - 2))
  else file_name

let to_pretty_string file_name =
  if file_name = "" then
    "<unknown location>"
  else if Filename.is_relative file_name then
    skip_dot file_name
  else
    let path = Hpath.insert cwd file_name in
    skip_dot (add_path path)

let pretty fmt p =
  if is_special_stdout p then
    Format.fprintf fmt "<stdout>"
  else if is_empty p then
    Format.fprintf fmt "<unknown location>"
  else
    Format.fprintf fmt "%s" (to_pretty_string p)

let compare_pretty ?(case_sensitive=false) s1 s2 =
  let s1 = to_pretty_string s1 in
  let s2 = to_pretty_string s2 in
  if case_sensitive then String.compare s1 s2
  else
    String.compare
      (String.lowercase_ascii s1)
      (String.lowercase_ascii s2)

let pp_abs fmt p = Format.fprintf fmt "%s" p


(* -------------------------------------------------------------------------- *)
(* --- Path manipulation                                                  --- *)
(* -------------------------------------------------------------------------- *)

let basename p = Filename.basename p

let dirname p = Filename.dirname p

let extend ?existence t ext = of_string ?existence (t ^ ext)

let concat ?existence t s = of_string ?existence (t ^ "/" ^ s)

let concats ?existence t sl =
  let s' = List.fold_left (fun acc s -> acc ^ "/" ^ s) "" sl in
  of_string ?existence (t ^ s')

let to_base_uri name =
  let p = Hpath.insert cwd name in
  let buf = Buffer.create 80 in
  let res = add_uri_path buf p in
  let uri =
    Buffer.contents buf in
  let uri =
    try
      if String.get uri 0 = '/' then
        String.sub uri 1 (String.length uri - 1)
      else uri
    with Invalid_argument _ -> uri
  in
  res, uri


(* -------------------------------------------------------------------------- *)
(* --- Relative Paths                                                     --- *)
(* -------------------------------------------------------------------------- *)

let relativize ?base_name file_name =
  let file_name = (Hpath.insert cwd file_name).path_name in
  let base_name = match base_name with
    | None -> cwd.path_name
    | Some b -> (Hpath.insert cwd b).path_name
  in
  if base_name = file_name then "." else
    let base_name = base_name ^ Filename.dir_sep in
    if String.starts_with ~prefix:base_name file_name then
      let n = String.length base_name in
      let file_name = String.sub file_name n (String.length file_name - n) in
      if file_name = "" then "." else file_name
    else file_name

let is_relative ?base_name file_name =
  let file_name = (Hpath.insert cwd file_name).path_name in
  let base_name = match base_name with
    | None -> cwd.path_name
    | Some b -> (Hpath.insert cwd b).path_name
  in
  base_name = file_name
  || String.starts_with ~prefix:(base_name ^ Filename.dir_sep) file_name


(* -------------------------------------------------------------------------- *)
(* --- Symboling Names                                                    --- *)
(* -------------------------------------------------------------------------- *)

(* Note: Symbolic directories are not currently projectified *)
let symbolic_dirs = Hashtbl.create 3

let add_symbolic_dir name dir =
  Hashtbl.replace symbolic_dirs dir name ;
  (Hpath.insert cwd (dir:>string)).symbolic_name <- Some name

(** Initialize using Config *)
let add_symbolic_dir_list name =
  List.iter (fun d -> add_symbolic_dir name d)

let reset_symbolic_dirs () = Hashtbl.clear symbolic_dirs

let all_symbolic_dirs () =
  let compare (s1, s1') (s2, s2') =
    let c = String.compare s1 s2 in
    if c <> 0 then c
    else String.compare s1' s2'
  in
  List.sort compare @@
  Hashtbl.fold (fun dir name acc -> (name, dir) :: acc) symbolic_dirs []


(* -------------------------------------------------------------------------- *)
(* --- Position in source file                                            --- *)
(* -------------------------------------------------------------------------- *)

type position =
  {
    pos_path : t;
    pos_lnum : int;
    pos_bol : int;
    pos_cnum : int;
  }

let empty_pos = {
  pos_path = empty;
  pos_lnum = 0;
  pos_bol = 0;
  pos_cnum = -1;
}

let pp_pos fmt pos =
  let path = pos.pos_path in
  if is_empty path || is_special_stdout path then
    Format.fprintf fmt "%a" pretty path
  else
    Format.fprintf fmt "%a:%d" pretty path pos.pos_lnum

let is_empty_pos pos = pos == empty_pos



(* -------------------------------------------------------------------------- *)
(* --- Deprecated Normalized module                                       --- *)
(* -------------------------------------------------------------------------- *)

let normalize ?existence ?base_name s = of_string ?existence ?base:base_name s

let exists _ = failwith "deprecated"
let is_file _ = failwith "deprecated"
let is_dir _ = failwith "deprecated"
let readdir  _ = failwith "deprecated"
let remove _ = failwith "deprecated"
let rename _ = failwith "deprecated"
let copy_file _ = failwith "deprecated"
let iter_lines _ = failwith "deprecated"

module Normalized = struct
  type nonrec t = t

  let of_string ?existence ?base_name s =
    let base = (base_name : string option :> t option) in
    of_string ?existence ?base s
  let extend = extend
  let concat = concat
  let concats = concats
  let to_pretty_string = to_pretty_string
  let to_string_list = to_string_list
  let equal = equal
  let compare = compare
  let compare_pretty = compare_pretty
  let empty = empty
  let is_empty = is_empty
  let is_special_stdout = is_special_stdout
  let pretty = pretty
  let pp_abs = pp_abs
  let is_file p =
    try (Unix.stat (p :> string)).Unix.st_kind = Unix.S_REG with _ -> false
  let to_base_uri = to_base_uri
end
