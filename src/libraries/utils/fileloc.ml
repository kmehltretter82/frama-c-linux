(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** {2 Datatype definition} *)

module Prototype = struct

  type t = Filepos.t * Filepos.t [@@deriving eq, ord, show]

  let unknown = Filepos.(unknown, unknown)
  let reprs = [ unknown ]
  let copy = Datatype.identity
  let is_known loc = fst loc |> Filepos.is_known
  let hash loc = fst loc |> Filepos.hash
  let pretty_debug = pp

  let pretty fmt (pos_start, pos_end) =
    let pp_path = Filepath.pretty in
    if not (Filepos.is_known pos_start) && not (Filepos.is_known pos_end) then
      Filepos.pretty fmt pos_start
    else
      let pos_start = Filepos.original pos_start
      and pos_end = Filepos.original pos_end in
      let path1 = Filepos.path pos_start and path2 = Filepos.path pos_end
      and line1 = Filepos.line pos_start and line2 = Filepos.line pos_end
      and col1 = Filepos.column pos_start and col2 = Filepos.column pos_end in
      if Filepath.equal path1 path2 then
        if line1 <= 0 || line2 <= 0 then
          Format.fprintf fmt "%a" pp_path path1
        else if line1 = line2 then
          if col1 <= 0 || col2 <= 0 then
            Format.fprintf fmt "%a:%d" pp_path path1 line1
          else if col1 = col2 then
            Format.fprintf fmt "%a:%d:%d" pp_path path1 line1 col1
          else
            Format.fprintf fmt "%a:%d:%d-%d" pp_path path1 line1 col1 col2
        else
          Format.fprintf fmt "%a:%d-%d" pp_path path1 line1 line2
      else
        Format.fprintf fmt "%a-%a"
          Filepos.pretty pos_start
          Filepos.pretty pos_end

  let pretty_long fmt (pos_start, pos_end) =
    let pp_path fmt path = Format.fprintf fmt "%S" (Filepath.to_string path) in
    if not (Filepos.is_known pos_start) && not (Filepos.is_known pos_end) then
      Filepos.pretty fmt pos_start
    else
      let pos_start = Filepos.original pos_start
      and pos_end = Filepos.original pos_end in
      let path1 = Filepos.path pos_start and path2 = Filepos.path pos_end
      and line1 = Filepos.line pos_start and line2 = Filepos.line pos_end
      and col1 = Filepos.column pos_start and col2 = Filepos.column pos_end in
      if Filepath.equal path1 path2 then
        if line1 <= 0 || line2 <= 0 then
          Format.fprintf fmt "%a" pp_path path1
        else if line1 = line2 then
          if col1 <= 0 || col2 <= 0 then
            Format.fprintf fmt "%a, line %d" pp_path path1 line1
          else if col1 = col2 then
            Format.fprintf fmt "%a, line %d, character %d"
              pp_path path1 line1 col1
          else
            Format.fprintf fmt "%a, line %d, characters %d-%d"
              pp_path path1 line1 col1 col2
        else
          Format.fprintf fmt "%a, lines %d-%d" pp_path path1 line1 line2
      else
        Format.fprintf fmt "between %a and %a"
          Filepos.pretty_long pos_start
          Filepos.pretty_long pos_end

  let pretty_long_with_inclusions fmt loc =
    pretty_long fmt loc;
    List.pretty ~format:"%t" ~item:",@ included from %a" ~sep:"" ~empty:""
      Filepos.pretty fmt (Filepos.inclusions (fst loc))

end


include Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    include Prototype
    let name = "Fileloc"
  end)

include Prototype


(** {2 Conversion from/to Lexing.position } *)

let of_lexing_loc (pos1, pos2) =
  Filepos.of_lexing_pos pos1, Filepos.of_lexing_pos pos2

let to_lexing_loc (pos1, pos2) =
  Filepos.to_lexing_pos pos1, Filepos.to_lexing_pos pos2


(** {2 Accessors } *)

let path loc = fst loc |> Filepos.path

let line loc = fst loc |> Filepos.line


(** {2 Alternative datatype } *)

module Original = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    include Prototype
    let name = "Fileloc.Original"
    type t = Filepos.Original.t * Filepos.Original.t [@@deriving eq, ord]
    let hash loc = fst loc |> Filepos.Original.hash
  end)
