(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* ************************************************************************** *)
(** {2 Exported code} *)
(* ************************************************************************** *)

let stmt ?warn:_ kf stmt =
  RteGen.Visit.get_annotations_stmt
    ~flags:(RteGen.Flags.default
              ~div_mod:false
              ~mem_access:false
              ~initialized:Kernel_function.Set.empty
              ~pointer_alignment:false
              ~pointer_value:false
              ~left_shift_negative:false
              ~right_shift_negative:false
              ())
    kf stmt

let exp ?warn:_ kf stmt e =
  RteGen.Visit.get_annotations_exp
    ~flags:(RteGen.Flags.default
              ~div_mod:false
              ~mem_access:false
              ~initialized:Kernel_function.Set.empty
              ~pointer_alignment:false
              ~pointer_value:false
              ~left_shift_negative:false
              ~right_shift_negative:false
              ())
    kf stmt e

let get_state_selection_with_dependencies () =
  State_selection.with_dependencies RteGen.Generator.self
