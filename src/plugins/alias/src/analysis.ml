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
open Cil_datatype

module Dataflow = Dataflow2

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

module type InternalTable = sig
  include Table
  val add : key -> value -> unit
  val iter : (key -> value -> unit) -> unit
end

module Make_table (H: Hashtbl.S) (V: sig type t val size : int end)
  : InternalTable with type key = H.key and type value = V.t = struct
  type key = H.key
  type value = V.t
  let tbl = H.create V.size
  let add = H.replace tbl
  let find = H.find tbl
  let iter f = H.iter f tbl
end

(* In Function_table, value None means the function has no definition *)
module Function_table = Make_table (Kernel_function.Hashtbl) (struct
    type t = Abstract_state.summary option
    let size = 7
  end)

let function_compute_ref = Extlib.mk_fun "function_compute"

(* In Stmt_table, value None means abstract state = Bottom *)
module Stmt_table = struct
  include Dataflow.StartData (struct
      type t = Abstract_state.t option
      let size = 7
    end)
  type key = stmt
  type value = data
end

let warn_unsupported_explicit_pointer pp_obj obj loc =
  Options.warning ~source:(fst loc) ~wkey:Options.Warn.unsupported_address
    "unsupported feature: explicit pointer address: %a; analysis may be unsound" pp_obj obj

let do_assignment (lv:lval) (exp:exp) (a:Abstract_state.t) : Abstract_state.t =
  try Abstract_state.assignment a lv exp
  with Simplified.Explicit_pointer_address loc ->
    warn_unsupported_explicit_pointer  Printer.pp_exp exp loc;
    a

let rec do_init (lv:lval) (init:init) state =
  match init with
  | SingleInit e -> Option.map (do_assignment lv e) state
  | CompoundInit (_, l) ->
    List.fold_left (fun state (o, init) -> do_init (Cil.addOffsetLval o lv) init state) state l

let doFunction f = !function_compute_ref f

let do_function_call (stmt:stmt) state (res : lval option) (ef : exp) (args: exp list) loc =
  let is_malloc (s:string) : bool =
    (s = "malloc") || (s = "calloc") (* todo : add all function names *)
  in
  match ef with
  | {enode=Lval (Var v, _);_}  when is_malloc v.vname ->
    (* special case for malloc *)
    begin match (state, res) with
      | (None, _) -> None
      | (Some a, None) -> (Options.warning "Memory allocation not stored (ignored)"; Some a)
      | (Some a, Some lv) ->
        try Some (Abstract_state.assignment_x_allocate_y a lv)
        with Simplified.Explicit_pointer_address loc ->
          warn_unsupported_explicit_pointer Printer.pp_stmt stmt loc;
          Some a
    end
  | _ -> (* general case *)
    let get_function kf = try Function_table.find kf with Not_found -> doFunction kf in
    let summaries =
      match Kernel_function.get_called ef with
      | Some kf when Kernel_function.is_main kf -> []
      | Some kf -> [get_function kf]
      | None -> (* dereference function pointer using the results of the points-to analysis *)
        begin match ef, Stmt_table.find stmt with
          | {enode = Lval lv; _}, Some state ->
            let targets = Abstract_state.find_vars lv state in
            Options.feedback ~level:3 "%a is an indirect function call to one of %a"
              Printer.pp_stmt stmt
              Abstract_state.VarSet.pretty targets;
            let kf_of_var {vname; _} =
              try Some (Globals.Functions.find_def_by_name vname) with Not_found -> None
            in
            let kfs = Seq.filter_map kf_of_var @@ Abstract_state.VarSet.to_seq targets in
            List.of_seq @@ Seq.map get_function kfs
          | _ ->
            Options.fatal "unsupported call to function pointer: %a" Exp.pretty ef
        end
    in
    let apply_summary state summary =
      match (state, summary) with
      | (None, _) -> None
      | (Some a, Some summary) -> Some (Abstract_state.call a res args summary)
      | (Some a, None) ->
        Options.warning ~wkey:Options.Warn.undefined_function ~once:true ~source:(fst loc)
          "function %a has no definition" Exp.pretty ef;
        Some a
    in
    List.fold_left apply_summary state summaries

let do_cons_init (s:stmt) (v:varinfo) f arg t loc state =
  Cil.treat_constructor_as_func (do_function_call s state) v f arg t loc

let analyse_instr (s:stmt) (i:instr) (a:Abstract_state.t option) : Abstract_state.t option =
  match i with
  | Set (lv,exp,_) -> Option.map (do_assignment lv exp) a
  | Local_init (v,AssignInit i,_) -> do_init (Var v, NoOffset) i a
  | Local_init (v,ConsInit (f,arg,t),loc) -> do_cons_init s v f arg t loc a
  | Code_annot _ -> a
  | Skip _ -> a
  | Call (res,ef,es,loc) -> do_function_call s a res ef es loc
  | Asm (_,_,_,loc) ->
    Options.warning
      ~source:(fst loc) ~wkey:Options.Warn.unsupported_asm
      "unsupported feature: assembler code; skipping";
    a

let pp_abstract_state_opt ?(debug=false) fmt v =
  match v with
  | None -> Format.fprintf fmt "⊥"
  | Some a -> Abstract_state.pretty ~debug fmt a

