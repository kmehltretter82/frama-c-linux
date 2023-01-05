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

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

module type InternalTable  = sig
  include Table
  val add : key -> value -> unit
  val pretty : Format.formatter -> (Format.formatter -> key -> unit) -> (Format.formatter -> value -> unit) -> unit
  val clear : unit -> unit
end


module Make_table(H: Hashtbl.S)(V: sig type t val size :int end) : InternalTable with type key = H.key and type value = V.t = struct
  type key = H.key
  type value = V.t
  let tbl = H.create V.size
  let add = H.add tbl
  let find = H.find tbl
  let pretty fmt print_key print_value =
    Format.fprintf fmt "@[<hov 2>";
    H.iter (fun k v -> Format.fprintf fmt "After statement %a :@. @[<2>%a@] @." print_key k print_value v) tbl;
    Format.fprintf fmt "@]@."
  let clear () = H.clear tbl
end

module A = struct type t = Abstract_state.t option let size = 7 end
module R = struct type t = Abstract_state.summary option let size = 7 end

module Stmt_table = Make_table(Cil_datatype.Stmt.Hashtbl)(A)
module Function_table = Make_table(Kernel_function.Hashtbl)(R)


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

  (* type of the return of the following function *)
  type basic_lval =  BNone | BLval of lval | BAddrOf of lval 
    
  (* finds, in an expression, the "basic" lval (eg a variable, a pointer or an array name). *)
  let rec find_basic_lval (exp:exp) : basic_lval =
    match exp.enode with
      Lval lv -> BLval lv
    | AddrOf lv -> BAddrOf lv
    | CastE (_,exp) -> find_basic_lval exp
    | UnOp (_,exp,_) -> find_basic_lval exp
    | BinOp (_,exp1,exp2,_) ->
      begin
        match (find_basic_lval exp1, find_basic_lval exp2) with
          (BNone,BNone) -> BNone
        | (BNone, res2) -> res2
        | (res1, BNone) -> res1
        | _ -> failwith "find_basic_lval: 2 basic lval in a BinOp"
      end
    | _ -> BNone

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
    | _ -> (Options.feedback "Skiping @[%a@] (doInstr not implemented)" Stmt.pretty s; a)

  let doGuard _ _ a =
    Dataflow.GUse a, Dataflow.GUse a

  let doStmt (s:stmt) (a:t) =
    (* let _, kf = Kernel_function.find_from_sid s.sid in
     * let is_first = Kernel_function.is_first_stmt kf s in
     * let is_last = Kernel_function.is_return_stmt kf s in *)
    let new_a = match s.skind with
        Instr i -> doInstr s i a
      | _ -> a
    in
    begin match new_a with
        None -> ()
      | Some a -> Stmt_table.add s (Some a)
    end;
    Dataflow.SUse new_a



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


let computed_flag = ref false

let is_computed () = !computed_flag

let compute () =
  Ast.compute();
  Options.feedback "Parsing done";
  Globals.Functions.iter doFunction;
  Options.feedback "Functions done";
  computed_flag := true;
  let value_pretty fmt a =
    match a with
    | None -> Format.fprintf fmt "<Bot>"
    | Some a -> Abstract_state.pretty fmt a
  in
  Stmt_table.pretty Format.std_formatter Stmt.pretty value_pretty


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
