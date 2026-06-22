(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Region Command Line Interface *)

open Parameter_sig
include Log.Messages

val gen_loc: Fileloc.t

module Enabled : Bool
module Assert : Bool
