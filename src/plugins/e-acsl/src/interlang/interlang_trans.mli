(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2025                                               *)
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

(** The compilation of E-ACSL to Cil currently has two different compilation
    schemes, the original direct-to-Cil compilation scheme, and the new
    compilation scheme, in which E-ACSL is first translated into an
    intermediate language {!Interlang} and only then into Cil.
    The implementation of the new compilation scheme is not yet complete and
    will fail on many E-ACSL expressions. Therefore we supply in this module a
    function that tries first the new compilation schemes and only in case of
    failure applies the older one. *)

open Cil_types

(** a compiler that translates E-ACSL predicates to an expression of the E-ACSL
    intermediate language (see {!Interlang}) using the {!Interlang_gen.m} monad. *)
type 'a il_compiler = 'a -> Interlang.exp Interlang_gen.m

(** a direct-to-Cil compiler that compiles E-ACSL predicates directly to Cil. *)
type 'a compiler =
  loc:location ->
  adata:Assert.t ->
  env:Env.t ->
  kf:kernel_function ->
  'a ->
  exp * Assert.t * Env.t

(** compile a predicate to a Cil expression by first trying the new
    compilation scheme via the E-ACSL intermediate language (see {!Interlang});
    if that fails raising {!Interlang_gen.Not_covered}, fall back to the old
    direct-to-Cil compilation scheme. *)
val try_il_compiler :
  'a il_compiler ->
  'a compiler ->
  'a compiler
