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

(** Module for preprocessing the quantified predicates. Predicates with
    quantifiers are hard to translate, so we delegate some of the work to a
    preprocessing phase. At the end of this phase, all the quantified predicates
    should have an associated preprocessed form [vars * goal] where - [vars] is a
    list of guarded variables in the right order - [goal] is the predicate under
    the quantifications The guarded variables in the list [vars] are of type
    [term * logic_var * term * predicate option], where a tuple [(t1,v,t2,p)]
    indicates that v is a logic variable with the two guards t1 <= x < t2 and p
    is an additional optional guard to intersect the first guard with the
    provided type for the variable v *)

