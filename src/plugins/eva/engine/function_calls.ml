(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(* Signal that some results are not stored. The gui or some API calls
   may fail ungracefully. *)
let partial_results () =
  not (Parameters.ResultsAll.get ()) ||
  not (Parameters.NoResultsFunctions.is_empty ())


let info name : (module State_builder.Info_with_size) =
  (module struct
    let name = "Eva.Function_calls." ^ name
    let size = 17
    let dependencies = [ Self.state ]
  end)

module StmtSet = Cil_datatype.Stmt.Set
module Callers = Kernel_function.Map.Make (StmtSet)
module CallersTable = Kernel_function.Make_Table (Callers) (val info "Callers")

let register_call kinstr kf =
  let callstack = Eva_utils.current_call_stack () in
  let kf', kinstr' = Callstack.top_call callstack in
  assert (Kernel_function.equal kf kf');
  assert (Cil_datatype.Kinstr.equal kinstr kinstr');
  match kinstr, Callstack.top_caller callstack with
  | Kglobal, _ -> CallersTable.add kf Kernel_function.Map.empty
  | Kstmt _, None -> assert false
  | Kstmt stmt, Some caller ->
    let callsite = StmtSet.singleton stmt in
    let change calls =
      let prev_stmts = Kernel_function.Map.find_opt caller calls in
      let new_stmts =
        Option.fold ~none:callsite ~some:(StmtSet.union callsite) prev_stmts
      in
      Kernel_function.Map.add caller new_stmts calls
    in
    let add _kf = Kernel_function.Map.singleton caller callsite in
    ignore (CallersTable.memo ~change add kf)

let is_called = CallersTable.mem

let callers kf =
  try
    let calls = Kernel_function.Map.bindings (CallersTable.find kf) in
    List.map fst calls
  with Not_found -> []

let callsites kf =
  try
    let calls = Kernel_function.Map.bindings (CallersTable.find kf) in
    List.map (fun (kf, set) -> kf, StmtSet.elements set) calls
  with Not_found -> []

let nb_callsites () =
  CallersTable.fold
    (fun _kf callers count ->
       Kernel_function.Map.fold
         (fun _caller callsites count -> count + StmtSet.cardinal callsites)
         callers count)
    0

type analysis_target =
  [ `Builtin of string * Builtins.builtin * cacheable * funspec
  | `Spec of Cil_types.funspec
  | `Body of Cil_types.fundec * bool ]

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

(* All statuses bound to a given function should be identical, except for
   recursive functions that may not be completely unrolled: the body is first
   analyzed, and then the spec is used. This can also lead to partial and
   complete analyses of the same function, depending on the success of the
   unrolling for each call. *)
let merge_status s1 s2 =
  match s1, s2 with
  | Analyzed result, SpecUsed  | SpecUsed, Analyzed result ->
    Analyzed (if result = Complete then Partial else result)
  | Analyzed Partial, Analyzed Complete | Analyzed Complete, Analyzed Partial ->
    Analyzed Partial
  | _, _ ->
    assert (s1 = s2);
    s1

let register_status kf kind =
  let status =
    match kind with
    | `Builtin (name, _, _, _) -> Builtin name
    | `Spec _ -> SpecUsed
    | `Body (_, results) -> Analyzed (if results then Complete else NoResults)
  in
  let change prev_status = merge_status prev_status status in
  ignore (StatusTable.memo ~change (fun _ -> status) kf)

let analysis_status kf =
  try StatusTable.find kf
  with Not_found -> Unreachable


(* Must be consistent with the choice made by [analysis_target] below. *)
let use_spec_instead_of_definition ?(recursion_depth = -1) kf =
  Ast_info.start_with_frama_c_builtin (Kernel_function.get_name kf) ||
  Builtins.is_builtin_overridden kf ||
  recursion_depth >= Parameters.RecursiveUnroll.get () ||
  not (Kernel_function.is_definition kf) ||
  Kernel_function.Set.mem kf (Parameters.UsePrototype.get ())

(* Returns the function specification of [kf], with generated assigns clauses
   if they are missing. *)
let get_funspec callsite kf =
  let loc =
    match callsite with
    | Kglobal -> None
    | Kstmt stmt -> Some (Cil_datatype.Stmt.loc stmt)
  in
  Populate_spec.populate_funspec ?loc ~do_body:true kf [`Assigns];
  Annotations.funspec kf

let analysis_target ~recursion_depth callsite kf =
  match Builtins.find_builtin_override kf with
  | Some (name, builtin, cache, spec) ->
    `Builtin (name, builtin, cache, spec)
  | None ->
    if recursion_depth >= Parameters.RecursiveUnroll.get ()
    then begin
      Recursion.check_spec callsite kf;
      `Spec (get_funspec callsite kf)
    end
    else
      match kf.fundec with
      | Declaration _ -> `Spec (get_funspec callsite kf)
      | Definition (def, _) ->
        if Kernel_function.Set.mem kf (Parameters.UsePrototype.get ())
        then `Spec (get_funspec callsite kf)
        else `Body (def, save_results def)

let define_analysis_target ?(recursion_depth = -1) callsite kf  =
  let kind = analysis_target callsite kf ~recursion_depth in
  register_call callsite kf;
  register_status kf kind;
  kind


type t = (analysis_status * Callers.t) Kernel_function.Map.t

let get_results () =
  StatusTable.fold_sorted
    (fun kf status acc ->
       let callers = CallersTable.find kf in
       Kernel_function.Map.add kf (status, callers) acc)
    Kernel_function.Map.empty

let set_results =
  let register kf (status, callers) =
    StatusTable.replace kf status;
    CallersTable.replace kf callers
  in
  Kernel_function.Map.iter register

let merge_results =
  let union _kf (status1, callers1) (status2, callers2) =
    let union_stmt _kf s1 s2 = Some (StmtSet.union s1 s2) in
    let callers = Kernel_function.Map.union union_stmt callers1 callers2 in
    let status = merge_status status1 status2 in
    Some (status, callers)
  in
  Kernel_function.Map.union union
