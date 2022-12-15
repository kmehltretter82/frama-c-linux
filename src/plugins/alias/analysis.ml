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
open Dataflow2
open Abstract_state


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

module A = struct type t = Abstract_state.t let size = 7 end

(* module Stmt_table = Make_table(Cil_datatype.Stmt.Hashtbl)(A)
 * module Function_table = Make_table(Kernel_function.Hashtbl)(A) *)


module D = StartData(A)

module T =
struct

  let name = "alias"

  let debug = true (* TODO see options *)

  type t = Abstract_state.t

  let copy x = x (* we only have persistant data *)

  let pretty = Abstract_state.pretty

  let  computeFirstPredecessor _ a = a

  let combinePredecessors _ ~old a = ignore old ; Some a

  let do_assignment (a:t) (lv:lval) (exp:exp) =
    match (lv,exp.enode) with
      ((Var v1, NoOffset), Lval (Var v2,NoOffset)) ->
      (* case x = y *)
      assignment_x_y a (Var v1, NoOffset) (Var v2, NoOffset)
    | ((Var v1, NoOffset), AddrOf lv2) ->
      (* case x = &y *)
      assignment_x_addr_y a (Var v1, NoOffset) lv2
    | ((Var v1, NoOffset), Lval (Mem e2, NoOffset)) ->
      (* case x  = *y *)
      begin
        match e2.enode with
          Lval lv2 -> assignment_x_ptr_y a (Var v1, NoOffset) lv2
        |  _ -> failwith "not implemented"
      end
    | ((Mem e1, NoOffset), Lval lv2) ->
      (* case *x = y *)
      begin
        match e1.enode with
          Lval lv1 -> assignment_ptr_x_y a lv1 lv2
        |  _ -> failwith "not implemented"
      end
    | _ -> failwith "not implemented"

  let doInstr _  (i:instr) (a:t) =
    match i with
      Set(lv,exp,_) -> do_assignment a lv exp
    | _ -> failwith "not implemented"

  (* let do_stmt (s:stmt) (a:t)  =
   *   (\* let new_a = *\)
   *   match s.skind with
   *   | Instr i -> do_instr s i a
   *   | _ -> failwith "not implemented"
   *          (\* in
   *           * Stmt_table.add s new_a ; new_a *\) *)

  let doGuard _ _ a =
    GUse a, GUse a

  let doStmt (s:stmt) (a:t) =
    ignore (s,a);
    SDefault
  (** The (forwards) transfer function for a statement. The [(Cil.CurrentLoc.get
      ())] * is set before calling this. The default action is to do the
      instructions * in this statement, if applicable, and continue with the
      successors. *)

  let doEdge _ _ a = a

  module StmtStartData = D
end

module  F = Forwards(T)

let doFunction (f:kernel_function) =
  F.compute (fst (find_stmts (Kernel_function.get_definition f)))

let make_summary  _ =
  failwith "not implemented"

let compute () =
  Ast.compute();
  Options.feedback "Parsing done";
  Globals.Functions.iter doFunction;
  Options.feedback "Functions done"

let clear () =
  failwith "not implemented"

let get_abstract_state _ =
  failwith "not implemented"
