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
open Cil_datatype

(* ************************************************************************** *)
(* Functions that translate a given ACSL annotation into the corresponding C
   statements (if any) for runtime assertion checking. *)
(* ************************************************************************** *)

let must_translate ppt =
  Options.Valid.get ()
  || match Property_status.get ppt with
  | Never_tried
  | Inconsistent _
  | Best ((False_if_reachable | False_and_reachable | Dont_know), _) ->
    true
  | Best (True, _) ->
    (* [TODO] generating code for "valid under hypotheses" properties could be
       useful for some use cases (in particular, when E-ACSL does not stop on
       the very first error).
       ==> introduce a new option or modify the behavior of -e-acsl-valid,
       see e-acsl#35 *)
    false

let must_translate_opt = function
  | None -> false
  | Some ppt -> must_translate ppt

let () =
  Contract.must_translate_ppt_ref := must_translate;
  Contract.must_translate_ppt_opt_ref := must_translate_opt

let pre_funspec kf kinstr env funspec =
  let unsupported f x = ignore (Env.handle_error (fun env -> f x; env) env) in
  let convert_unsupported_clauses env =
    unsupported
      (fun spec ->
         let ppt = Property.ip_decreases_of_spec kf kinstr spec in
         if must_translate_opt ppt then Env.not_yet env "variant clause")
      funspec;
    (* TODO: spec.spec_terminates is not part of the E-ACSL subset *)
    unsupported
      (fun spec ->
         let ppt = Property.ip_terminates_of_spec kf kinstr spec in
         if must_translate_opt ppt then Env.not_yet env "terminates clause")
      funspec;
    env
  in
  let env = convert_unsupported_clauses env in
  let loc = Kernel_function.get_location kf in
  let contract = Contract.create ~loc funspec in
  Contract.translate_preconditions kf kinstr env contract

let post_funspec kf kinstr env =
  Contract.translate_postconditions kf kinstr env

let pre_code_annotation kf stmt env annot =
  let convert env = match annot.annot_content with
    | AAssert(l, p) ->
      if must_translate (Property.ip_of_code_annot_single kf stmt annot) then
        let env = Env.set_annotation_kind env Smart_stmt.Assertion in
        if l <> [] then
          Env.not_yet env "@[assertion applied only on some behaviors@]";
        Translate.translate_predicate kf env p.tp_statement
      else
        env
    | AStmtSpec(l, spec) ->
      if l <> [] then
        Env.not_yet env "@[statement contract applied only on some behaviors@]";
      let loc = Stmt.loc stmt in
      let contract = Contract.create ~loc spec in
      Contract.translate_preconditions kf (Kstmt stmt) env contract
    | AInvariant(l, loop_invariant, p) ->
      if must_translate (Property.ip_of_code_annot_single kf stmt annot) then
        let env = Env.set_annotation_kind env Smart_stmt.Invariant in
        if l <> [] then
          Env.not_yet env "@[invariant applied only on some behaviors@]";
        let env = Translate.translate_predicate kf env p.tp_statement in
        if loop_invariant then
          Env.add_loop_invariant env p.tp_statement
        else env
      else
        env
    | AVariant _ ->
      if must_translate (Property.ip_of_code_annot_single kf stmt annot)
      then Env.not_yet env "variant"
      else env
    | AAssigns _ ->
      (* TODO: it is not a precondition --> should not be handled here,
         to be fixed when implementing e-acsl#29 *)
      let ppts = Property.ip_of_code_annot kf stmt annot in
      List.iter
        (fun ppt -> if must_translate ppt then Env.not_yet env "assigns")
        ppts;
      env
    | AAllocation _ ->
      let ppts = Property.ip_of_code_annot kf stmt annot in
      List.iter
        (fun ppt -> if must_translate ppt then Env.not_yet env "allocation")
        ppts;
      env
    | APragma _ -> Env.not_yet env "pragma"
    | AExtended _ -> env (* never translate extensions. *)
  in
  Env.handle_error convert env

let post_code_annotation kf stmt env annot =
  let convert env = match annot.annot_content with
    | AStmtSpec(_, _) -> Contract.translate_postconditions kf (Kstmt stmt) env
    | AAssert _
    | AInvariant _
    | AVariant _
    | AAssigns _
    | AAllocation _
    | APragma _
    | AExtended _ -> env
  in
  Env.handle_error convert env

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
