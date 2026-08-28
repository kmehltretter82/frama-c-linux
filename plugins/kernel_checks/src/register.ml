(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

let main () =
  if Options.Enabled.get () then begin
    let max_errno = Options.MaxErrno.get () in
    if max_errno <= 0 then
      Options.abort "-kernel-checks-max-errno must be positive";
    let pointer_modulus =
      Z.two_power_of_int (Cil.bitsSizeOf Cil_const.voidPtrType)
    in
    if Z.geq (Z.of_int max_errno) pointer_modulus then
      Options.abort
        "-kernel-checks-max-errno must fit below the pointer modulus";
    if Options.PreserveEncodedPointers.get () then begin
      Options.apply_encoded_pointer_profile ();
      Options.feedback
        "preserving encoded-pointer states; creation-time invalid/unaligned \
         pointer and pointer-to-integer range checks are disabled \
         (memory-access checks remain enabled)"
    end;
    let violations = Err_ptr.run () in
    Options.result "ERR_PTR: %d provable protocol violation(s)" violations
  end

let () = Boot.Main.extend main
