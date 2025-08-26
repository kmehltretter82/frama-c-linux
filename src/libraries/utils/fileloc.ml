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
  let pretty_long fmt loc = fst loc |> Filepos.pretty_long fmt
  let pretty_line fmt loc = fst loc |> Filepos.pretty_long ~file:false fmt
  let pretty_debug = pp

  let pretty fmt loc =
    let pos = fst loc in
    if Filepos.is_known pos
    then Filepos.pretty fmt pos
    else Format.fprintf fmt "generated"

  let pretty_line_range fmt (pos_start, pos_end) =
    if Filepos.path pos_start = Filepos.path pos_end then
      if Filepos.line pos_start = Filepos.line pos_end then
        if Filepos.input_column pos_start = Filepos.input_column pos_end then
          (* same location, do not print twice. *)
          Format.fprintf fmt "line %d, column %d"
            (Filepos.line pos_start)
            (Filepos.input_column pos_start)
        else
          (* single file, single line *)
          Format.fprintf fmt "line %d, between columns %d and %d"
            (Filepos.line pos_start)
            (Filepos.input_column pos_start)
            (Filepos.input_column pos_end)
      else
        (* single file, multiple lines *)
        Format.fprintf fmt "between lines %d and %d"
          (Filepos.line pos_start)
          (Filepos.line pos_end)
    else (* multiple files (very rare) *)
      let pp_pos fmt pos = Filepos.pretty_long fmt pos in
      Format.fprintf fmt "between %a and %a"
        pp_pos pos_start pp_pos pos_end

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


(** {2 Start semantic } *)

let compare_start_semantic (pos1, _ : t) (pos2, _ : t) =
  let c = Filepath.compare (Filepos.path pos1) (Filepos.path pos2) in
  if c <> 0 then c else
    let c = Filepos.line pos1 - Filepos.line pos2 in
    if c <> 0 then c else
      Filepos.input_column pos1 - Filepos.input_column pos2

let equal_start_semantic l1 l2 = compare_start_semantic l1 l2 = 0
