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


(* -------------------------------------------------------------------------- *)
(* --- Current Working Directory                                          --- *)
(* -------------------------------------------------------------------------- *)

(* Note: the call to Unix.realpath prevents some issues with symbolic links
   in directory names. If you have problems with this, please contact us.
   For the same reason, Sys.getcwd should _not_ be called directly, but only
   via this function, to avoid conflicting results in case the user forgot
   to call Unix.realpath.
*)
let pwd () = Unix.(realpath (getcwd ()))


(* -------------------------------------------------------------------------- *)
(* --- Conversion from string                                             --- *)
(* -------------------------------------------------------------------------- *)

type existence =
  | Must_exist
  | Must_not_exist
  | Indifferent

exception No_file
exception File_exists

let normalize ?base s =
  if s = ""
  then ""
  else
    let norm_path_name = Hpath.(of_string ?base s |> to_string) in
    if norm_path_name = ""
    then "/"
    else norm_path_name

let check_existence ~existence p =
  match existence with
  | Must_exist when not (Sys.file_exists p) ->
    raise No_file
  | Must_not_exist when Sys.file_exists p ->
    raise File_exists
  | Indifferent | Must_exist | Must_not_exist -> ()

let of_string ?(existence=Indifferent) ?base s =
  let p = normalize ?base s in
  check_existence ~existence p;
  p

let to_string_list l = l

let to_quoted_string s =
  Filename.quote s


(* -------------------------------------------------------------------------- *)
(* --- Datatype                                                           --- *)
(* -------------------------------------------------------------------------- *)

include Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type nonrec t = string
    let name = "Filepath"
    let reprs = [ of_string "/" ]
    let equal = String.equal
    let compare = String.compare
    let hash = Hashtbl.hash (* String.hash only introduced in OCaml 5.0 *)
    let copy = Fun.id
  end)


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

let to_base_uri name =
  Hpath.(of_string name |> to_uri)

let to_pretty_string p =
  let rec skip_dot s =
    if String.starts_with ~prefix:"./" s then
      skip_dot (String.sub s 2 (String.length s - 2))
    else s
  in
  if is_special_stdout p then
    "<stdout>"
  else if is_empty p then
    "<unknown location>"
  else if Filename.is_relative p then
    skip_dot p
  else
    let s = match to_base_uri p with
      | None, uri -> uri
      | Some "PWD", uri -> uri
      | Some symb, uri -> symb ^ "/" ^ uri
    in
    skip_dot s

let pretty fmt p =
  Format.pp_print_string fmt (to_pretty_string p)

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

let has_suffix p suffix = Filename.check_suffix p suffix

let chop_suffix p suffix = Filename.chop_suffix p suffix


(* -------------------------------------------------------------------------- *)
(* --- Relative Paths                                                     --- *)
(* -------------------------------------------------------------------------- *)

let relativize ?(base=Hpath.(cwd |> to_string)) p =
  if base = p then "." else
    let base = base ^ Filename.dir_sep in
    if String.starts_with ~prefix:base p then
      let n = String.length base in
      let p = String.sub p n (String.length p - n) in
      if p = "" then "." else p
    else p

let is_relative ?(base=Hpath.(cwd |> to_string)) p =
  String.equal base p || String.starts_with ~prefix:(base ^ Filename.dir_sep) p

let to_pretty_relative ?base p =
  if is_relative ?base p
  then relativize ?base p
  else to_pretty_string p


(* -------------------------------------------------------------------------- *)
(* --- Symboling Names                                                    --- *)
(* -------------------------------------------------------------------------- *)

let add_symbolic_dir name p =
  Hpath.(Names.add (of_string p) name)

let add_symbolic_dir_list name l =
  List.iter (fun p -> Hpath.(Names.add (of_string p)) name) l

let remove_symbolic_dir p =
  Hpath.Names.remove (Hpath.of_string p)

let reset_symbolic_dirs () =
  Hpath.Names.reset ()

let all_symbolic_dirs () =
  Hpath.Names.all ()
  |> List.map (fun (path, name) -> (name, Hpath.to_string path))


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
(* --- Deprecated functions and modules                                   --- *)
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
