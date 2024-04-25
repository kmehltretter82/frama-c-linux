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

(** Maps from intervals to values. *)

(** Maps from intervals to values. The documentation of the returned
    maps is in module {!Offsetmap_sig}. *)
module Make (V : Offsetmap_lattice_with_isotropy.S) :
  Offsetmap_sig.S
  with type v = V.t
   and type widen_hint = V.widen_hint

(**/**)
(* Exported as Int_Intervals, do not use this module directly *)
module Int_Intervals: Int_Intervals_sig.S
(**/**)


(** Maps from intervals to simple values. The documentation of the returned
    maps is in module {!Offsetmap_bitwise_sig}. *)
module Make_bitwise(V: sig
    include Lattice_type.Bounded_Join_Semi_Lattice
    include Lattice_type.With_Narrow with type t := t
    include Lattice_type.With_Top with type t := t
  end) :
  Offsetmap_bitwise_sig.S
  with type v = V.t
   and type intervals = Int_Intervals.t


(**/**)

(* This is automatically set by the Value plugin. Do not modify. *)
val set_plevel: int -> unit
val get_plevel: unit -> int


(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
