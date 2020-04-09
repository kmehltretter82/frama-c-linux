(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

let dkey = Options.dkey_prepare

(* ********************************************************************** *)
(* Environment *)
(* ********************************************************************** *)

let fct_tbl: unit Kernel_function.Hashtbl.t = Kernel_function.Hashtbl.create 7

(* The purpose of [actions] is similar to the Frama-C visitor's
   [get_filling_actions] but we need to fill it outside the visitor. So it is
   our own version. *)
let actions = Queue.create ()

(* global table for ensuring that logic info are not shared between a function
   definition and its duplicate *)
module Global: sig
  val add_logic_info: logic_info -> unit
  val mem_logic_info: logic_info -> bool
  val reset: unit -> unit
end = struct

  let tbl = Cil_datatype.Logic_info.Hashtbl.create 7
  let add_logic_info x = Cil_datatype.Logic_info.Hashtbl.add tbl x ()
  let mem_logic_info x = Cil_datatype.Logic_info.Hashtbl.mem tbl x
  let reset () = Cil_datatype.Logic_info.Hashtbl.clear tbl

end

let reset () =
  Kernel_function.Hashtbl.clear fct_tbl;
  Global.reset ();
  Queue.clear actions

(* ********************************************************************** *)
(* Duplicating a function *)
(* ********************************************************************** *)

(* [tbl] associates the old formals to the new ones *)
let dup_funspec tbl bhv spec =
  (*  Options.feedback "DUP SPEC %a" Cil.d_funspec spec;*)
  let o = object
    inherit Cil.genericCilVisitor bhv

    val already_visited = Cil_datatype.Logic_var.Hashtbl.create 7

    method !vlogic_info_use li =
      if Global.mem_logic_info li then
        Cil.ChangeDoChildrenPost
          ({ li with l_var_info = li.l_var_info } (* force a copy *),
           Visitor_behavior.Get.logic_info bhv)
      else
        Cil.JustCopy

    method !vterm_offset _ =
      Cil.DoChildrenPost
        (function (* no way to directly visit fieldinfo and model_info uses *)
          | TField(fi, off) ->
            TField(Visitor_behavior.Get.fieldinfo bhv fi, off)
          | TModel(mi, off) ->
            TModel(Visitor_behavior.Get.model_info bhv mi, off)
          | off ->
            off)

    method !vlogic_var_use orig_lvi =
      match orig_lvi.lv_origin with
      | None ->
        Cil.JustCopy
      | Some vi ->
        try
          let new_lvi =
            Cil_datatype.Logic_var.Hashtbl.find already_visited orig_lvi
          in
          Cil.ChangeTo new_lvi
        with Not_found ->
          Cil.ChangeDoChildrenPost
            ({ orig_lvi with lv_id = orig_lvi.lv_id } (* force a copy *),
             fun lvi ->
               try
                 let new_vi = Cil_datatype.Varinfo.Hashtbl.find tbl vi in
                 Cil_datatype.Logic_var.Hashtbl.add
                   already_visited orig_lvi lvi;
                 (* [lvi] is the logic counterpart of a formal varinfo that has
                    been replaced by a new one: propagate this change *)
                 lvi.lv_id <- new_vi.vid;
                 lvi.lv_name <- new_vi.vname;
                 lvi.lv_origin <- Some new_vi;
                 new_vi.vlogic_var_assoc <- Some lvi;
                 lvi
               with Not_found ->
                 assert vi.vglob;
                 (* using [Visitor_behavior.Get.logic_var bhv lvi] is correct
                    only because the lv_id used to compare the lvi does not
                    change between the original one and this copy *)
                 Visitor_behavior.Get.logic_var bhv lvi)

    method !videntified_term _ =
      Cil.DoChildrenPost Logic_const.refresh_identified_term

    method !videntified_predicate _ =
      Cil.DoChildrenPost Logic_const.refresh_predicate
  end in
  Cil.visitCilFunspec o spec

let dup_fundec loc spec bhv sound_verdict_vi kf vi new_vi =
  new_vi.vdefined <- true;
  let formals = Kernel_function.get_formals kf in
  let mk_formal vi =
    let name =
      if vi.vname = "" then
        (* unnamed formal parameter: must generate a fresh name since a fundec
           cannot have unnamed formals (see bts #2303). *)
        Varname.get
          ~scope:Varname.Function
          (Functions.RTL.mk_gen_name "unamed_formal")
      else
        vi.vname
    in
    Cil.copyVarinfo vi name
  in
  let new_formals = List.map mk_formal formals in
  let res =
    let ty = Kernel_function.get_return_type kf in
    if Cil.isVoidType ty
    then None
    else Some (Cil.makeVarinfo false false ~referenced:true "__retres" ty)
  in
  let return =
    Cil.mkStmt ~valid_sid:true
      (Return(Extlib.opt_map (Cil.evar ~loc) res, loc))
  in
  let stmts =
    let l =
      [ Cil.mkStmtOneInstr ~valid_sid:true
          (Call(Extlib.opt_map Cil.var res,
                Cil.evar ~loc vi,
                List.map (Cil.evar ~loc) new_formals,
                loc));
        return ]
    in
    if Functions.instrument kf then
      l
    else
      (* set the 'sound_verdict' variable to 'false' whenever required *)
      let unsound =
        Cil.mkStmtOneInstr ~valid_sid:true
          (Set((Var sound_verdict_vi, NoOffset), Cil.zero ~loc, loc))
      in
      unsound :: l
  in
  let locals = match res with None -> [] | Some r -> [ r ] in
  let body = Cil.mkBlock stmts in
  body.blocals <- locals;
  let tbl = Cil_datatype.Varinfo.Hashtbl.create 7 in
  List.iter2 (Cil_datatype.Varinfo.Hashtbl.add tbl) formals new_formals;
  let new_spec = dup_funspec tbl bhv spec in
  let fundec =
    { svar = new_vi;
      sformals = new_formals;
      slocals = locals;
      smaxid = List.length new_formals;
      sbody = body;
      smaxstmtid = None;
      sallstmts = [];
      sspec = new_spec }
  in
  (* compute the CFG of the new [fundec] *)
  Cfg.clearCFGinfo ~clear_id:false fundec;
  Cfg.cfgFun fundec;
  fundec

let dup_global loc actions spec bhv sound_verdict_vi kf vi new_vi =
  let name = vi.vname in
  Options.feedback ~dkey ~level:2 "entering in function %s" name;
  let fundec = dup_fundec loc spec bhv sound_verdict_vi kf vi new_vi  in
  let fct = Definition(fundec, loc) in
  let new_spec = fundec.sspec in
  let new_kf = { fundec = fct; spec = new_spec } in
  Queue.add
    (fun () ->
       Kernel_function.Hashtbl.add fct_tbl new_kf ();
       Globals.Functions.register new_kf;
       Globals.Functions.replace_by_definition new_spec fundec loc;
       Annotations.register_funspec new_kf;
       if new_vi.vname = "main" then begin
         (* recompute the info about the old main since its name has changed;
            see the corresponding part in the main visitor *)
         Globals.Functions.remove vi;
         Globals.Functions.register kf
       end)
    actions;
  (* remove the specs attached to the previous kf iff it is a definition:
     it is necessary to keep stable the number of annotations in order to get
     [Keep_status] working fine. *)
  let kf = Visitor_behavior.Get.kernel_function bhv kf in
  if Kernel_function.is_definition kf then begin
    Queue.add
      (fun () ->
         let bhvs =
           Annotations.fold_behaviors (fun e b acc -> (e, b) :: acc) kf []
         in
         List.iter
           (fun (e, b) -> Annotations.remove_behavior ~force:true e kf b)
           bhvs;
         Annotations.iter_decreases
           (fun e _ -> Annotations.remove_decreases e kf)
           kf;
         Annotations.iter_terminates
           (fun e _ -> Annotations.remove_terminates e kf)
           kf;
         Annotations.iter_complete
           (fun e l -> Annotations.remove_complete e kf l)
           kf;
         Annotations.iter_disjoint
           (fun e l -> Annotations.remove_disjoint e kf l)
           kf)
      actions
  end;
  GFun(fundec, loc), GFunDecl(new_spec, new_vi, loc)

(* ********************************************************************** *)
(* Alignment *)
(* ********************************************************************** *)

(* Returns true if the list of attributes [attrs] contains an [align] attribute
   of [algn] or greater. Returns false otherwise.
   Throws an exception if
   - [attrs] contains several [align] attributes specifying different
     alignments
   - [attrs] has a single align attribute with a value which is less than
     [algn] *)
let sufficiently_aligned vi algn =
  let alignment =
    List.fold_left
      (fun acc attr ->
         match attr with
         | Attr("align", [AInt i]) ->
           let alignment = Integer.to_int i in
           if acc <> 0 && acc <> alignment then begin
             (* multiple align attributes with different values *)
             Options.error
               "multiple alignment attributes with different values for\
                variable %a. Keeping the last one."
               Printer.pp_varinfo vi;
             alignment
           end else if alignment < algn then begin
             (* if there is an alignment attribute it should be greater or equal
                to [algn] *)
             Options.error
               "alignment of variable %a should be greater or equal to %d.@ \
                Continuing with this value."
               Printer.pp_varinfo vi
               algn;
             algn
           end else
             alignment
         | Attr("align", _) ->
           (* align attribute with an argument other than a single number,
              should not happen really *)
           assert false
         | _ -> acc)
      0
      vi.vattr
  in
  alignment > 0

(* return [true] iff the given [vi] requires to be aligned at the boundary
   of [algn] (i.e., less than [algn] bytes and has no alignment attribute) *)
let require_alignment vi algn =
  Cil.bitsSizeOf vi.vtype < algn*8 && not (sufficiently_aligned vi algn)

(* ********************************************************************** *)
(* Visitor *)
(* ********************************************************************** *)

class prepare_visitor = object (self)
  inherit Visitor.frama_c_inplace

  val mutable has_new_stmt_in_fundec = false

  (* ---------------------------------------------------------------------- *)
  (* visitor's local variable *)
  (* ---------------------------------------------------------------------- *)

  val terms = Misc.Id_term.Hashtbl.create 7
  (* table for ensuring absence of term sharing *)

  val unduplicable_functions =
    let white_list =
      [ "__builtin_va_arg";
        "__builtin_va_end";
        "__builtin_va_start";
        "__builtin_va_copy" ]
    in
    List.fold_left
      (fun acc s -> Datatype.String.Set.add s acc)
      Datatype.String.Set.empty
      white_list

  val fct_tbl = Cil_datatype.Varinfo.Hashtbl.create 7
  val mutable new_definitions: global list = []
  (* new definitions of the annotated functions which will contain the
     translation of the E-ACSL contract *)

  (* the variable [sound_verdict] belongs to the E-ACSL's RTL and indicates
     whether the verdict emitted by E-ACSL is sound. It needs to be visible at
     that point because it is set in all function duplicates
     (see [dup_fundec]). *)
  val mutable sound_verdict_vi =
    let name = Functions.RTL.mk_api_name "sound_verdict" in
    let vi = Cil.makeGlobalVar name Cil.intType in
    vi.vstorage <- Extern;
    vi.vreferenced <- true;
    vi

  (* ---------------------------------------------------------------------- *)
  (* visitor's private methods *)
  (* ---------------------------------------------------------------------- *)

  method private is_variadic_function vi =
    match Cil.unrollType vi.vtype with
    | TFun(_, _, variadic, _) -> variadic
    | _ -> true

  (* ---------------------------------------------------------------------- *)
  (* visitor's method overloading *)
  (* ---------------------------------------------------------------------- *)

  method !vlogic_info_decl li =
    Global.add_logic_info li;
    Cil.SkipChildren

  method !vvrbl vi =
    try
      let new_vi = Cil_datatype.Varinfo.Hashtbl.find fct_tbl vi in
      (* replace functions at callsite by its duplicated version *)
      Cil.ChangeTo new_vi
    with Not_found ->
      Cil.SkipChildren

  method !vterm _t =
    Cil.DoChildrenPost
      (fun t ->
         if Misc.Id_term.Hashtbl.mem terms t then
           (* remove term sharing for soundness of E-ACSL typing
              (see typing.ml) *)
           { t with term_node = t.term_node }
         else begin
           Misc.Id_term.Hashtbl.add terms t ();
           t
         end)

  (* Add align attributes to local variables (required by temporal analysis) *)
  method !vblock _ =
    if Options.Temporal_validity.get () then
      Cil.DoChildrenPost
        (fun blk ->
           List.iter
             (fun vi ->
                (* 4 bytes alignment is required to allow sufficient space for
                   storage of 32-bit timestamps in a 1:1 shadow. *)
                if require_alignment vi 4 then
                  vi.vattr <-
                    Attr("aligned", [ AInt Integer.four ]) :: vi.vattr)
             blk.blocals;
           blk)
    else
      Cil.DoChildren

  method !vfunc fundec =
    Cil.DoChildrenPost
      (fun _ ->
         if has_new_stmt_in_fundec then begin
           has_new_stmt_in_fundec <- false;
           (* recompute the CFG *)
           Cfg.clearCFGinfo ~clear_id:false fundec;
           Cfg.cfgFun fundec;
         end;
         fundec)

  method !vglob_aux = function
    | GFunDecl(_, vi, loc) | GFun({ svar = vi }, loc)
      when (* duplicate a function iff: *)
        (* it is not already duplicated *)
        not (Cil_datatype.Varinfo.Hashtbl.mem fct_tbl vi)
        && (* it is duplicable *)
        not (Datatype.String.Set.mem vi.vname unduplicable_functions)
        && (* it is not a variadic function *)
        not (self#is_variadic_function vi)
        && (* it is not a built-in *)
        not (Misc.is_fc_or_compiler_builtin vi)
        &&
        (let kf =
           try Globals.Functions.get vi with Not_found -> assert false
         in
         (* either explicitely listed as to be not instrumented *)
         not (Functions.instrument kf)
         ||
         (* or: *)
         ((* it has a function contract *)
           not (Cil.is_empty_funspec
                  (Annotations.funspec ~populate:false
                     (Extlib.the self#current_kf)))
           && (* its annotations must be monitored *)
           Functions.check kf))
      ->
      let name = Functions.RTL.mk_gen_name vi.vname in
      let new_vi = Cil.makeGlobalVar name vi.vtype in
      Cil_datatype.Varinfo.Hashtbl.add fct_tbl vi new_vi;
      Cil.DoChildrenPost
        (fun l -> match l with
           | [ GFunDecl(_, vi, _) | GFun({ svar = vi }, _) as g ]
             ->
             let kf = Extlib.the self#current_kf in
             (match g with
              | GFunDecl _ ->
                if not (Kernel_function.is_definition kf)
                && vi.vname <> "malloc" && vi.vname <> "free"
                then
                  Options.warning
                    "@[annotating undefined function `%a':@ \
                     the generated program may miss memory instrumentation@ \
                     if there are memory-related annotations.@]"
                    Printer.pp_varinfo vi
              | GFun _ -> ()
              | _ -> assert false);
             let tmp = vi.vname in
             if tmp = "main" then begin
               (* the new function becomes the new main: *)
               (* 1. swap the name of both functions *)
               vi.vname <- new_vi.vname;
               new_vi.vname <- tmp;
               (* 2. force recomputation of the entry point if necessary *)
               if Kernel.MainFunction.get () = tmp then begin
                 let selection =
                   State_selection.with_dependencies Kernel.MainFunction.self
                 in
                 Project.clear ~selection ()
               end
               (* 3. recompute what is necessary in [Globals.Functions]:
                  done in [dup_global] *)
             end;
             let new_g, new_decl =
               dup_global
                 loc
                 self#get_filling_actions
                 (Annotations.funspec ~populate:false kf)
                 self#behavior
                 sound_verdict_vi
                 kf
                 vi
                 new_vi
             in
             (* postpone the introduction of the new function definition to the
                end *)
             new_definitions <- new_g :: new_definitions;
             (* put the declaration before the original function in order to
                solve issue with recursive functions *)
             [ new_decl; g ]
           | _ -> assert false)

    | GVarDecl(vi, _loc) | GFunDecl(_, vi, _loc) | GFun({ svar = vi }, _loc)
      when Misc.is_fc_or_compiler_builtin vi ->
      Cil.DoChildren

    | _ ->
      Cil.DoChildren

  method !vfile f =
    Cil.DoChildrenPost
      (fun _ ->
         match new_definitions with
         | [] -> f
         | _ :: _ ->
           (* add the generated definitions of libc at the end of
              [new_definitions]. This way, we are sure that they have access to
              all of it (in particular, the memory model, GMP and the soundness
              variable). Also add the [__e_acsl_sound_verdict] variable at the
              beginning *)
           let new_globals =
             GVarDecl(sound_verdict_vi, Cil_datatype.Location.unknown)
             :: f.globals
             @ new_definitions
           in
           f.globals <- new_globals;
           f)

  initializer
    reset ()

end

let prepare () =
  Options.feedback ~level:2 "prepare AST for E-ACSL transformations";
  Visitor.visitFramacFile (new prepare_visitor) (Ast.get ());
  Queue.iter (fun f -> f ()) actions;
  Ast.mark_as_grown ()

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
