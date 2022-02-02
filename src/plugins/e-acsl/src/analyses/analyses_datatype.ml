(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2021                                               *)
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

(** Datatypes for analyses types *)

open Cil_datatype
open Analyses_types

module PredOrTerm =
  Datatype.Make_with_collections
    (struct
      type t = pred_or_term

      let name = "E_ACSL.PredOrTerm"

      let reprs =
        let reprs =
          List.fold_left
            (fun reprs t -> PoT_term t :: reprs)
            []
            Term.reprs
        in
        List.fold_left
          (fun reprs p -> PoT_pred p :: reprs)
          reprs
          Predicate.reprs

      include Datatype.Undefined

      let compare pot1 pot2 =
        match pot1, pot2 with
        | PoT_pred _, PoT_term _ -> -1
        | PoT_term _, PoT_pred _ -> 1
        | PoT_pred p1, PoT_pred p2 -> PredicateStructEq.compare p1 p2
        | PoT_term t1, PoT_term t2 -> Term.compare t1 t2

      let equal = Datatype.from_compare

      let hash = function
        | PoT_pred p -> 7 * PredicateStructEq.hash p
        | PoT_term t -> 97 * Term.hash t

      let pretty fmt = function
        | PoT_pred p -> Printer.pp_predicate fmt p
        | PoT_term t -> Printer.pp_term fmt t

      let varname _ = "pred_or_term"
    end)