let do_instr (s:stmt) (i:instr) (a:Abstract_state.t option) : Abstract_state.t option =
  Options.feedback ~level:3 "@[analysing instruction:@ %a@]" Printer.pp_stmt s;
  let result = analyse_instr s i a in
  Options.feedback ~level:3 "@[May-aliases after instruction@;<2>@[%a@]@;<2>are@;<2>@[%a@]@]"
    Printer.pp_stmt s (pp_abstract_state_opt ~debug:false) result;
  Options.debug ~level:3 "@[May-alias graph after instruction@;<2>@[%a@]@;<2>is@;<4>@[%a@]@]"
    Printer.pp_stmt s (pp_abstract_state_opt ~debug:true) result;
  result

module T = struct
  let name = "alias"

  let debug = true (* TODO see options *)

  type t = Abstract_state.t option

  module StmtStartData = Stmt_table

  let copy x = x (* we only have persistant data *)

  let pretty fmt a =
    match a with
    | None -> Format.fprintf fmt "<No abstract state>"
    | Some a -> Abstract_state.pretty fmt a

  let computeFirstPredecessor _ a = a

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

  let doGuard _ _ a = Dataflow.GUse a, Dataflow.GUse a

  let doStmt _ _ = Dataflow.SDefault

  let doEdge _ _ a = a
end

module F = Dataflow.Forwards (T)

let do_stmt (a: Abstract_state.t) (s:stmt) :  Abstract_state.t =
  match s.skind with
  | Instr i ->
    begin match do_instr s i (Some a) with
      | None -> Options.fatal "problem here"
      | Some a -> a
    end
  | _ -> a

let analyse_function (kf:kernel_function) =
  if not @@ Kernel_function.has_definition kf then None else begin
    Options.feedback ~level:2 "analysing function: %a" Kernel_function.pretty kf;
    let first_stmt =
      try Kernel_function.find_first_stmt kf
      with Kernel_function.No_Statement -> assert false
    in
    T.StmtStartData.add first_stmt (Some Abstract_state.empty);
    F.compute [first_stmt];
    let return_stmt = Kernel_function.find_return kf in
    try Stmt_table.find return_stmt
    with Not_found ->
      let source, _ = Kernel_function.get_location kf in
      Options.warning ~source ~wkey:Options.Warn.no_return_stmt
        "function %a does not return; analysis may be unsound"
        Kernel_function.pretty kf;
      Some Abstract_state.empty
  end

let doFunction (kf:kernel_function) =
  let final_state = analyse_function kf in
  let level = if Kernel_function.is_main kf then 1 else 2 in
  final_state |> Option.iter (fun s ->
      Options.feedback ~level "@[May-aliases at the end of function %a:@ @[%a@]"
        Kernel_function.pretty kf
        (Abstract_state.pretty ~debug:false) s;
      Options.debug ~level "May-alias graph at the end of function %a:@;<4>@[%a@]"
        Kernel_function.pretty kf
        (Abstract_state.pretty ~debug:true)s;
    );
  let result =
    match final_state with
    (* final state is None if kf has no definition *)
    | None -> None
    | Some fs ->
      let summary = Abstract_state.make_summary fs kf in
      Options.debug ~level:2 "Summary of function %a:@ @[%a@]"
        Kernel_function.pretty kf
        (Abstract_state.pretty_summary ~debug:false) summary;
      Some summary
  in
  if Kernel_function.is_main kf then begin
    match Options.Dot_output.get (), final_state with
    | "", _ -> ()
    | _, None -> ()
    | fname, Some final_state -> Abstract_state.print_dot fname final_state
  end;
  Function_table.add kf result;
  result

let () = function_compute_ref := doFunction

let make_summary (state:Abstract_state.t) (kf:kernel_function) =
  try begin match Function_table.find kf with
    | Some s -> (state, s)
    | None -> Options.fatal "not implemented"
  end
  with Not_found ->
    begin match doFunction kf with
      | Some s -> (state, s)
      | None -> Options.fatal "not implemented"
    end

let computed_flag = ref false

let is_computed () = !computed_flag

let print_stmt_table_elt fmt k v :unit =
  let print_key = Stmt.pretty in
  let print_value fmt v =
    match v with
    | None -> Format.fprintf fmt "<Bot>"
    | Some a -> Abstract_state.pretty ~debug:(Options.DebugTable.get ()) fmt a
  in
  Format.fprintf fmt "Before statement %a :@[<hov 2> %a@]@." print_key k print_value v

let print_function_table_elt fmt kf s : unit =
  let function_name = Kernel_function.get_name kf in
  match s with
  | None -> Options.debug "function %s -> None" function_name
  | Some s ->
    Format.fprintf fmt "Summary of function %s:@;<5 2>@[%a@]@."
      function_name
      (Abstract_state.pretty_summary ~debug:(Options.DebugTable.get ())) s

let compute () =
  Ast.compute ();
  Globals.Functions.iter (fun kf -> ignore @@ doFunction kf);
  computed_flag := true;
  if Options.ShowStmtTable.get () then
    Stmt_table.iter (print_stmt_table_elt Format.std_formatter);
  if Options.ShowFunctionTable.get () then
    Function_table.iter (print_function_table_elt Format.std_formatter)

let clear () =
  computed_flag := false;
  Stmt_table.clear ()

let get_state_before_stmt stmt =
  if is_computed ()
  then try Stmt_table.find stmt with Not_found -> None
  else None

let get_summary kf =
  if is_computed ()
  then try Function_table.find kf with Not_found -> None
  else None
