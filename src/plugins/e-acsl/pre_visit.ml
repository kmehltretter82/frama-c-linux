(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012                                                    *)
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

(* ********************************************************************** *)
(* Environment *)
(* ********************************************************************** *)

let fct_tbl: unit Kernel_function.Hashtbl.t = Kernel_function.Hashtbl.create 7
let is_generated_function kf = Kernel_function.Hashtbl.mem fct_tbl kf

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
  Global.reset ()

(* ********************************************************************** *)
(* Duplicating functions *)
(* ********************************************************************** *)

let dup_funspec tbl bhv spec =
  (*  Options.feedback "DUP SPEC %a" Cil.d_funspec spec;*)
  let o = object
    inherit Cil.genericCilVisitor (Cil.copy_visit (Project.current ()))

    val already_visited = Cil_datatype.Logic_var.Hashtbl.create 7

    method vlogic_info_use li =
      if Global.mem_logic_info li then
	Cil.ChangeDoChildrenPost
	  ({ li with l_var_info = li.l_var_info } (* force a copy *),
	   Cil.get_logic_info bhv)
      else
	Cil.JustCopy

    method vterm_offset _ =
      Cil.DoChildrenPost
	(function
	(* no way to directly visit fieldinfo and model_info uses *)	
	| TField(fi, off) -> TField(Cil.get_fieldinfo bhv fi, off)
	| TModel(mi, off) -> TModel(Cil.get_model_info bhv mi, off)
	| off -> off)

    method vlogic_var_use orig_lvi =
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
	       (* using [Cil.get_logic_var bhv lvi] is correct only because the
		  lv_id used to compare the lvi does not change between the
		  original one and this copy *)
	       try 
		 let new_vi = Cil_datatype.Varinfo.Hashtbl.find tbl vi in
		 Cil_datatype.Logic_var.Hashtbl.add 
		   already_visited orig_lvi lvi;
		 lvi.lv_id <- new_vi.vid;
		 lvi.lv_name <- new_vi.vname;
		 lvi.lv_origin <- Some new_vi;
		 new_vi.vlogic_var_assoc <- Some lvi;
		 lvi
	       with Not_found -> 
		 assert vi.vglob;
		 Cil.get_logic_var bhv lvi)

    method videntified_term _ = 
      Cil.DoChildrenPost Logic_const.refresh_identified_term

    method videntified_predicate _ = 
      Cil.DoChildrenPost Logic_const.refresh_predicate
  end in
  Cil.visitCilFunspec o spec

let dup_fundec loc spec bhv kf vi new_vi =
  new_vi.vdefined <- true;
  let formals = Kernel_function.get_formals kf in
  let new_formals = List.map (fun vi -> Cil.copyVarinfo vi vi.vname) formals in
  let res =
    let ty = Kernel_function.get_return_type kf in
    if Cil.isVoidType ty then None
    else Some (Cil.makeVarinfo false false "__retres" ty)
  in
  let return =
    Cil.mkStmt ~valid_sid:true
      (Return(Extlib.opt_map (Cil.evar ~loc) res, loc))
  in
  let stmts = 
    [ Cil.mkStmtOneInstr ~valid_sid:true
	(Call(Extlib.opt_map Cil.var res,
	      Cil.evar ~loc vi, 
	      List.map (Cil.evar ~loc) new_formals, 
	      loc)); 
      return ]
  in
  let locals = match res with None -> [] | Some r -> [ r ] in
  let body = Cil.mkBlock stmts in
  body.blocals <- locals;
  let tbl = Cil_datatype.Varinfo.Hashtbl.create 7 in
  List.iter2 (Cil_datatype.Varinfo.Hashtbl.add tbl) formals new_formals;
  let new_spec = dup_funspec tbl bhv spec in
  { svar = new_vi;
    sformals = new_formals;
    slocals = locals;
    smaxid = List.length new_formals;
    sbody = body;
    smaxstmtid = None;
    sallstmts = [];
    sspec = new_spec }, 
  return

let dup_global loc spec bhv kf vi new_vi = 
  (*  Options.feedback "DUP GLOBAL %s" vi.vname;*)
  let fundec, return = dup_fundec loc spec bhv kf vi new_vi  in
  let fct = Definition(fundec, loc) in
  let spec = fundec.sspec in
  let kf = { fundec = fct; return_stmt = Some return; spec = spec } in
  Kernel_function.Hashtbl.add fct_tbl kf ();
  Globals.Functions.register kf;
  Globals.Functions.replace_by_definition spec fundec loc;
  GFun(fundec, loc)

(* ********************************************************************** *)
(* Visitor *)
(* ********************************************************************** *)

class dup_functions_visitor prj = object (self)
  inherit Visitor.frama_c_copy prj

  val fct_tbl = Cil_datatype.Varinfo.Hashtbl.create 7

  method vlogic_info_decl li = 
    Global.add_logic_info li;
    Cil.JustCopy

  method vvrbl vi =
    try
      let new_vi = Cil_datatype.Varinfo.Hashtbl.find fct_tbl vi in
      Cil.ChangeTo new_vi
    with Not_found ->
      Cil.JustCopy

  method vglob_aux = function
  | GVarDecl(_, vi, loc) | GFun({ svar = vi }, loc) 
      when Cil.isFunctionType vi.vtype
	&& not (Misc.is_library_loc loc) 
	&& not (Cil.is_builtin vi)
	&& not (Cil_datatype.Varinfo.Hashtbl.mem fct_tbl vi)
	&& not (Cil.is_empty_funspec
		  (Annotations.funspec ~populate:false
		     (Extlib.the self#current_kf)))
	-> 
    let name = "__e_acsl_" ^ vi.vname in
    let new_vi = Project.on prj (Cil.makeGlobalVar name) vi.vtype in
    Cil_datatype.Varinfo.Hashtbl.add fct_tbl vi new_vi;
    Cil.DoChildrenPost
      (fun l -> match l with
      | [ GVarDecl(_, vi, _) | GFun({ svar = vi }, _) as g ] -> 
	let tmp = vi.vname in
	if tmp = Kernel.MainFunction.get () then begin
	  (* the new function becomes the new main: simply swap the name of both
	     functions *)
	  vi.vname <- new_vi.vname;
	  new_vi.vname <- tmp
	end;
	let kf = 
	  try 
	    Globals.Functions.get (Cil.get_original_varinfo self#behavior vi)
	  with Not_found -> 
	    Options.fatal
	      "unknown function `%s' while trying to duplicate it" 
	      vi.vname
	in
	let spec = Annotations.funspec ~populate:false kf in
	let vi_bhv = Cil.get_varinfo self#behavior vi in
	let new_g = 
	  Project.on prj (dup_global loc spec self#behavior kf vi_bhv) 
	    new_vi 
	in
	[ g; new_g ]
      | _ -> assert false)
  | GVarDecl(_, vi, loc) | GFun({ svar = vi }, loc) 
      when Misc.is_library_loc loc || Cil.is_builtin vi
	->
    Cil.JustCopy
  | _ -> 
    Cil.DoChildren

  initializer reset ()

end

let dup_functions () =
  let prj =
    File.create_project_from_visitor
      "e_acsl_dup_functions" 
      (new dup_functions_visitor)
  in
  Project.copy ~selection:(Plugin.get_selection ()) prj;
  prj

(*
Local Variables:
compile-command: "make"
End:
*)
