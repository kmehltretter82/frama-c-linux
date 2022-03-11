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

module Private = struct
  module Abstractions = Eva__Abstractions
  module Analysis = Eva__Analysis
  module Alarmset = Eva__Alarmset
  module Parameters = Parameters
  module Main_values = Eva__Main_values
  module Eval = Eva__Eval
  module Eval_terms = Eva__Eval_terms
  module Eva_utils = Eva_utils
  module Eva_results = Eva_results
  module Self = Self
  module Red_statuses = Eva__Red_statuses
  module Abstract_value = Eva__Abstract_value
  module Abstract_domain = Eva__Abstract_domain
  module Mark_noresults = Eva__Mark_noresults
  module Simple_memory = Eva__Simple_memory
  module Structure = Eva__Structure
  module Eval_typ = Eva__Eval_typ
  module Eval_op = Eva__Eval_op
  module Domain_builder = Eva__Domain_builder
  module Main_locations = Eva__Main_locations
  module Eval_annots = Eva__Eval_annots
  module Eva_dynamic = Eva_dynamic
end

module Analysis = Analysis
module Results = Results
module Parameters = Parameters
module Eva_annotations = Eva_annotations
module Eval = Eval
module Builtins = Builtins
module Eval_terms = Eval_terms
module Eva_results = Eva_results
module Unit_tests = Unit_tests
