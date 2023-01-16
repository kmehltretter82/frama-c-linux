(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2023                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype
open Utils

module Dataflow = Dataflow2

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

module type InternalTable  = sig
  include Table
  val add : key -> value -> unit
  val iter : (key -> value -> unit) -> unit
  val clear : unit -> unit
end


module Make_table(H: Hashtbl.S)(V: sig type t val size :int end) : InternalTable with type key = H.key and type value = V.t = struct
  type key = H.key
  type value = V.t
  let tbl = H.create V.size
  let add = H.add tbl
  let find = H.find tbl
  let iter f =
    H.iter f tbl
  let clear () = H.clear tbl
end

module A = struct type t = Abstract_state.t option let size = 7 end
module R = struct type t = Abstract_state.summary option let size = 7 end

module Stmt_table = Make_table(Cil_datatype.Stmt.Hashtbl)(A)
module Function_table = Make_table(Kernel_function.Hashtbl)(R)


module D = Dataflow.StartData(A)


(* let print_option pp fmt x =
 *   match x with
 *     None -> ()
 *   | Some x -> pp fmt x *)

module T =
struct

  let name = "alias"

  let debug = true (* TODO see options *)

  type t = Abstract_state.t option

  module StmtStartData = D

  let copy x = x (* we only have persistant data *)

  let pretty fmt state =
    match state with
    | None -> Format.fprintf fmt "None"
    | Some s -> Format.fprintf fmt "%a" (Abstract_state.pretty ~debug:false) s

  (* let pretty_debug fmt state =
   *   match state with
   *   | None -> Format.fprintf fmt "None"
   *   | Some s -> Format.fprintf fmt "%a" (Abstract_state.pretty ~debug:true) s *)

  let  computeFirstPredecessor _ a = a

  let combinePredecessors stmt ~old state =
    match stmt.skind, old, state with
    | _, _, None -> assert false
    | _, None, Some _ -> Some state (* [old] already included in [state] *)
    | _, Some old, Some new_ ->
      if Abstract_state.equal old new_ then
        None
      else
        Some (Some (Abstract_state.union old new_))

  let do_assignment (a:t) (lv:lval) (exp:exp) : t =
    (* Format.printf "State before do_assignment %a = %a : @[%a@]@." Lval.pretty lv Exp.pretty exp pretty_debug a; *)
    match (a,lv, find_basic_lval exp) with
      (Some a, (Var v1, NoOffset), BLval (Var v2,NoOffset)) ->
      (* case x = y *)
      Some (Abstract_state.assignment_x_y a (Var v1, NoOffset) (Var v2, NoOffset))
    (* constant assignments : do nothing, but maybe check the type of the assigned variable ? *)
    | (_, (Var _, NoOffset), BNone) -> a
    (* arithmetic operations: either do nothing (normal arithmetic) or returns top (pointer arithmetic) *)
    | (Some a, (Var v1, NoOffset), BAddrOf lv2) ->
      (* case x = &y *)
      Some (Abstract_state.assignment_x_addr_y a (Var v1, NoOffset) lv2)
    | (Some a, (Var v1, NoOffset), BLval (Mem e2, NoOffset)) ->
      (* case x  = *y *)
      begin
        match e2.enode with
          Lval lv2 -> Some (Abstract_state.assignment_x_ptr_y a (Var v1, NoOffset) lv2)
        |  _ -> failwith " do_assignment not implemented 1"
      end
    | (Some a, (Mem e1, NoOffset), BLval lv2) ->
      (* case *x = y *)
      begin
        match e1.enode with
          Lval lv1 -> Some (Abstract_state.assignment_ptr_x_y a lv1 lv2)
        |  _ -> (Options.feedback "Skipping assignment @[%a@] = @[%a@] (BUG do_assignment 2)" Lval.pretty lv Exp.pretty exp; Some a) (* failwith " do_assignment not implemented 2" *)
      end
    (* cases *x = cst *)
    | (Some a, (Mem e1, NoOffset), BNone) ->
      begin
        match e1.enode with
          Lval lv1 -> Some (Abstract_state.assignment_ptr_x_cst a lv1)
        |  _ -> Options.feedback "Ingnoring assignment %a = %a (do_assignment  not implemented 3)@." Lval.pretty lv Exp.pretty exp; Some a
      end
    | (None, _, _) -> None
    | _ -> (Options.feedback "Skipping assignment @[%a@] = @[%a@] (not implemented)" Lval.pretty lv Exp.pretty exp; a)

  let rec do_init vi init state = match init with
    | SingleInit e -> do_assignment state (Var vi, NoOffset) e
    | CompoundInit(_, l) ->
      List.fold_left (fun state (_, init) -> do_init vi init state) state l


  let doInstr (s:stmt)  (i:instr) (a:t) :t =
    match i with
      Set(lv,exp,_) ->
      let new_a = do_assignment a lv exp in
      new_a
    | Local_init(v,AssignInit i,_) ->
      let new_a = do_init v i a in
      new_a
    | Code_annot _ -> a
    | Skip _ -> a
    (* special case for malloc *)
    | Call(res,{enode=Lval (Var info, _);_},_,_) when info.vname = "malloc"  ->
      begin
        match (a,res) with
          (None, _) -> None
        | (Some a,None) -> (Options.feedback "Warning : malloc not stored (ignored)"; Some a)
        | (Some a, Some  (Var v1, NoOffset)) -> Some (Abstract_state.assignment_x_allocate_y a  (Var v1, NoOffset))
        | (Some a, Some lv) -> (Options.feedback "Skipping assignment @[%a@] = malloc() (not implemented)" Lval.pretty lv; Some a)
      end
    (* general case for calls *)
    | Call(res,ef,es,(loc,_)) ->
      begin
        let summary = match Kernel_function.get_called ef with
          | Some kf -> (try Function_table.find kf with Not_found -> None)
          | None -> Options.abort ~source:loc
                      "Unsupported function pointer (skipped)"
        in
        match (a, summary) with
          (None, _) -> None
        | (Some a, Some summary) ->
          let new_a = Abstract_state.call a res es summary in
          Some new_a
        | (Some a, None) -> (Options.feedback "Skiping @[%a@] (summary not found)" Stmt.pretty s; Some a)
    end
    | _ -> (Options.feedback "Skiping @[%a@] (doInstr not implemented)" Stmt.pretty s; a)

  let doGuard _ _ a =
    Dataflow.GUse a, Dataflow.GUse a

  let rec process_Stmt (s:stmt) (a:t) : t =
    (* let _, kf = Kernel_function.find_from_sid s.sid in
     * let is_first = Kernel_function.is_first_stmt kf s in
     * let is_last = Kernel_function.is_return_stmt kf s in *)
    let new_a =
      match s.skind with
        Instr i -> doInstr s i a
      | Block b -> process_Block b a
      | _ -> a
    in
    begin match new_a with
        None -> ()
      | Some a -> Stmt_table.add s (Some a)
    end;
    new_a

  and process_Block b a =
    List.fold_left
      (fun acc s -> process_Stmt s acc)
      a
      b.bstmts

  let doStmt (s:stmt) (a:t) =
    Dataflow.SUse (process_Stmt s a)


  let doEdge _ _ a = a
end

module  F = Dataflow.Forwards(T)

let doFunction (kf:kernel_function) =
  Options.feedback ~level:2 "entering in function %a."
    Kernel_function.pretty kf;
  if Kernel_function.has_definition kf then
    let first_stmts = try [Kernel_function.find_first_stmt kf] with Kernel_function.No_Statement -> [] in
    List.iter (fun stmt -> T.StmtStartData.add stmt (Some Abstract_state.initial_value)) first_stmts;
    F.compute first_stmts;
    let return_stmt = Kernel_function.find_return kf in
    let final_state : Abstract_state.t option = try Stmt_table.find return_stmt with Not_found -> None in
    let summary: Abstract_state.summary =
      Abstract_state.make_summary final_state kf
    in
    Function_table.add kf (Some summary)

let make_summary (state:Abstract_state.t) (kf:kernel_function) =
  try
    begin
      match Function_table.find kf with
        Some s -> (state, s)
      | None -> failwith "not implemented"
    end
  with
    Not_found ->
    begin
      doFunction kf;
      match Function_table.find kf with
        Some s -> (state, s)
      | None -> failwith "not implemented"
    end

let computed_flag = ref false

let is_computed () = !computed_flag

let compute () =
  Ast.compute();
  Options.feedback "Parsing done";
  Globals.Functions.iter doFunction;
  Options.feedback "Functions done";
  computed_flag := true;
  let print_stmt_table_elt fmt k v :unit =
    let print_key = Stmt.pretty in
    let print_value fmt v =
      match v with
      | None -> Format.fprintf fmt "<Bot>"
      | Some a -> Abstract_state.pretty fmt a
    in
    Format.fprintf fmt "After statement %a :@.@[<hov 2> %a@]@." print_key k print_value v
  in
  let print_function_table_elt fmt kf s :unit =
    let function_name =
      Kernel_function.get_name kf
    in
    match s with
      None -> Format.printf "DEBUG: function %s -> None@." function_name
    | Some s -> Abstract_state.pretty_summary ~function_name fmt s
  in
  if Options.ShowStmtTable.get() then
    Stmt_table.iter (print_stmt_table_elt Format.std_formatter);
  if Options.ShowFunctionTable.get() then
    begin
      Function_table.iter (print_function_table_elt Format.std_formatter)
    end


let clear () =
  computed_flag := false;
  Stmt_table.clear()

let get_abstract_state _ stmt =
  if is_computed ()
  then
    try Stmt_table.find stmt with
      Not_found -> None
  else
    None
