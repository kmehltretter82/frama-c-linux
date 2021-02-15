(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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
open Cvalue

exception Invalid_nb_of_args of int
exception Outside_builtin_possibilities

type builtin_type = unit -> typ * typ list

type builtin =
  Cvalue.Model.t ->
  (Cil_types.exp * Cvalue.V.t * Cvalue.V_Offsetmap.t) list ->
  Value_types.call_result

(* 'Always' means the builtin will always be used to replace a function
   with its name. 'OnAuto' means that the function will be replaced only
   if -eva-builtins-auto is set. *)
type use_builtin = Always | OnAuto

(* Table of all registered builtins; filled by [register_builtin] calls.  *)
let table = Hashtbl.create 17

(* Table binding each kernel function to their builtin for a given analysis.
   Filled at the beginning of each analysis by [prepare_builtins]. *)
let builtins_table = Hashtbl.create 17

module Info = struct
  let name = "Eva.Builtins.BuiltinsOverride"
  let dependencies = [ Db.Value.self ]
end
(** Set of functions overridden by a builtin. *)
module BuiltinsOverride = State_builder.Set_ref (Kernel_function.Set) (Info)

let register_builtin name ?replace ?typ f =
  Value_parameters.register_builtin name;
  Hashtbl.replace table name (f, typ, None, Always);
  match replace with
  | None -> ()
  | Some fname -> Hashtbl.replace table fname (f, typ, Some name, OnAuto)

(* The functions in _builtin must only return the 'Always' builtins *)

let builtin_names_and_replacements () =
  let stand_alone, replacements =
    Hashtbl.fold (fun name (_, _, replaced_by, _) (acc1, acc2) ->
        match replaced_by with
        | None -> name :: acc1, acc2
        | Some rep_by -> acc1, (name, rep_by) :: acc2
      ) table ([], [])
  in
  List.sort String.compare stand_alone,
  List.sort (fun (name1, _) (name2, _) -> String.compare name1 name2) replacements

let () =
  Cmdline.run_after_configuring_stage
    (fun () ->
       if Value_parameters.BuiltinsList.get () then begin
         let stand_alone, replacements = builtin_names_and_replacements () in
         Log.print_on_output
           (fun fmt ->
              Format.fprintf fmt "@[*** LIST OF EVA BUILTINS@\n@\n\
                                  ** Replacements set -eva-builtins-auto:\
                                  @\n   unless otherwise specified, \
                                  function <f> is replaced by builtin \
                                  Frama_C_<f>:@\n@\n   @[%a@]@]@\n"
                (Pretty_utils.pp_list ~sep:",@ "
                   (fun fmt (name, rep_by) ->
                      if rep_by = "Frama_C_" ^ name then
                        Format.fprintf fmt "%s" name
                      else
                        Format.fprintf fmt "%s (replaced by: %s)" name rep_by))
                replacements);
         Log.print_on_output
           (fun fmt ->
              Format.fprintf fmt "@\n@[** Full list of builtins \
                                  (configurable via -eva-builtin):@\n\
                                  @\n   @[%a@]@]@\n"
                (Pretty_utils.pp_list ~sep:",@ "
                   Format.pp_print_string) stand_alone);
         raise Cmdline.Exit
       end)

(* Returns the specification of a builtin, used to evaluate preconditions
   and to transfer the states of other domains. *)
let find_builtin_specification kf =
  let spec = Annotations.funspec kf in
  (* The specification can be empty if [kf] has a body but no specification,
     in which case [Annotations.funspec] does not generate a specification.
     TODO: check that the specification is the frama-c libc specification? *)
  if spec.spec_behavior <> [] then Some spec else None

(* Returns [true] if the function [kf] is incompatible with the expected type
   for a given builtin, which therefore cannot be applied. *)
let inconsistent_builtin_typ kf = function
  | None -> false (* No expected type provided with the builtin, no check. *)
  | Some typ ->
    let expected_result, expected_args = typ () in
    match Kernel_function.get_type kf with
    | TFun (result, args, _, _) ->
      (* If a builtin expects a void pointer, then accept all pointer types. *)
      let need_cast typ expected =
        Cil.need_cast typ expected
        && not (Cil.isVoidPtrType expected && Cil.isPointerType typ)
      in
      let args = Cil.argsToList args in
      need_cast result expected_result
      || List.length args <> List.length expected_args
      || List.exists2 (fun (_, t, _) u -> need_cast t u) args expected_args
    | _ -> assert false

(* Warns if the builtin [bname] overrides the function definition [kf]. *)
let warn_builtin_override kf source bname =
  let internal =
    (* TODO: treat this 'internal' *)
    let file = source.Filepath.pos_path in
    Filepath.is_relative ~base_name:Fc_config.datadir (file :> string)
  in
  if Kernel_function.is_definition kf && not internal
  then
    let fname = Kernel_function.get_name kf in
    Value_parameters.warning ~source ~once:true
      ~wkey:Value_parameters.wkey_builtins_override
      "function %s: definition will be overridden by %s"
      fname (if fname = bname then "its builtin" else "builtin " ^ bname)

let prepare_builtin kf builtin_name builtin expected_typ =
  let source = fst (Kernel_function.get_location kf) in
  if inconsistent_builtin_typ kf expected_typ
  then
    Value_parameters.warning ~source ~once:true
      ~wkey:Value_parameters.wkey_builtins_override
      "The builtin %s will not be used for function %a of incompatible type.@ \
       (got: %a)."
      builtin_name Kernel_function.pretty kf
      Printer.pp_typ (Kernel_function.get_type kf)
  else
    match find_builtin_specification kf with
    | None ->
      Value_parameters.warning ~source ~once:true
        ~wkey:Value_parameters.wkey_builtins_missing_spec
        "The builtin for function %a will not be used, as its frama-c libc \
         specification is not available."
        Kernel_function.pretty kf
    | Some spec ->
      warn_builtin_override kf source builtin_name;
      BuiltinsOverride.add kf;
      Hashtbl.replace builtins_table kf (builtin_name, builtin, spec)

let prepare_builtins () =
  BuiltinsOverride.clear ();
  Hashtbl.clear builtins_table;
  let autobuiltins = Value_parameters.BuiltinsAuto.get () in
  (* Links kernel functions to the registered builtins. *)
  Hashtbl.iter
    (fun name (f, typ, _bname, u) ->
       if autobuiltins || u = Always
       then
         try
           let kf = Globals.Functions.find_by_name name in
           prepare_builtin kf name f typ
         with Not_found -> ())
    table;
  (* Overrides builtins attribution according to the -eva-builtin option. *)
  Value_parameters.BuiltinsOverrides.iter
    (fun (kf, name) ->
       let builtin_name = Option.get name in
       let f, typ, _, _ = Hashtbl.find table builtin_name in
       prepare_builtin kf builtin_name f typ)

let find_builtin_override = Hashtbl.find_opt builtins_table

let is_builtin_overridden =
  if not (BuiltinsOverride.is_computed ())
  then prepare_builtins ();
  BuiltinsOverride.mem

(* -------------------------------------------------------------------------- *)
(* --- Returning a clobbered set                                          --- *)
(* -------------------------------------------------------------------------- *)

let clobbered_set_from_ret state ret =
  let aux b _ acc =
    match Model.find_base_or_default b state with
    | `Top -> Base.SetLattice.top
    | `Bottom -> acc
    | `Value m ->
      if Locals_scoping.offsetmap_contains_local m then
        Base.SetLattice.(join (inject_singleton b) acc)
      else acc
  in
  try V.fold_topset_ok aux ret Base.SetLattice.bottom
  with Abstract_interp.Error_Top -> Base.SetLattice.top

(* -------------------------------------------------------------------------- *)
(* --- Applying a builtin                                                 --- *)
(* -------------------------------------------------------------------------- *)

type call = (Precise_locs.precise_location, Cvalue.V.t) Eval.call
type result = Cvalue.Model.t * Locals_scoping.clobbered_set

open Eval

let unbottomize = function
  | `Bottom -> Cvalue.V.bottom
  | `Value v -> v

let offsetmap_of_formals state arguments rest =
  let compute expr assigned =
    let offsm = Cvalue_offsetmap.offsetmap_of_assignment state expr assigned in
    let value = unbottomize (Eval.value_assigned assigned) in
    expr, value, offsm
  in
  let treat_one_formal arg = compute arg.concrete arg.avalue in
  let treat_one_rest (exp, v) = compute exp v in
  let list = List.map treat_one_formal arguments in
  let rest = List.map treat_one_rest rest in
  list @ rest

let compute_builtin name builtin state actuals =
  try builtin state actuals
  with
  | Invalid_nb_of_args n ->
    Value_parameters.error ~current:true
      "Invalid number of arguments for builtin %s: %d expected, %d found"
      name n (List.length actuals);
    raise Db.Value.Aborted
  | Outside_builtin_possibilities ->
    Value_parameters.warning ~once:true ~current:true
      "Call to builtin %s failed, aborting." name;
    raise Db.Value.Aborted

let apply_builtin builtin call state =
  let name = Kernel_function.get_name call.kf in
  let actuals = offsetmap_of_formals state call.arguments call.rest in
  let res = compute_builtin name builtin state actuals in
  let call_stack = Value_util.call_stack () in
  Db.Value.Call_Type_Value_Callbacks.apply (`Builtin res, state, call_stack);
  let clob = Locals_scoping.bottom () in
  Locals_scoping.remember_bases_with_locals clob res.Value_types.c_clobbered;
  let process_one_return acc (ret, post_state) =
    if Cvalue.Model.is_reachable post_state then
      let state =
        match ret, call.return with
        | Some offsm_ret, Some vi_ret ->
          let b_ret = Base.of_varinfo vi_ret in
          Cvalue.Model.add_base b_ret offsm_ret post_state
        | _, _ -> post_state
      in
      (state, clob) :: acc
    else
      acc
  in
  let list = List.fold_left process_one_return [] res.Value_types.c_values in
  list, res.Value_types.c_cacheable

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
