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

(* -------------------------------------------------------------------------- *)
(* state *)
(* -------------------------------------------------------------------------- *)

let self = Generator.self

(* -------------------------------------------------------------------------- *)
(* getters *)
(* -------------------------------------------------------------------------- *)

type status_accessor = Generator.status_accessor

let get_all_status () = Generator.all_statuses
let get_signedOv_status () = Generator.Signed_overflow.accessor
let get_divMod_status () = Generator.Div_mod.accessor
let get_initialized_status () = Generator.Initialized.accessor
let get_signed_downCast_status () = Generator.Signed_downcast.accessor
let get_memAccess_status () = Generator.Mem_access.accessor
let get_pointerCall_status () = Generator.Pointer_call.accessor
let get_unsignedOv_status () = Generator.Unsigned_overflow.accessor
let get_unsignedDownCast_status () = Generator.Unsigned_downcast.accessor
let get_pointer_downcast_status () = Generator. Pointer_downcast.accessor
let get_float_to_int_status () = Generator.Float_to_int.accessor
let get_finite_float_status () = Generator.Finite_float.accessor
let get_pointer_value_status () = Generator.Pointer_value.accessor
let get_bool_value_status () = Generator.Bool_value.accessor


(* -------------------------------------------------------------------------- *)
(* dedicated computations *)
(* -------------------------------------------------------------------------- *)

let annotate_kf kf = Visit.annotate kf

(* annotate for all rte + unsigned overflows (which are not rte), for a given
   function *)
let do_all_rte kf =
  let flags =
    { (Flags.all ()) with
      Flags.signed_downcast = false;
      unsigned_downcast = false; }
  in
  Visit.annotate ~flags kf

(* annotate for rte only (not unsigned overflows and downcasts) for a given
   function *)
let do_rte kf =
  let flags =
    { (Flags.all ()) with
      Flags.unsigned_overflow = false;
      signed_downcast = false;
      unsigned_downcast = false; }
  in
  Visit.annotate ~flags kf

let compute () =
  (* compute RTE annotations, whether Enabled is set or not *)
  Ast.compute () ;
  let include_function kf =
    let fsel = Options.FunctionSelection.get () in
    Kernel_function.Set.is_empty fsel
    || Kernel_function.Set.mem kf fsel
  in
  Globals.Functions.iter
    (fun kf -> if include_function kf then annotate_kf kf)
