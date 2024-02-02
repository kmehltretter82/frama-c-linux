(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Nat
open Finite



module Space (Field : Field.S) : sig

  type scalar = Field.scalar
  type ('n, 'm) matrix
  type 'n vector = ('n, zero succ) matrix

  module Vector : sig
    val pretty : Format.formatter -> 'n vector -> unit
    val zero   : 'n succ nat -> 'n succ vector
    val base   : 'n succ finite -> 'n succ nat -> 'n succ vector
    val repeat : scalar -> 'n succ nat -> 'n succ vector
    val set    : 'n finite -> scalar -> 'n vector -> 'n vector
    val size   : 'n vector -> 'n nat
    val norm   : 'n vector -> scalar
  end

  module Matrix : sig
    val pretty : Format.formatter -> ('n, 'm) matrix -> unit
    val id : 'n succ nat -> ('n succ, 'n succ) matrix
    val zero : 'n succ nat -> 'm succ nat -> ('n succ, 'm succ) matrix
    val get : 'n finite -> 'm finite -> ('n, 'm) matrix -> scalar
    val set : 'n finite -> 'm finite -> scalar -> ('n, 'm) matrix -> ('n, 'm) matrix
    val norm : ('n, 'm) matrix -> scalar
    val transpose : ('n, 'm) matrix -> ('m, 'n) matrix
    val dimensions : ('m, 'n) matrix -> 'm nat * 'n nat
    val ( + ) : ('n, 'm) matrix -> ('n, 'm) matrix -> ('n, 'm) matrix
    val ( * ) : ('n, 'm) matrix -> ('m, 'p) matrix -> ('n, 'p) matrix
    (* Memoized, instantiate first on a matrix and then use it *)
    val power : ('n, 'n) matrix -> (int -> ('n, 'n) matrix)
  end

end
