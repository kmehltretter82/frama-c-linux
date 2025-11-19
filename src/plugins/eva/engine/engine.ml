(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Eval

module type S = Engine_sig.S_with_results

module Make (Abstract: Abstractions.S) = struct

  module Eval' =
    Evaluation.Make (Abstract.Ctx) (Abstract.Val) (Abstract.Loc) (Abstract.Dom)

  module rec Transfer_inout' : Engine_sig.Transfer_inout =
    Transfer_inout.Make (Engine)

  and Transfer_stmt' : Engine_sig.Transfer_stmt =
    Transfer_stmt.Make (Engine)

  and Transfer_logic' : Engine_sig.Transfer_logic =
    Transfer_logic.Make (Engine.Dom)

  and Transfer_specification' : Engine_sig.Transfer_specification =
    Transfer_specification.Make (Engine)

  and Initialization' : Engine_sig.Initialization = Initialization.Make (Engine)
  and Iterator' : Engine_sig.Iterator  = Iterator.Make (Engine)
  and Compute' : Engine_sig.Compute = Compute_functions.Make (Engine)
  and Interference' : Engine_sig.Interferences = Interferences.Make (Engine)

  and Engine : Engine_sig.S_with_results
    with type Ctx.t = Abstract.Ctx.t
     and type Val.t = Abstract.Val.t
     and type Loc.location = Abstract.Loc.location
     and type Dom.state = Abstract.Dom.state =
  struct

    module Ctx = Abstract.Ctx
    module Val = Abstract.Val
    module Loc = Abstract.Loc

    module Dom = struct
      include Abstract.Dom
      include Cvalue_domain.Getters (Abstract.Dom)
    end

    module Eval = Eval'
    module Transfer_inout = Transfer_inout'
    module Transfer_stmt = Transfer_stmt'
    module Transfer_logic = Transfer_logic'
    module Transfer_specification = Transfer_specification'
    module Initialization = Initialization'
    module Iterator = Iterator'
    module Compute = Compute'
    module Interferences = Interference'

    let find stmt f =
      if Self.is_computed ()
      then
        let kf = Kernel_function.find_englobing_kf stmt in
        match Function_calls.analysis_status kf with
        | Unreachable | SpecUsed | Builtin _ -> `Bottom
        | Analyzed NoResults -> `Top
        | Analyzed (Complete | Partial) -> f stmt
      else `Top

    let get_stmt_state ~after stmt =
      find stmt (Dom.Store.get_stmt_state ~after :> stmt -> Dom.t or_top_bottom)

    let get_stmt_state_by_callstack ?selection ~after stmt =
      find stmt (Dom.Store.get_stmt_state_by_callstack ?selection ~after)

    let get_global_state () =
      (Dom.Store.get_global_state () :> Dom.t or_top_bottom)

    let get_initial_state kf =
      if Self.is_computed () then
        if Function_calls.is_called kf
        then (Dom.Store.get_initial_state kf :> Dom.t or_top_bottom)
        else `Bottom
      else `Top

    let get_initial_state_by_callstack ?selection kf =
      if Self.is_computed () then
        if Function_calls.is_called kf
        then Abstract.Dom.Store.get_initial_state_by_callstack ?selection kf
        else `Bottom
      else `Top

    let eval_expr state expr = Eval.evaluate state expr >>=: snd

    let copy_lvalue state expr = Eval.copy_lvalue state expr >>=: snd

    let eval_lval_to_loc state lv =
      let get_loc (_, loc) = loc in
      let for_writing = false in
      Eval.lvaluate ~for_writing state lv >>=: get_loc

    let eval_function state ?args lv =
      let list, alarms = Eval.eval_function lv ?args state in
      Lattice_bounds.TopBottom.map (List.map fst) list, alarms

    let assume_cond ~pos state cond positive =
      fst (Eval.reduce state cond positive) >>- fun valuation ->
      let dval = Eval.to_domain_valuation valuation in
      Dom.assume ~pos cond positive dval state
  end

  include Engine
end


let default = Abstractions.Config.of_list [Cvalue_domain.registered, None]
module DefaultAbstractions = (val Abstractions.make default)
module Default : Engine_sig.S_with_results = Make (DefaultAbstractions)


(* Reference to the current configuration (built by Abstractions.configure from
   the parameters of Eva regarding the abstractions used in the analysis) and
   the current Engine module. *)
let ref_engine = ref (default, (module Default : S))

(* Returns the current Engine module. *)
let current () = (module (val (snd !ref_engine)): S)

(* Set of hooks called whenever the current Engine module is changed.
   Useful for the GUI parts that depend on it. *)
module Engine_Hook = Hook.Build (struct type t = (module S) end)

(* Register a new hook. *)
let register_hook = Engine_Hook.extend

(* Sets the current Engine module for a given configuration.
   Calls the hooks above. *)
let set_current config (engine: (module S)) =
  Engine_Hook.apply (module (val engine): S);
  ref_engine := (config, engine)

(* Builds the Engine module corresponding to a given configuration,
   and sets it as the current engine. *)
let make config =
  let engine =
    if Abstractions.Config.(equal config default) then (module Default : S)
    else
      let module Abstract = (val Abstractions.make config) in
      let module Engine = Make (Abstract) in
      (module Engine)
  in
  set_current config engine

(* Builds the engine reference according to the parameters of Eva. *)
let reset () =
  let config = Abstractions.Config.configure () in
  (* If the configuration has not changed, do not reset the engine but uses
     the reference instead. *)
  if not (Abstractions.Config.equal config (fst !ref_engine))
  then make config

(* Resets the Engine reference when the current project is changed. *)
let () =
  Project.register_after_set_current_hook ~user_only:true (fun _ -> reset ());
  Project.register_after_global_load_hook reset
