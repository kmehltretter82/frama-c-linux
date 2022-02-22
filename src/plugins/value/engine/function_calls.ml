(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

open Cil_types
open Eval

let save_results f =
  Parameters.ResultsAll.get () && not (Parameters.NoResultsFunctions.mem f)


let info name : (module State_builder.Info_with_size) =
  (module struct
    let name = "Eva.Function_calls." ^ name
    let size = 17
    let dependencies = [ Self.state ]
  end)

module StmtSet = Cil_datatype.Stmt.Set
module Calls = Kernel_function.Map.Make (StmtSet)
module Callers = Kernel_function.Make_Table (Calls) (val info "Callers")

let register_call kinstr kf =
  match kinstr, Eva_utils.call_stack () with
  | Kglobal, _ -> Callers.add kf Kernel_function.Map.empty
  | Kstmt _, ([] | [_]) -> assert false
  | Kstmt stmt, (kf', kinstr') :: (caller, _) :: _ ->
    assert (Kernel_function.equal kf kf');
    assert (Cil_datatype.Kinstr.equal kinstr kinstr');
    let callsite = StmtSet.singleton stmt in
    let change calls =
      let prev_stmts = Kernel_function.Map.find_opt caller calls in
      let new_stmts =
        Option.fold ~none:callsite ~some:(StmtSet.union callsite) prev_stmts
      in
      Kernel_function.Map.add caller new_stmts calls
    in
    let add _kf = Kernel_function.Map.singleton caller callsite in
    ignore (Callers.memo ~change add kf)

let is_called = Callers.mem

let callers kf =
  try
    let calls = Kernel_function.Map.bindings (Callers.find kf) in
    List.map fst calls
  with Not_found -> []

let callsites kf =
  try
    let calls = Kernel_function.Map.bindings (Callers.find kf) in
    List.map (fun (kf, set) -> kf, StmtSet.elements set) calls
  with Not_found -> []


type analysis_target =
  [ `Builtin of string * Builtins.builtin * cacheable * funspec
  | `Spec of Cil_types.funspec
  | `Def of Cil_types.fundec * bool ]

type results = Complete | Partial | NoResults
type analysis_status =
    Unreachable | SpecUsed | Builtin of string | Analyzed of results

module Status = Datatype.Make (
  struct
    include Datatype.Serializable_undefined
    type t = analysis_status
    let name = "Function_calls.Status"
    let reprs = [ Unreachable ]
    let structural_descr = Structural_descr.t_sum [| [| |] |]
    let pretty fmt t =
      let str = match t with
        | Unreachable -> "Unreachable"
        | SpecUsed -> "Spec"
        | Builtin name -> "Builtin " ^ name
        | Analyzed _ -> "Analyzed"
      in
      Format.fprintf fmt "%s" str
  end)

module StatusTable = Kernel_function.Make_Table (Status) (val info "StatusTable")

let register_status kf kind =
  let status =
    match kind with
    | `Builtin (name, _, _, _) -> Builtin name
    | `Spec _ -> SpecUsed
    | `Def (_, results) -> Analyzed (if results then Complete else NoResults)
  in
  let change prev_status =
    match prev_status, status with
    | Analyzed result, SpecUsed ->
      Analyzed (if result = Complete then Partial else result)
    | Analyzed Partial, Analyzed Complete ->
      Analyzed Partial
    | _, _ ->
      assert (prev_status = status);
      status
  in
  ignore (StatusTable.memo ~change (fun _ -> status) kf)

let analysis_status kf =
  try StatusTable.find kf
  with Not_found -> Unreachable


let analysis_target ~recursion_depth callsite kf =
  match Builtins.find_builtin_override kf with
  | Some (name, builtin, cache, spec) ->
    `Builtin (name, builtin, cache, spec)
  | None ->
    if recursion_depth >= Parameters.RecursiveUnroll.get ()
    then `Spec (Recursion.get_spec callsite kf)
    else
      match kf.fundec with
      | Declaration (_,_,_,_) -> `Spec (Annotations.funspec kf)
      | Definition (def, _) ->
        if Kernel_function.Set.mem kf (Parameters.UsePrototype.get ())
        then `Spec (Annotations.funspec kf)
        else `Def (def, save_results def)

let define_analysis_target ?(recursion_depth = -1) callsite kf  =
  let kind = analysis_target callsite kf ~recursion_depth in
  Eva_results.mark_kf_as_called kf;
  register_call callsite kf;
  register_status kf kind;
  kind
