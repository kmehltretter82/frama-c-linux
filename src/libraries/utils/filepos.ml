(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

[@@@alert "-deprecated"]
type t = Filepath.position = {
  pos_path : Filepath.t;
  pos_lnum : int;
  pos_bol : int;
  pos_cnum : int;
}
[@@@alert "+deprecated"]

let unknown = {
  pos_path = Filepath.empty;
  pos_lnum = 0;
  pos_bol = 0;
  pos_cnum = -1;
}

let is_unknown pos = pos == unknown

let of_lexing_pos p = {
  pos_path = Filepath.of_string p.Lexing.pos_fname;
  pos_lnum = p.Lexing.pos_lnum;
  pos_bol = p.Lexing.pos_bol;
  pos_cnum = p.Lexing.pos_cnum;
}

let to_lexing_pos p = {
  Lexing.pos_fname = Filepath.to_string_abs p.pos_path;
  pos_lnum = p.pos_lnum;
  pos_bol = p.pos_bol;
  pos_cnum = p.pos_cnum;
}

let pretty fmt pos =
  let path = pos.pos_path in
  if Filepath.is_empty path || Filepath.is_special_stdout path then
    Format.fprintf fmt "%a" Filepath.pretty path
  else
    Format.fprintf fmt "%a:%d" Filepath.pretty path pos.pos_lnum

let pretty_debug fmt pos =
  Format.fprintf fmt "{pos_path=%a;pos_lnum=%d;pos_bol=%d;pos_cnum=%d}"
    Filepath.pretty_abs pos.pos_path
    pos.pos_lnum
    pos.pos_bol
    pos.pos_cnum

let pp_with_col fmt pos =
  Format.fprintf fmt "%a char %d" pretty pos
    (pos.pos_cnum - pos.pos_bol)

include (
  Datatype.Make_with_collections (struct
    type nonrec t = t
    let name = "Filepos"
    let reprs = [ unknown ]
    let compare = Extlib.compare_basic
    let hash = Hashtbl.hash
    let copy = Datatype.identity
    let equal = ( = )
    let pretty = pretty
    let structural_descr = Structural_descr.t_abstract
    let rehash = Datatype.identity
    let mem_project = Datatype.never_any_project
  end) : Datatype.S_with_collections with type t := t)
