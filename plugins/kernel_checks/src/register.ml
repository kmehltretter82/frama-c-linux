(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

let main () =
  if Options.Enabled.get () then begin
    if Options.AstOnly.get () then
      Options.feedback
        "AST-only profile: skipping Eva-dependent ERR_PTR and counted-by \
         checks"
    else begin
      let max_errno = Options.MaxErrno.get () in
      if max_errno <= 0 then
        Options.abort "-kernel-checks-max-errno must be positive";
      let pointer_modulus =
        Z.two_power_of_int (Cil.bitsSizeOf Cil_const.voidPtrType)
      in
      if Z.geq (Z.of_int max_errno) pointer_modulus then
        Options.abort
          "-kernel-checks-max-errno must fit below the pointer modulus";
      let fault_errno = Options.FaultErrno.get () in
      if fault_errno > max_errno then
        Options.abort
          "-kernel-checks-fault-errno must not exceed \
           -kernel-checks-max-errno";
      Models.configure_entry_profile ();
      Models.configure_err_ptr_sources ();
      if Options.PreserveEncodedPointers.get () then begin
        Options.apply_encoded_pointer_profile ();
        Options.feedback
          "preserving encoded-pointer states; creation-time invalid/unaligned \
           pointer and pointer-to-integer range checks are disabled \
           (memory-access checks remain enabled)"
      end;
      let violations = Err_ptr.run () in
      Options.result "ERR_PTR: %d provable protocol violation(s)" violations
    end;
    let mte_violations = Mte.run () in
    if mte_violations > 0 then
      Options.result
        "MTE initialization: %d faultable access violation(s)"
        mte_violations;
    if not (Options.AstOnly.get ()) then begin
      let counted_by_violations = Counted_by.run () in
      if counted_by_violations > 0 then
        Options.result
          "counted_by bounds: %d provable violation(s)"
          counted_by_violations
    end;
    let validation_order_violations = Validation_order.run () in
    if validation_order_violations > 0 then
      Options.result
        "validation order: %d rejected-input atomicity risk(s)"
        validation_order_violations
  end

let () = Boot.Main.extend main
