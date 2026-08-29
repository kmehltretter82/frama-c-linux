(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

include Plugin.Register
    (struct
      let name = "Linux kernel checks"
      let shortname = "kernel-checks"
      let help = "check Linux-specific semantic protocols"
    end)

module Enabled = False
    (struct
      let option_name = "-kernel-checks"
      let help = "run Linux kernel semantic checks after Eva"
    end)

module MaxErrno = Int
    (struct
      let option_name = "-kernel-checks-max-errno"
      let arg_name = "n"
      let default = 4095
      let help = "largest errno encoded by ERR_PTR (default: 4095)"
    end)

module BoundedEntry = False
    (struct
      let option_name = "-kernel-checks-bounded-entry"
      let help =
        "configure a bounded Eva entry state for Linux callback analysis; \
         unless explicitly overridden, enables -lib-entry and uses context \
         depth 0 and width 1; use an analysis harness for deeper objects"
    end)

module FaultErrno = Int
    (struct
      let option_name = "-kernel-checks-fault-errno"
      let arg_name = "n"
      let default = 12
      let help =
        "positive errno returned by the Frama_C_kernel_err_ptr Eva fault \
         model (default: 12, ENOMEM)"
    end)

let () = FaultErrno.set_range ~min:1 ~max:max_int

module ErrPtrSources = String_set
    (struct
      let option_name = "-kernel-checks-err-ptr-source"
      let arg_name = "f1,...,fn"
      let help =
        "interpret each listed pointer-returning function as the \
         Frama_C_kernel_err_ptr fault model"
    end)

module PreserveEncodedPointers = True
    (struct
      let option_name = "-kernel-checks-preserve-encoded-pointers"
      let help =
        "preserve typed ERR_PTR values during Eva by disabling creation-time \
         invalid/unaligned pointer and pointer-to-integer range checks; \
         memory-access checks remain enabled"
    end)

let original_pointer_checks = ref None

let apply_encoded_pointer_profile () =
  if Option.is_none !original_pointer_checks then
    original_pointer_checks :=
      Some
        (Kernel.InvalidPointer.get (), Kernel.UnalignedPointer.get (),
         Kernel.PointerDowncast.get ());
  Kernel.InvalidPointer.set false;
  Kernel.UnalignedPointer.set false;
  Kernel.PointerDowncast.set false

let restore_pointer_profile () =
  match !original_pointer_checks with
  | None -> ()
  | Some (invalid, unaligned, downcast) ->
    Kernel.InvalidPointer.set invalid;
    Kernel.UnalignedPointer.set unaligned;
    Kernel.PointerDowncast.set downcast;
    original_pointer_checks := None

let configure_pointer_profile ~enabled ~preserve =
  if enabled && preserve then apply_encoded_pointer_profile ()
  else restore_pointer_profile ()

let () =
  Enabled.add_set_hook
    (fun _ enabled ->
       configure_pointer_profile
         ~enabled ~preserve:(PreserveEncodedPointers.get ()))

let () =
  PreserveEncodedPointers.add_set_hook
    (fun _ preserve ->
       configure_pointer_profile ~enabled:(Enabled.get ()) ~preserve)

let wkey_err_ptr =
  register_warn_category
    ~help:"provable violations of the Linux ERR_PTR protocol"
    "err-ptr"

let wkey_mte_init =
  register_warn_category
    ~help:"faultable user accesses while ARM64 MTE initialization is pending"
    "mte-init"

let wkey_counted_by_bounds =
  register_warn_category
    ~help:"provably out-of-bounds accesses to GCC counted-by fields"
    "counted-by-bounds"
