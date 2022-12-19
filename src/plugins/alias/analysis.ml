(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2022                                               *)
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

module Dataflow = Dataflow2

(* module type Table = sig
 *   type key
 *   type value
 *   val find: key -> value
 *   (\** @raise Not_found if the key is not in the table. *\)
 * end
 *
 * module Make_table(H: Hashtbl.S)(VV: sig type tt val size :int end) = struct
 *   type key = H.key
 *   type value = VV.tt
 *   let tbl = H.create VV.size
 *   let add = H.add tbl
 *   let find = H.find tbl
 *
 * end *)

module A = struct type t = Abstract_state.t option let size = 7 end

(* module Stmt_table = Make_table(Cil_datatype.Stmt.Hashtbl)(A)
 * module Function_table = Make_table(Kernel_function.Hashtbl)(A) *)


module D = Dataflow.StartData(A)

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
    | Some s -> Format.fprintf fmt "%a" Abstract_state.pretty s

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
    match (a,lv,exp.enode) with
      (Some a, (Var v1, NoOffset), Lval (Var v2,NoOffset)) ->
      (* case x = y *)
      Some (Abstract_state.assignment_x_y a (Var v1, NoOffset) (Var v2, NoOffset))
    | (Some a, (Var v1, NoOffset), AddrOf lv2) ->
      (* case x = &y *)
      Some (Abstract_state.assignment_x_addr_y a (Var v1, NoOffset) lv2)
    | (Some a, (Var v1, NoOffset), Lval (Mem e2, NoOffset)) ->
      (* case x  = *y *)
      begin
        match e2.enode with
          Lval lv2 -> Some (Abstract_state.assignment_x_ptr_y a (Var v1, NoOffset) lv2)
        |  _ -> failwith " do_assignment not implemented 1"
      end
    | (Some a, (Mem e1, NoOffset), Lval lv2) ->
      (* case *x = y *)
      begin
        match e1.enode with
          Lval lv1 -> Some (Abstract_state.assignment_ptr_x_y a lv1 lv2)
        |  _ -> failwith " do_assignment not implemented 2"
      end
    | (None, _, _) -> None
    | _ -> (Options.feedback "Skipping assignment @[%a@] = @[%a@] (not implemented)" Lval.pretty lv Exp.pretty exp; a)

  let doInstr (s:stmt)  (i:instr) (a:t) :t =
    match i with
      Set(lv,exp,_) ->
      let new_a = do_assignment a lv exp in
      new_a
    | _ -> (Options.feedback "Skiping @[%a@] (doInstr not implemented)" Stmt.pretty s; a)

  (* let do_stmt (s:stmt) (a:t)  =
   *   (\* let new_a = *\)
   *   match s.skind with
   *   | Instr i -> do_instr s i a
   *   | _ -> failwith "not implemented"
   *          (\* in
   *           * Stmt_table.add s new_a ; new_a *\) *)

  let doGuard _ _ a =
    Dataflow.GUse a, Dataflow.GUse a

  let doStmt (s:stmt) (a:t) =
    (* let f_post (a:t) =
     *   match a with
     * in *)
    ignore (s,a);
    Dataflow.SDefault
  (** The (forwards) transfer function for a statement. The [(Cil.CurrentLoc.get
      ())] * is set before calling this. The default action is to do the
      instructions * in this statement, if applicable, and continue with the
      successors. *)

  let doEdge _ _ a = a
end

module  F = Dataflow.Forwards(T)

let doFunction (kf:kernel_function) =
  Options.feedback ~level:2 "entering in function %a."
    Kernel_function.pretty kf;
  if Kernel_function.has_definition kf then
    let first_stmts = try [Kernel_function.find_first_stmt kf] with Kernel_function.No_Statement -> [] in
    List.iter (fun stmt -> T.StmtStartData.add stmt (Some Abstract_state.initial_value)) first_stmts;
    F.compute first_stmts

let make_summary  _ =
  failwith "make_summary not implemented"

let compute () =
  Ast.compute();
  Options.feedback "Parsing done";
  Globals.Functions.iter doFunction;
  Options.feedback "Functions done"

let clear () =
  failwith "clear not implemented"

let get_abstract_state _ =
  failwith "get_abstract_state not implemented"
