(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(** Cartesian product of two value abstractions. *)

type 'v truth := 'v Abstract_value.truth

(** [narrow_truth (v1, t1) (v2, t2)] intersects the truth values [t1] and [t2]
    resulting from [assume_] functions for abstract values [v1] and [v2]
    (that may be reduced by the assumption). *)
val narrow_truth: 'a * 'a truth -> 'b * 'b truth -> ('a * 'b) truth

(** Same as narrow_truth for truth values involving pairs of abstract values. *)
val narrow_truth_pair:
  ('a * 'a) * ('a * 'a) truth -> ('b * 'b) * ('b * 'b) truth ->
  (('a * 'b)  * ('a * 'b)) truth

module Make
    (Context : Abstract_context.S)
    (Left  : Abstract.Value.Internal with type context = Context.t)
    (Right : Abstract.Value.Internal with type context = Context.t)
  : Abstract.Value.Internal
    with type t = Left.t * Right.t
     and type context = Context.t


(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
