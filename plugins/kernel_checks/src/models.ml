(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

let err_ptr_builtin_name = "Frama_C_kernel_err_ptr"

let model_emitter =
  Emitter.create
    "Linux kernel fault models" [Emitter.Funspec]
    ~correctness:
      [Options.ErrPtrSources.parameter; Options.FaultErrno.parameter]
    ~tuning:[]

let err_ptr_builtin _state _arguments =
  let pointer_bits = Cil.bitsSizeOf Cil_const.voidPtrType in
  let modulus = Z.two_power_of_int pointer_bits in
  let errno = Z.of_int (Options.FaultErrno.get ()) in
  let encoded = Z.sub modulus errno in
  Eva.Builtins.Result [Cvalue.V.inject_int encoded]

let () =
  Eva.Builtins.register_builtin err_ptr_builtin_name err_ptr_builtin

let configure_err_ptr_sources () =
  let configure name =
    let kernel_function =
      try Globals.Functions.find_by_name name
      with Not_found ->
        Options.abort
          "-kernel-checks-err-ptr-source: function %s was not found" name
    in
    let function_type = Kernel_function.get_type kernel_function in
    let returns_pointer =
      match function_type.tnode with
      | TFun (result, _, _) -> Ast_types.C.is_ptr result
      | _ -> false
    in
    if not returns_pointer then
      Options.abort
        "-kernel-checks-err-ptr-source: function %s does not return a pointer"
        name;
    (* The forced error return has no side effects.  Give Eva the explicit
       assigns clause required for transferring states through a builtin. *)
    Annotations.add_assigns
      ~keep_empty:false model_emitter kernel_function (Writes []);
    Eva.Parameters.use_builtin kernel_function err_ptr_builtin_name;
    Options.feedback
      "fault model: %s returns ERR_PTR(-%d)"
      name (Options.FaultErrno.get ())
  in
  if not (Options.ErrPtrSources.is_empty ()) then begin
    Ast.compute ();
    Options.ErrPtrSources.iter configure;
    Eva.Parameters.change_correctness ()
  end

let configure_entry_profile () =
  if Options.BoundedEntry.get () then begin
    if not (Kernel.LibEntry.is_set ()) then Kernel.LibEntry.set true;
    if not (Eva.Parameters.ContextDepth.is_set ()) then
      Eva.Parameters.ContextDepth.set 0;
    if not (Eva.Parameters.ContextWidth.is_set ()) then
      Eva.Parameters.ContextWidth.set 1;
    Options.feedback
      "bounded entry profile: lib-entry=%b, context depth=%d, width=%d"
      (Kernel.LibEntry.get ())
      (Eva.Parameters.ContextDepth.get ())
      (Eva.Parameters.ContextWidth.get ())
  end
