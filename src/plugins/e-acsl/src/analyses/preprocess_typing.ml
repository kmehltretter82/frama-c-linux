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

let must_translate_ref : (Property.t -> bool) ref =
  Extlib.mk_fun "must_translate_ref"
let must_translate_opt_ref : (Property.t option -> bool) ref =
  Extlib.mk_fun "must_translate_opt_ref"

let type_requires v kf kinstr bhvr =
  if Cil.is_default_behavior bhvr then
    List.iter
      (fun ip_requires ->
         if !must_translate_ref (Property.ip_of_requires kf kinstr bhvr ip_requires) then
           let tp_requires = ip_requires.ip_content.tp_statement in
           ignore (Visitor.visitFramacPredicate v tp_requires))
      bhvr.b_requires
  else
    List.iter
      (fun ip_requires ->
         if !must_translate_ref (Property.ip_of_requires kf kinstr bhvr ip_requires) then
           let tp_requires = ip_requires.ip_content in
           let pred_kind = tp_requires.tp_kind in
           match pred_kind with
           | Assert | Check ->
             let requires = tp_requires.tp_statement in
             ignore (Visitor.visitFramacPredicate v requires)
           | Admit -> ())
      bhvr.b_requires


let type_post_conditions v kf kinstr bhvr =
  if Cil.is_default_behavior bhvr then
    List.iter
      (fun ((termination, ip_post_cond) as tp) ->
         if !must_translate_ref (Property.ip_of_ensures kf kinstr bhvr tp) then
           let post_cond = ip_post_cond.ip_content.tp_statement in
           match termination with
           | Normal -> ignore (Visitor.visitFramacPredicate v post_cond)
           | Exits | Breaks | Continues | Returns -> ())
      bhvr.b_post_cond
  else
    List.iter
      (fun ((termination, ip_post_cond) as tp) ->
         if !must_translate_ref (Property.ip_of_ensures kf kinstr bhvr tp) then
           let tp_post_cond = ip_post_cond.ip_content in
           let pred_kind = tp_post_cond.tp_kind in
           match pred_kind with
           | Assert | Check -> begin
               let post_cond = tp_post_cond.tp_statement in
               match termination with
               | Normal ->
                 ignore (Visitor.visitFramacPredicate v post_cond)
               | Exits | Breaks | Continues | Returns -> ()
             end
           | Admit -> ())
      bhvr.b_post_cond


let typer_visitor (lenv : Typing.Params_ty.t) = object (self)
  inherit Visitor.frama_c_inplace

  (* Only type the globals that do not come from the Rtl *)
  method !vglob_aux =
    function
    (* library functions and built-ins *)
    | GFun({ svar = vi }, _) when Builtins.mem vi.vname ->
      Cil.SkipChildren

    | GFun({ svar = vi }, _)
      when Misc.is_fc_or_compiler_builtin vi ->
      Cil.SkipChildren

    | g when Rtl.Symbols.mem_global g ->
      Cil.SkipChildren

    | GFun({svar = vi}, _) ->
      let kf = try Globals.Functions.get vi with Not_found -> assert false in
      if Functions.check kf then Cil.DoChildren else Cil.SkipChildren

    (* other globals: nothing to do *)
    | GFunDecl _
    | GVarDecl _
    | GVar _
    | GType _
    | GCompTag _
    | GCompTagDecl _
    | GEnumTag _
    | GEnumTagDecl _
    | GAsm _
    | GPragma _
    | GText _
    | GAnnot _
      -> Cil.SkipChildren

<<<<<<< HEAD
<<<<<<< variant A
    | _ -> Cil.DoChildren
>>>>>>> variant B
  method !vpredicate p =
    Error.generic_handle (Typing.type_named_predicate ~lenv) () p;
    Cil.SkipChildren

  method !vspec spec =
    List.iter (fun b -> (List.iter (fun p -> ignore (Visitor.visitFramacIdPredicate self p)) b.b_assumes)) spec.spec_behavior;
    List.iter (type_requires self (Option.get self#current_kf) (self#current_kinstr)) spec.spec_behavior;
    List.iter (type_post_conditions self (Option.get self#current_kf) self#current_kinstr) spec.spec_behavior;
    Cil.SkipChildren
======= end
=======
  method !vpredicate p =
    Error.generic_handle (Typing.type_named_predicate ~lenv) () p; Cil.SkipChildren
>>>>>>> 32bad40483e... [e-acsl] improve preprocessing phase for typing

  method !vspec spec =
    List.iter (fun b -> (List.iter (fun p -> ignore (Visitor.visitFramacIdPredicate self p)) b.b_assumes)) spec.spec_behavior;
    List.iter (type_requires self (Option.get self#current_kf) (self#current_kinstr)) spec.spec_behavior;
    List.iter (type_post_conditions self (Option.get self#current_kf) self#current_kinstr) spec.spec_behavior;
    Cil.SkipChildren

  method !vcode_annot annot =
    match annot.annot_content with
    | AAssert(_, _) | AVariant(_, _) ->
      let translate = try
          !must_translate_ref (Property.ip_of_code_annot_single (Option.get self#current_kf) (Option.get self#current_stmt) annot)
        with Invalid_argument _ -> true
      in
      if translate then
        Cil.DoChildren
      else
        Cil.SkipChildren
    | AStmtSpec(l, _) ->
      if l <> [] then Cil.SkipChildren
      else Cil.DoChildren
    | AInvariant(l, _, _) ->
      let translate =
        try !must_translate_ref (Property.ip_of_code_annot_single (Option.get self#current_kf) (Option.get self#current_stmt) annot)
        with Invalid_argument _ -> true
      in if translate then
        if l <> [] then
          Cil.SkipChildren
        else Cil.DoChildren
      else Cil.SkipChildren
    | AAssigns _ -> Cil.SkipChildren
    | AAllocation _ -> Cil.SkipChildren
    | APragma _ -> Cil.SkipChildren
    | AExtended _ -> Cil.SkipChildren

end

let type_program ast =
  Visitor.visitFramacFileSameGlobals (typer_visitor []) ast

let type_code_annot lenv annot =
  ignore (Visitor.visitFramacCodeAnnotation (typer_visitor lenv) annot)

let preprocess_predicate lenv p =
  Preprocess_predicates.preprocess_predicate p;
  Bound_variables.preprocess_predicate p;
  ignore (Visitor.visitFramacPredicate (typer_visitor lenv) p)

let preprocess_rte ~lenv rte =
  Preprocess_predicates.preprocess_annot rte;
  Bound_variables.preprocess_annot rte;
  type_code_annot lenv rte
