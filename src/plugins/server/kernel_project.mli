(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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
(** Project Services *)
(* -------------------------------------------------------------------------- *)

open Data

module ProjectInfo : Data.S with type t = Project.t
module ProjectRequest : Request.Input with type t = Project.t * string * json

module GetCurrent : Request.S
  with type input = unit
   and type output = Project.t

module SetCurrent : Request.S
  with type input = Project.t
   and type output = unit

module GetProjects : Request.S
  with type input = unit
   and type output = Project.t list

module GetOn : Request.S
  with type input = ProjectRequest.t
   and type output = json

module SetOn : Request.S
  with type input = ProjectRequest.t
   and type output = json

module ExecOn : Request.S
  with type input = ProjectRequest.t
   and type output = json

(* -------------------------------------------------------------------------- *)
