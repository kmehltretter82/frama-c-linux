(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

let preconditions_emitter =
  Emitter.create
    "Call Preconditions"
    [ Emitter.Property_status ]
    ~correctness:[]
    ~tuning:[]

(* Map from a requires to the its specializations at all call sites. *)
module PreCondProxyGenerated =
  State_builder.Hashtbl(Property.Hashtbl)(Datatype.List(Property))
    (struct
      let name = "Call Preconditions Generated"
      let dependencies = [Ast.self]
      let size = 97
    end)


module PropStmt =
  Datatype.Pair_with_collections(Property)(Cil_datatype.Stmt)

module FunctionPointers =
  Cil_state_builder.Stmt_hashtbl(Kernel_function.Hptset)
    (struct
      let name = "Statuses_by_call.FunctionPointers"
      let dependencies = [Ast.self]
      let size = 37
    end)

let add_called_function stmt kf =
  let prev =
    try FunctionPointers.find stmt
    with Not_found -> Kernel_function.Hptset.empty
  in
  let s = Kernel_function.Hptset.add kf prev in
  FunctionPointers.replace stmt s


let all_functions_with_preconditions stmt =
  match stmt with
  | { skind=Instr (Call(_,Var vkf,_,_)
                  |Local_init(_,ConsInit(vkf,_,_),_)) } ->
    let kf = Globals.Functions.get vkf in
    Kernel_function.Hptset.singleton kf
  |  _ ->
    try FunctionPointers.find stmt
    with Not_found -> Kernel_function.Hptset.empty

(* Map from [requires * stmt] to the specialization of the requires
   at the statement. Only present if the kernel function that contains
   the requires can be called at the statement. *)
module PreCondAt =
  State_builder.Hashtbl(PropStmt.Hashtbl)(Property)
    (struct
      let size = 37
      let dependencies = [ Ast.self ]
      let name = "Statuses_by_call.PreCondAt"
    end)

(* Transposes the precondition property [pid] of the called function [kf]
   at call site [stmt], with arguments [args], result assigned in [result],
   and function [func]. *)
let rec transpose_precondition stmt pid kf func args =
  let formals = Kernel_function.get_formals kf in
  let ip = match pid with
    | Property.IPPredicate {Property.ip_pred} -> ip_pred
    | _ -> assert false
  in
  let ip = Logic_subst.ipred formals args ip in
  let kf_call = Kernel_function.find_englobing_kf stmt in
  let p = Property.ip_property_instance kf_call stmt ip pid in
  PreCondAt.add (pid, stmt) p;
  (match func with
   | Var vkf ->
     assert (Cil_datatype.Varinfo.equal vkf (Kernel_function.get_vi kf))
   | _ ->
     let loc = Cil_datatype.Stmt.loc stmt in
     Kernel.debug ~source:(fst loc)
       "Adding precondition for call to %a through pointer"
       Kernel_function.pretty kf;
     add_called_function stmt kf;
     add_call_precondition pid p
  );
  p

and precondition_at_call kf pid stmt =
  try PreCondAt.find (pid, stmt)
  with Not_found ->
    let do_call = transpose_precondition stmt pid kf in
    match stmt.skind with
    | Instr (Call (_, func, args, _)) -> do_call func args
    | Instr (Local_init (v, ConsInit (f, args, kind), loc)) ->
      let do_call _result funclv args _loc = do_call funclv args in
      Cil.treat_constructor_as_func do_call v f args kind loc
    | _ -> assert false

and setup_precondition_proxy called_kf precondition =
  if not (PreCondProxyGenerated.mem precondition) then begin
    Kernel.debug "Setting up syntactic call-preconditions for precondition \
                  of %a" Kernel_function.pretty called_kf;
    let call_preconditions =
      List.rev_map
        (fun (_,stmt) -> precondition_at_call called_kf precondition stmt)
        (Kernel_function.find_syntactic_callsites called_kf)
    in
    Property_status.logical_consequence
      preconditions_emitter precondition call_preconditions;
    PreCondProxyGenerated.add precondition call_preconditions
  end

and add_call_precondition precondition call_precondition =
  let prev = try PreCondProxyGenerated.find precondition with Not_found -> [] in
  let all = call_precondition :: prev in
  PreCondProxyGenerated.replace precondition all;
  Property_status.logical_consequence preconditions_emitter precondition all

let fold_requires f kf acc =
  let bhvs = Annotations.behaviors kf in
  List.fold_right
    (fun bhv acc -> List.fold_right (f bhv) bhv.b_requires acc) bhvs acc


(* Properties for kf-preconditions at call-site stmt, if created.
   Returns both the initial property and its copy at call site. *)
let all_call_preconditions_at ~warn_missing kf stmt =
  let aux bhv precond properties =
    let pid_spec = Property.ip_of_requires kf Kglobal bhv precond in
    if PreCondAt.mem (pid_spec, stmt) then
      let pid_call = precondition_at_call kf pid_spec stmt in
      (pid_spec, pid_call) :: properties
    else (
      if warn_missing then
        Kernel.fatal ~source:(fst (Cil_datatype.Stmt.loc stmt))
          "Preconditions %a for %a not yet registered at this statement"
          Printer.pp_identified_predicate precond Kernel_function.pretty kf;
      properties)
  in
  fold_requires aux kf []

let setup_all_preconditions_proxies kf =
  let aux bhv req () =
    let ip = Property.ip_of_requires kf Kglobal bhv req in
    setup_precondition_proxy kf ip
  in
  fold_requires aux kf ()

let replace_call_precondition ip stmt ip_at_call =
  (try
     (* Remove previous binding *)
     let cur = PreCondAt.find (ip, stmt) in
     PreCondAt.remove (ip, stmt);
     let all = PreCondProxyGenerated.find ip in
     let all' = List.filter (fun p -> not @@ Property.equal cur p) all in
     PreCondProxyGenerated.replace ip all';
   with Not_found -> ());
  PreCondAt.replace (ip, stmt) ip_at_call;
  add_call_precondition ip ip_at_call
