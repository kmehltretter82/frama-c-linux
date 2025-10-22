(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
  Register.compute ()

(* Deprecated old dynamically registered API *)

let _ignore =
  Dynamic.register
    ~comment:"Generate all RTE annotations in the given function."
    ~plugin:"RteGen"
    "do_all_rte"
    (Datatype.func Kernel_function.ty Datatype.unit)
    do_all_rte

let _ignore =
  Dynamic.register
    ~comment:"The emitter used for generating RTE annotations"
    ~plugin:"RteGen"
    "emitter"
    Emitter.ty
    Generator.emitter

(* retrieve list of generated rte annotations for a given stmt *)
let _ignore =
  Dynamic.register
    ~comment:"Get the list of annotations previously emitted by RTE for the \
              given statement."
    ~plugin:"RteGen"
    "get_rte_annotations"
    (Datatype.func
       Cil_datatype.Stmt.ty
       (let module L = Datatype.List(Cil_datatype.Code_annotation) in L.ty))
    Generator.get_registered_annotations

let _ignore =
  Dynamic.register
    ~comment:"Generate RTE annotations corresponding to the given stmt of \
              the given function."
    ~plugin:"RteGen"
    "stmt_annotations"
    (Datatype.func2 Kernel_function.ty Cil_datatype.Stmt.ty
       (let module L = Datatype.List(Cil_datatype.Code_annotation) in L.ty))
    Visit.get_annotations_stmt

let _ignore =
  Dynamic.register
    ~comment:"Generate RTE annotations corresponding to the given exp \
              of the given stmt in the given function."
    ~plugin:"RteGen"
    "exp_annotations"
    (Datatype.func3 Kernel_function.ty Cil_datatype.Stmt.ty Cil_datatype.Exp.ty
       (let module L = Datatype.List(Cil_datatype.Code_annotation) in L.ty))
    Visit.get_annotations_exp

let _ignore =
  let kf = Kernel_function.ty in
  Dynamic.register
    ~plugin:"RteGen"
    "all_statuses"
    Datatype.(list (triple string (func2 kf bool unit) (func kf bool)))
    Generator.all_statuses
