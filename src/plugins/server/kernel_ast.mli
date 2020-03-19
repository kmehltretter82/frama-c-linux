(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

(* -------------------------------------------------------------------------- *)
(** Ast Data *)
(* -------------------------------------------------------------------------- *)

open Cil_types

module Kf : Data.S_collection with type t = kernel_function
module Ki : Data.S_collection with type t = kinstr
module Stmt : Data.S_collection with type t = stmt

module Marker :
sig
  include Data.S with type t = Printer_tag.localizable
  val create : t -> string (** Memoized unique identifier. *)
  val lookup : string -> t (** Get back the localizable, if any. *)
end

(* -------------------------------------------------------------------------- *)
(** Ast Printer *)
(* -------------------------------------------------------------------------- *)

module Printer : Printer_tag.S_pp

(* -------------------------------------------------------------------------- *)
