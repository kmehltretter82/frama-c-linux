(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(** Eva public API.

   The main modules are:
   - Analysis: run the analysis.
   - Results: access analysis results, especially the values of expressions
      and memory locations of lvalues at each program point.

   The following modules allow configuring the Eva analysis:
   - Parameters: change the configuration of the analysis.
   - Eva_annotations: add local annotations to guide the analysis.
   - Builtins: register ocaml builtins to be used by the cvalue domain
       instead of analysing the body of some C functions.

   Other modules are for internal use only. *)

module Analysis = Analysis
module Results = Results

module Parameters = Parameters
module Eva_annotations = Eva_annotations
module Builtins = Builtins


(** For internal use *)

module Private: sig
  module Abstractions = Abstractions
  module Alarmset = Alarmset
  module Main_values = Main_values
  module Eval = Eval
  module Eva_utils = Eva_utils
  module Eva_results = Eva_results
  module Self = Self
  module Eval_terms = Eval_terms
  module Red_statuses = Red_statuses
  module Abstract_value = Abstract_value
  module Abstract_domain = Abstract_domain
  module Mark_noresults = Mark_noresults
  module Simple_memory = Simple_memory
  module Structure = Structure
  module Eval_typ = Eval_typ
  module Eval_op = Eval_op
  module Domain_builder = Domain_builder
  module Main_locations = Main_locations
  module Eval_annots = Eval_annots
  module Eva_dynamic = Eva_dynamic
end
