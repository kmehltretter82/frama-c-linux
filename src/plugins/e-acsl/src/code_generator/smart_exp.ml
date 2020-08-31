(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

open Cil_types

let lval ~loc lv =
  Cil.new_exp ~loc (Lval lv)

let deref ~loc lv = lval ~loc (Mem lv, NoOffset)

let subscript ~loc array idx =
  match Misc.extract_uncoerced_lval array with
  | Some { enode = Lval lv } ->
    let subscript_lval = Cil.addOffsetLval (Index(idx, NoOffset)) lv in
    lval ~loc subscript_lval
  | Some _ | None ->
    Options.fatal
      ~current:true
      "Trying to create a subscript on an array that is not an Lval: %a"
      Cil_types_debug.pp_exp
      array

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
