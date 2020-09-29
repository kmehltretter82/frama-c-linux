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

module Value_results = Value_results
module Value_parameters = Value_parameters
module Eval_terms = Eval_terms
module Unit_tests = Unit_tests
module Eva_annotations = Eva_annotations
module Private = struct
  module Abstractions = Eva__Abstractions
  module Analysis = Eva__Analysis
  module Alarmset = Eva__Alarmset
  module Main_values = Eva__Main_values
  module Value_parameters =Eva__Value_parameters
  module Eval = Eva__Eval
  module Eval_terms = Eva__Eval_terms
  module Red_statuses = Eva__Red_statuses
  module Abstract_value = Eva__Abstract_value
  module Abstract_domain = Eva__Abstract_domain
  module Mark_noresults = Eva__Mark_noresults
  module Simple_memory = Eva__Simple_memory
  module Structure = Eva__Structure
  module Eval_typ = Eva__Eval_typ
  module Eval_op = Eva__Eval_op
  module Value_util = Eva__Value_util
  module Value_results = Eva__Value_results
  module Domain_builder = Eva__Domain_builder
  module Main_locations = Eva__Main_locations
  module Eval_annots = Eva__Eval_annots
end
