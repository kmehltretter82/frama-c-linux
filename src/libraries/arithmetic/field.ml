(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

type 't bounds = { lower : 't ; upper : 't }

module type S = sig

  include Datatype.S_with_collections
  type scalar = t

  val zero    : scalar
  val one     : scalar
  val two     : scalar
  val pos_inf : scalar
  val neg_inf : scalar

  val of_int    : int -> scalar
  val of_float  : float -> scalar
  val to_float  : scalar -> float
  val of_string : string -> scalar

  val neg : scalar -> scalar
  val abs : scalar -> scalar
  val max : scalar -> scalar -> scalar
  val min : scalar -> scalar -> scalar

  val pow2 : int -> scalar
  val log2 : scalar -> int bounds
  val sqrt : scalar -> scalar bounds

  val ( + ) : scalar -> scalar -> scalar
  val ( - ) : scalar -> scalar -> scalar
  val ( * ) : scalar -> scalar -> scalar
  val ( / ) : scalar -> scalar -> scalar

  val ( =  ) : scalar -> scalar -> bool
  val ( != ) : scalar -> scalar -> bool
  val ( <= ) : scalar -> scalar -> bool
  val ( <  ) : scalar -> scalar -> bool
  val ( >= ) : scalar -> scalar -> bool
  val ( >  ) : scalar -> scalar -> bool

end
