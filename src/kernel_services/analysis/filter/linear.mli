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

open Nat.Types
open Finite.Types



module Space (Field : Field.S) : sig

  open Field.Types

  module Types : sig
    type ('n, 'm) matrix
    type 'n vector = ('n, zero succ) matrix
  end

  open Types

  module Vector : sig
    val pretty : Format.formatter -> 'n vector -> unit
    val size : 'n vector -> 'n nat
    val norm : 'n vector -> scalar
    val zero : 'n succ nat -> 'n succ vector
    val repeat : scalar -> 'n succ nat -> 'n succ vector
    val set : 'n finite -> scalar -> 'n vector -> 'n vector
  end

  module Matrix : sig
    val pretty : Format.formatter -> ('n, 'm) matrix -> unit
    val id : 'n succ nat -> ('n succ, 'n succ) matrix
    val zero : 'n succ nat -> 'm succ nat -> ('n succ, 'm succ) matrix
    val set : 'n finite -> 'm finite -> scalar -> ('n, 'm) matrix -> ('n, 'm) matrix
    val dimensions : ('m, 'n) matrix -> 'm nat * 'n nat
    val ( + ) : ('n, 'm) matrix -> ('n, 'm) matrix -> ('n, 'm) matrix
    val ( * ) : ('n, 'm) matrix -> ('m, 'p) matrix -> ('n, 'p) matrix
    val norm : ('n, 'm) matrix -> scalar
  end

end
