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
  (*  val clear : unit -> unit*)
end


module Make_table(H: Hashtbl.S)(V: sig type t val size :int end) : InternalTable with type key = H.key and type value = V.t = struct
  type key = H.key
  type value = V.t
  let tbl = H.create V.size
  let add = H.add tbl
  let find = H.find tbl
  let iter f =
    H.iter f tbl
    (* let clear () = H.clear tbl*)
end

module A = struct type t = Abstract_state.t option let size = 7 end
module R = struct type t = Abstract_state.summary option let size = 7 end

(*module Stmt_table = Make_table(Cil_datatype.Stmt.Hashtbl)(A)*)
module Function_table = Make_table(Kernel_function.Hashtbl)(R)

let function_compute_ref = Extlib.mk_fun "function_compute"

module D = Dataflow.StartData(A)

module Stmt_table = struct
  include D
  type key = stmt
  type value = data
end



let do_assignment (a:Abstract_state.t option) (lv:lval) (exp:exp) : Abstract_state.t option=
  match a with
    None -> None
  | Some a -> Some (Abstract_state.assignment a lv exp)

let rec do_init vi init state = match init with
  | SingleInit e -> do_assignment state (Var vi, NoOffset) e
  | CompoundInit(_, l) ->
    List.fold_left (fun state (_, init) -> do_init vi init state) state l

let list_instr_warnings : stmt list ref = ref []

let feedback_only_once s =
  if not (List.mem s !list_instr_warnings) then
    begin
      list_instr_warnings := s::!list_instr_warnings;
      Options.feedback "Skipping @[%a@] (summary not found)" Stmt.pretty s
    end

let do_instr (s:stmt)  (i:instr) (a:Abstract_state.t option) : Abstract_state.t option =
  Options.feedback ~level:3 "analysing instruction: %a" Printer.pp_stmt s;
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
      | (Some a, None) -> (Options.feedback "Warning : malloc not stored (ignored)"; Some a)
      | (Some a, Some lv) -> Some (Abstract_state.assignment_x_allocate_y a lv)
    end
  (* general case for calls *)
  | Call(res,ef,es,(loc,_)) -> (* !function_compute_ref ef *)
    begin
      let summary = match Kernel_function.get_called ef with
        | Some kf -> (try Function_table.find kf
                      with Not_found -> !function_compute_ref kf ; Function_table.find kf)
        | None -> Options.abort ~source:loc
                    "Unsupported function pointer (skipped)"
      in
      match (a, summary) with
        (None, _) -> None
      | (Some a, Some summary) ->
        let new_a = Abstract_state.call a res es summary in
        Some new_a
      | (Some a, None) -> (feedback_only_once s; Some a)
    end
  | Asm _ | Local_init _ -> (Options.feedback "Skipping @[%a@] (doInstr not implemented)" Stmt.pretty s; a)




module T =
struct

  let name = "alias"

  let debug = true (* TODO see options *)

  type t = Abstract_state.t option

  module StmtStartData = Stmt_table

  let copy x = x (* we only have persistant data *)

  let pretty fmt a =
    match a with
      None -> Format.fprintf fmt "<No abstract state>"
    | Some a -> Abstract_state.pretty fmt a

  let  computeFirstPredecessor _ a = a

  let combinePredecessors _stmt ~old state =
    match old, state with
    | _, None -> assert false
    | None, Some _ -> Some state (* [old] already included in [state] *)
    | Some old, Some new_ ->
      if Abstract_state.is_included new_ old then
        None
      else
        Some (Some (Abstract_state.union old new_))

  let doInstr = do_instr

  let doGuard _ _ a =
    Dataflow.GUse a, Dataflow.GUse a

  let doStmt _ _ = Dataflow.SDefault

  let doEdge _ _ a = a
end

module  F = Dataflow.Forwards(T)

let do_stmt (a: Abstract_state.t) (s:stmt) :  Abstract_state.t =
  match s.skind with
    Instr i ->
    begin
      match do_instr s i (Some a) with
        None -> Options.fatal "problem here"
      | Some a -> a
    end
  | _ -> a

let analyse_function (kf:kernel_function) =
  Options.feedback ~level:2 "analysing function: %a" Kernel_function.pretty kf;
  if Kernel_function.has_definition kf then
    begin
      let first_stmt =
        try Kernel_function.find_first_stmt kf
        with Kernel_function.No_Statement -> assert false
      in
      T.StmtStartData.add first_stmt (Some Abstract_state.empty);
      F.compute [first_stmt];
      let return_stmt = Kernel_function.find_return kf in
      try Stmt_table.find return_stmt
      with
        Not_found ->
        begin
          Options.debug "return stmt of %a not in table" Kernel_function.pretty kf;
          Options.warning "Analysis is continuing but will not be sound";
          Some (Abstract_state.empty)
        end
    end
  else
    Some Abstract_state.empty

let doFunction (kf:kernel_function) =
  let final_state = analyse_function kf in
  let print_value ?(debug=false) fmt v =
    match v with
    | None -> Format.fprintf fmt "<Bot>"
    | Some a -> Abstract_state.pretty ~debug fmt a
  in
  if Kernel_function.is_main kf then
    (* if main, print the last abstract state *)
    let f_name = Options.Dot_output.get () in
    if f_name = ""
    then
      Options.feedback "May-aliases at the end of function main:@.%a@." (print_value ~debug:false) final_state
    else
      match final_state with
      | None  ->  Options.feedback "Abstract_state at the end of function main: <Bot>@."
      | Some final_state ->
        begin
          Abstract_state.print_dot f_name final_state;
          Options.feedback "Abstract_state at the end of function main:@.%a@." (print_value ~debug:true) (Some final_state)
        end
  else
    (* if not main, do nothing *)
    let summary: Abstract_state.summary =
      Abstract_state.make_summary final_state kf
    in
    Function_table.add kf (Some summary)

let () = function_compute_ref := doFunction

let make_summary (state:Abstract_state.t) (kf:kernel_function) =
  try
    begin
      match Function_table.find kf with
        Some s -> (state, s)
      | None -> Options.fatal "not implemented"
    end
  with
    Not_found ->
    begin
      doFunction kf;
      match Function_table.find kf with
        Some s -> (state, s)
      | None -> Options.fatal "not implemented"
    end

let computed_flag = ref false

let is_computed () = !computed_flag

let compute () =
  Ast.compute();
  Options.debug "Parsing done";
  Globals.Functions.iter doFunction;
  Options.debug "Functions done";
  computed_flag := true;
  let print_stmt_table_elt fmt k v :unit =
    let print_key = Stmt.pretty in
    let print_value fmt v =
      match v with
      | None -> Format.fprintf fmt "<Bot>"
      | Some a -> Abstract_state.pretty fmt a
    in
    Format.fprintf fmt "Before statement %a :@.@[<hov 2> %a@]@." print_key k print_value v
  in
  let print_function_table_elt fmt kf s :unit =
    let function_name =
      Kernel_function.get_name kf
    in
    match s with
      None -> Options.debug "function %s -> None@." function_name
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
  (*Stmt_table*)Stmt_table.clear()

let get_state_before_stmt _kf stmt =
  if is_computed ()
  then
    try Stmt_table.find stmt with
      Not_found -> None
  else
    None

let get_summary kf =
  if is_computed ()
  then
    try Function_table.find kf with
      Not_found -> None
  else
    None
