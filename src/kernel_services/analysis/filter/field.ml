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

module type S = sig

  type scalar
  include Datatype.S_with_collections with type t = scalar

  val zero     : scalar
  val one      : scalar
  val infinity : scalar

  val of_int : int -> scalar
  val of_float : float -> scalar
  val to_float : scalar -> float

  val neg : scalar -> scalar
  val abs : scalar -> scalar
  val max : scalar -> scalar -> scalar
  val min : scalar -> scalar -> scalar

  val ( =  ) : scalar -> scalar -> bool
  val ( <= ) : scalar -> scalar -> bool
  val ( <  ) : scalar -> scalar -> bool
  val ( >= ) : scalar -> scalar -> bool
  val ( >  ) : scalar -> scalar -> bool

  val ( + ) : scalar -> scalar -> scalar
  val ( - ) : scalar -> scalar -> scalar
  val ( * ) : scalar -> scalar -> scalar
  val ( / ) : scalar -> scalar -> scalar

end
