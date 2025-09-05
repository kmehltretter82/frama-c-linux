(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** For internal use only: the Eva gui and optional domains (numerors and apron)
    are compiled separately from the Eva core. This is used to give them access
    to the internal modules of Eva they need. *)

module Abstract = Abstract
module Abstract_context = Abstract_context
module Abstract_domain = Abstract_domain
module Abstract_location = Abstract_location
module Abstract_value = Abstract_value
module Abstractions = Abstractions
module Active_behaviors = Active_behaviors
module Alarmset = Alarmset
module Analysis = Analysis
module Assigns = Assigns
module Builtins = Builtins
module Callstack = Callstack
module Concurrency = Concurrency
module Cvalue_callbacks = Cvalue_callbacks
module Cvalue_domain = Cvalue_domain
module Cvalue_results = Cvalue_results
module Domain_builder = Domain_builder
module Eva_ast = Eva_ast
module Eva_automata = Eva_automata
module Eva_dynamic = Eva_dynamic
module Eva_results = Eva_results
module Eva_utils = Eva_utils
module Eval = Eval
module Eval_annots = Eval_annots
module Eval_op = Eval_op
module Eval_terms = Eval_terms
module Eval_typ = Eval_typ
module Function_calls = Function_calls
module Field_interval = Field_interval
module IEEE754 = IEEE754
module Inout_access = Inout_access
module Interferences = Interferences
module Logic_inout = Logic_inout
module Main_locations = Main_locations
module Main_values = Main_values
module Mqueue = Mqueue
module Mt_domain = Mt_domain
module Mutex = Mutex
module Parameters = Parameters
module Position = Position
module Red_statuses = Red_statuses
module Results = Results
module Self = Self
module Simple_memory = Simple_memory
module Structure = Structure
module Thread = Thread
module Unit_context = Unit_context
