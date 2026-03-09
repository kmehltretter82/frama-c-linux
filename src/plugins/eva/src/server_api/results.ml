(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Eva__Results

let is_called kf =
  match Callstack_requests.compatible_filter () with
  | None -> is_called kf
  | Some filter -> List.exists filter (at_start_of kf |> callstacks)

let callsites kf =
  let callsites = callsites kf in
  match Update.CurrentCallstacks.get () with
  | [] -> callsites
  | callstacks ->
    let module StmtSet = Cil_datatype.Stmt.Set in
    let add acc (kf', stmt) =
      if Kernel_function.equal kf kf' then StmtSet.add stmt acc else acc
    in
    let add' acc cs = List.fold_left add acc cs.Callstack.stack in
    let stmts = List.fold_left add' StmtSet.empty callstacks in
    let is_compatible stmt = Cil_datatype.Stmt.Set.mem stmt stmts in
    let filter (kf, stmt_list) =
      match List.filter is_compatible stmt_list with
      | [] -> None
      | stmt_list -> Some (kf, stmt_list)
    in
    List.filter_map filter callsites


let update request =
  match Callstack_requests.compatible_filter () with
  | None -> request
  | Some filter -> filter_callstack filter request

let at_start_of kf = at_start_of kf |> update
let at_end_of kf = at_end_of kf |> update
let before stmt = before stmt |> update
let after stmt = after stmt |> update
let before_kinstr kinstr = before_kinstr kinstr |> update
