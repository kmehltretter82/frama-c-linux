(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Eva public API. *)


(** {2 Main API} *)

(** Run the analysis and check analysis status. *)
module Analysis = Analysis

(** Main API to access the results of an analysis, such as the possible values
    of expressions and memory locations of lvalues at each program point. *)
module Results = Results


(** {2 Statistics} *)

(** Statistics about the analysis performance. *)
module Eva_perf = (Eva_perf : Eva_perf_sig.API)

(** Various statistics collected during an analysis. *)
module Statistics = Statistics


(** {2 Types used in Eva} *)

(** AST used by Eva. *)
module Eva_ast = Eva_ast

(** Position in the analysis *)
module Position = Position

(** Types of callstack. *)
module Callstack = Callstack

(** Types for the memory dependencies of an expression or lvalue. *)
module Deps = Deps


(** {2 Configuration of the analysis} *)

(** Command-line parameters of the analysis. *)
module Parameters = Parameters

(** Add local annotations to guide the analysis. *)
module Eva_annotations = Eva_annotations

(** Register OCaml builtins to be used by the cvalue domain instead of analysing
    the body of some C functions. *)
module Builtins = (Builtins : Builtins_sig.API)


(** {2 Registration of new abstractions} *)

(** Various types used in abstract domain signature. *)
module Eval = Eval

(** Signature of abstract domains, inferring properties about the program
    during the analysis. *)
module Abstract_domain = Abstract_domain

(** Signature of abstract numerical values, representing the set of possible
    values of an expression or lvalue. Used to exchange information between
    abstract domains. *)
module Abstract_value = Abstract_value

(** Signature of abstract memory locations, representing the set of possible
    memory locations pointed to by an lvalue. *)
module Abstract_location = Abstract_location

(** Signature of abstract state, which can be used to transfer information from
    states of abstract domains to abstract values. *)
module Abstract_context = Abstract_context

(** Empty context. *)
module Unit_context = Unit_context

(** Automatic builders to complete abstract domains from different
    simplified interfaces. *)
module Domain_builder = Domain_builder

(** Simplified interfaces for abstract domains. Complete abstract domains can be
    built from these interfaces through the functors in {!Domain_builder}. *)
module Simpler_domains = Simpler_domains

(** Build a domain upon a value abstraction with a very simple memory model
    for scalar non-volatile variables. *)
module Simple_memory = Simple_memory

(** Register new abstract domains. *)
module Domain = Abstractions.Domain

(** Common value abstractions shared by many abstract domains. *)
module Main_values = Main_values

(** Common location abstractions shared by many abstract domains. *)
module Main_locations = Main_locations


(** {2 Internal API}

    These modules are for internal use only.
    They may be modified or removed in future versions.
    Please contact us if you need features from these modules.  *)

(** Generation of annotations. *)
module Export = Export

(** Types and operations for the From plugin. *)
module Assigns = Assigns

(** Register hooks called during the analysis with states of the cvalue domain. *)
module Cvalue_callbacks = (Cvalue_callbacks : Cvalue_callbacks_sig.API)

(** Interpretation of predicates and assigns clauses for Inout and From plugins. *)
module Logic_inout = Logic_inout

(** Undocumented. *)
module Eva_results = Eva_results

(** Unit testing. *)
module Unit_tests = Unit_tests
