(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

(** This the API of the WP plug-in *)

(** {1 WP Core calculus} *)

module CfgAnnot = CfgAnnot
module CfgCalculus = CfgCalculus
module CfgCompiler = CfgCompiler
module CfgDump = CfgDump
module CfgGenerator = CfgGenerator
module CfgInfos = CfgInfos
module CfgInit = CfgInit
module CfgWP = CfgWP

(** {1 Memory models}*)

module MemDebug = MemDebug
module MemEmpty = MemEmpty
module MemLoader = MemLoader
module MemMemory = MemMemory
module MemRegion = MemRegion
module MemTyped = MemTyped
module MemVal = MemVal
module MemVar = MemVar
module MemZeroAlias = MemZeroAlias

(** {2 Alias analysis and hypotheses}*)

module MemoryContext = MemoryContext
module RefUsage = RefUsage
module WpTarget = WpTarget

(** {1 Compiler}*)

module CodeSemantics = CodeSemantics
module Conditions = Conditions
module Definitions = Definitions
module LogicAssigns = LogicAssigns
module LogicBuiltins = LogicBuiltins
module LogicCompiler = LogicCompiler
module LogicSemantics = LogicSemantics
module LogicUsage = LogicUsage
module StmtSemantics = StmtSemantics

module AssignsCompleteness = AssignsCompleteness
module Cache = Cache
module Cfloat = Cfloat
module Cint = Cint
module Clabels = Clabels
module Cleaning = Cleaning
module Cmath = Cmath
module Context = Context
module Cstring = Cstring
module Ctypes = Ctypes
module Cvalues = Cvalues
module Driver = Driver
module Dyncall = Dyncall
module Factory = Factory
module Filter_axioms = Filter_axioms
module Filtering = Filtering
module Footprint = Footprint
module Generator = Generator
module Lang = Lang
module Layout = Layout
module Letify = Letify
module Matrix = Matrix
module Mstate = Mstate
module NormAtLabels = NormAtLabels
module Passive = Passive
module Pcfg = Pcfg
module Pcond = Pcond
module Plang = Plang
module ProofSession = ProofSession
module Prover = Prover
module ProverScript = ProverScript
module ProverSearch = ProverSearch
module ProverTask = ProverTask
module ProverWhy3 = ProverWhy3

module RegionAccess = RegionAccess
module RegionAnalysis = RegionAnalysis
module RegionAnnot = RegionAnnot
module RegionDump = RegionDump
module Region = Region
module Register = Register
module Repr = Repr
module Rformat = Rformat
module Sigma = Sigma
module Sigs = Sigs
module Splitter = Splitter
module Stats = Stats
module VC = VC
module VCS = VCS
module Warning = Warning
module Why3Provers = Why3Provers
module WpContext = WpContext
module Wp_error = Wp_error
module Wp_eva = Wp_eva
module Wpo = Wpo
module Wp_parameters = Wp_parameters
module WpPropId = WpPropId
module WpReached = WpReached
module WpReport = WpReport
module Wprop = Wprop
module WpRTE = WpRTE
module WpTac = WpTac

(** {1 Interactive proof} *)

module Auto = Auto
module ProofEngine = ProofEngine
module ProofScript = ProofScript
module Script = Script
module Strategy = Strategy
module Tactical = Tactical

(** {2 Tactics}*)

module TacArray = TacArray
module TacBitrange = TacBitrange
module TacBittest = TacBittest
module TacBitwised = TacBitwised
module TacChoice = TacChoice
module TacClear = TacClear
module TacCompound = TacCompound
module TacCongruence = TacCongruence
module TacCut = TacCut
module TacFilter = TacFilter
module TacHavoc = TacHavoc
module TacInduction = TacInduction
module TacInstance = TacInstance
module TacLemma = TacLemma
module TacModMask = TacModMask
module TacNormalForm = TacNormalForm
module TacOverflow = TacOverflow
module TacRange = TacRange
module TacRewrite = TacRewrite
module TacSequence = TacSequence
module TacShift = TacShift
module TacSplit = TacSplit
module TacUnfold = TacUnfold
