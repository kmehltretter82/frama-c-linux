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
end


module Make_table(H: Hashtbl.S)(V: sig type t val size :int end) : InternalTable with type key = H.key and type value = V.t = struct
  type key = H.key
  type value = V.t
  let tbl = H.create V.size
  let add = H.replace tbl
  let find = H.find tbl
  let iter f =
    H.iter f tbl
end


module A = struct type t = Abstract_state.t option let size = 7 end
module R = struct type t = Abstract_state.summary option let size = 7 end

(* In Function_table, value None means the function has no definition *)
module Function_table = Make_table(Kernel_function.Hashtbl)(R)

let function_compute_ref = Extlib.mk_fun "function_compute"

module D = Dataflow.StartData(A)

(* In Stmt_table, value None means abstract state = Bottom *)
module Stmt_table = struct
  include D
  type key = stmt
  type value = data
end



let do_assignment (a:Abstract_state.t option) (lv:lval) (exp:exp) : Abstract_state.t option=
  match a with
    None -> None
  | Some a -> Some (Abstract_state.assignment a lv exp)

let rec do_init (lv:lval) (init:init) state =
  match init with
  | SingleInit e -> do_assignment state lv e
  | CompoundInit(_, l) ->
    List.fold_left (fun state (o, init) -> do_init (Cil.addOffsetLval o lv) init state) state l

let doFunction f = !function_compute_ref f

let do_function_call (_:stmt) state (res : lval option) (ef : exp) (args: exp list) loc =
  let is_malloc (s:string) : bool =
    (s = "malloc") || (s = "calloc") (* todo : add all function names *)
  in
  match ef with
  | {enode=Lval (Var v, _);_}  when is_malloc v.vname ->
    begin
      (* special case for malloc *)
      match (state,res) with
        (None, _) -> None
      | (Some a, None) -> (Options.warning "Memory allocation not stored (ignored)"; Some a)
      | (Some a, Some lv) -> Some (Abstract_state.assignment_x_allocate_y a lv)
    end
  | _ ->
    begin
      (* general case *)
      let summary =
        match Kernel_function.get_called ef with
        | Some kf when Kernel_function.is_main kf -> None
        | Some kf -> begin
            try Function_table.find kf
            with Not_found -> doFunction kf; Function_table.find kf
          end
        | None ->
          Options.warning ~wkey:Options.Warn.unsupported_function ~source:(fst loc)
            "calls to function pointer unsupported: %a" Exp.pretty ef;
          None
      in
      match (state, summary) with
        (None, _) -> None
      | (Some a, Some summary) ->
        Some(Abstract_state.call a res args summary)
      | (Some a, None) ->
        Options.warning ~wkey:Options.Warn.undefined_function ~once:true ~source:(fst loc)
          "function %a has no definition" Exp.pretty ef;
        Some a
    end

let do_cons_init (s:stmt) (v:varinfo) f arg t  loc state =
  Cil.treat_constructor_as_func (do_function_call s state) v f arg t loc


let do_instr (s:stmt)  (i:instr) (a:Abstract_state.t option) : Abstract_state.t option =
  match i with
    Set(lv,exp,_) ->
    let new_a = do_assignment a lv exp in
    new_a
  | Local_init(v,AssignInit i,_) ->
    let new_a = do_init (Var v, NoOffset) i a in
    new_a
  | Local_init(v,ConsInit (f,arg,t),loc) ->
    let new_a = do_cons_init s v f arg t loc a in
    new_a
  | Code_annot _ -> a
  | Skip _ -> a
  | Call(res,ef,es,loc) -> (* !function_compute_ref ef *)
    do_function_call s a res ef es loc
  | Asm _ -> (Options.warning "skipping @[%a@] (Asm not implemented)" Printer.pp_stmt s; a)

let pp_abstract_state_opt ?(debug=false) fmt v =
  match v with
  | None -> Format.fprintf fmt "<Bot>"
  | Some a -> Abstract_state.pretty ~debug fmt a

let do_instr (s:stmt)  (i:instr) (a:Abstract_state.t option) : Abstract_state.t option =
  Options.feedback ~level:3 "analysing instruction: %a" Printer.pp_stmt s;
  let result = do_instr s i a in
  Options.feedback ~level:3 "May-aliases at the end of instruction:@.%a@." (pp_abstract_state_opt ~debug:false) result;
  Options.debug ~level:3 "May-alias graph at the end of instruction:@.%a@." (pp_abstract_state_opt ~debug:true) result;
  result


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
      with Not_found ->
        begin
          let source, _ = Kernel_function.get_location kf in
          Options.warning ~source ~wkey:Options.Warn.no_return_stmt
            "function %a does not return; analysis is continuing but is not be sound"
            Kernel_function.pretty kf;
          Some (Abstract_state.empty)
        end
    end
  else
    Some Abstract_state.empty

let doFunction (kf:kernel_function) =
  let final_state = analyse_function kf in
  let level = if Kernel_function.is_main kf then 1 else 2 in
  Options.feedback ~level "May-aliases at the end of function %a:@.%a@."
    Kernel_function.pretty kf
    (pp_abstract_state_opt ~debug:false) final_state;
  Options.debug ~level "May-alias graph at the end of function %a:@.%a@."
    Kernel_function.pretty kf
    (pp_abstract_state_opt ~debug:true) final_state;
  let summary = Abstract_state.make_summary final_state kf in
  let function_name = Kernel_function.get_name kf in
  Options.debug ~level:2 "Summary of function %a:@.%a@."
    Kernel_function.pretty kf
    (Abstract_state.pretty_summary ~debug:false ~function_name) summary;
  if Kernel_function.is_main kf then
    let f_name = Options.Dot_output.get () in
    match f_name, final_state with
    | "", _ -> ()
    | _, None -> ()
    | _, Some final_state -> Abstract_state.print_dot f_name final_state
  else
    begin
      (* use None to encode functions that have no definition *)
      if Kernel_function.has_definition kf
      then Function_table.add kf @@ Some summary
      else Function_table.add kf None
    end

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
      Function_table.iter (fun x _ -> Format.printf "entry of function %a @." Kernel_function.pretty x);
      Function_table.iter (print_function_table_elt Format.std_formatter)
    end


let clear () =
  computed_flag := false;
  Stmt_table.clear()

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
