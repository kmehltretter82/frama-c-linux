(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)


(* Operations on n dimensional closed balls over a field 𝕂. *)

module Make (K : Field.S) : sig
  open Nat
  open Linear.Space (K)
  type 'n t = { center : 'n vector ; radius : 'n vector }
  val make : 'n succ vector -> 'n succ vector -> 'n succ t
  val zero : 'n succ nat -> 'n succ t
  val constant : 'n succ vector -> 'n succ t
  val pretty : 'n succ t Pretty_utils.formatter
  val is_included : 'n t -> 'n t -> bool
  val ( + ) : 'n t -> 'n t -> 'n t
end
