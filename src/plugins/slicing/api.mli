(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(* ---------------------------------------------------------------------- *)
(** Global data management *)

val split_slice :
  SlicingInternals.fct_slice -> SlicingInternals.fct_slice list

val merge_slices :
  SlicingInternals.fct_slice ->
  SlicingInternals.fct_slice -> replace:bool -> SlicingInternals.fct_slice

val copy_slice : SlicingInternals.fct_slice -> SlicingInternals.fct_slice

(* ---------------------------------------------------------------------- *)
(** {1 Global setting } *)

val self : State.t

(* ---------------------------------------------------------------------- *)

(** {2 Functions with journalized side effects } *)

val set_modes :
  ?calls:SlicingParameters.Mode.Calls.t ->
  ?callers:SlicingParameters.Mode.Callers.t ->
  ?sliceUndef:SlicingParameters.Mode.SliceUndef.t ->
  ?keepAnnotations:SlicingParameters.Mode.KeepAnnotations.t -> unit -> unit


(* ---------------------------------------------------------------------- *)

(** {1 Slicing project } *)
module Project : sig

  (** {2 Values } *)

  val default_slice_names :
    Cil_types.kernel_function -> bool -> int -> string

  (** {2 Functions with journalized side effects } *)

  val reset_slicing : unit -> unit

  val extract :
    ?f_slice_names:(Kernel_function.t -> bool -> int -> string) ->
    string -> Project.t

  val print_dot : filename:string -> title:string -> unit

  val change_slicing_level : Kernel_function.t -> int -> unit

  (** {2 No needs of Journalization} *)

  val is_directly_called_internal : Kernel_function.t -> bool

  val is_called : Cil_types.kernel_function -> bool

  val has_persistent_selection : Kernel_function.t -> bool

  (** {2 Debug} *)

  val pretty : Format.formatter -> unit

end

(* ---------------------------------------------------------------------- *)

(** {1 Mark} *)
module Mark : sig

  type t = SlicingTypes.sl_mark
  val dyn_t : SlicingTypes.Sl_mark.t Type.t

  (** {2 No needs of Journalization} *)

  val compare : SlicingTypes.sl_mark -> SlicingTypes.sl_mark -> int

  val pretty : Format.formatter -> SlicingTypes.sl_mark -> unit

  val make : data:bool -> addr:bool -> ctrl:bool -> SlicingTypes.sl_mark

  val is_bottom : SlicingTypes.sl_mark -> bool

  val is_spare : SlicingTypes.sl_mark -> bool

  val is_ctrl : SlicingTypes.sl_mark -> bool

  val is_data : SlicingTypes.sl_mark -> bool

  val is_addr : SlicingTypes.sl_mark -> bool

  val get_from_src_func : Kernel_function.t -> SlicingInternals.pdg_mark

end

(* ---------------------------------------------------------------------- *)

(** {1 Selection} *)
module Select : sig

  type t = SlicingTypes.sl_select
  val dyn_t : SlicingTypes.Sl_select.t Type.t

  type set = SlicingCmds.set

  type selections = SlicingTypes.Fct_user_crit.t Cil_datatype.Varinfo.Map.t

  val dyn_set : selections Type.t

  (** {2 Journalized selectors } *)

  val empty_selects : selections

  val select_stmt :
    selections -> spare:bool -> Cil_datatype.Stmt.t -> Kernel_function.t -> selections

  val select_stmt_ctrl :
    selections -> spare:bool -> Cil_datatype.Stmt.t -> Kernel_function.t -> selections

  val select_stmt_lval_rw :
    selections ->
    SlicingTypes.Sl_mark.t ->
    rd:Datatype.String.Set.t ->
    wr:Datatype.String.Set.t ->
    Cil_datatype.Stmt.t ->
    eval:Cil_datatype.Stmt.t -> Kernel_function.t -> selections

  val select_stmt_lval :
    selections ->
    SlicingTypes.Sl_mark.t ->
    Datatype.String.Set.t ->
    before:bool ->
    Cil_datatype.Stmt.t ->
    eval:Cil_datatype.Stmt.t -> Kernel_function.t -> selections

  val select_stmt_annots :
    selections ->
    SlicingTypes.Sl_mark.t ->
    spare:bool ->
    threat:bool ->
    user_assert:bool ->
    slicing_pragma:bool ->
    loop_inv:bool ->
    loop_var:bool -> Cil_datatype.Stmt.t -> Kernel_function.t -> selections

  val select_func_lval :
    selections ->
    SlicingTypes.Sl_mark.t ->
    Datatype.String.Set.t -> Kernel_function.t -> selections

  val select_func_lval_rw :
    selections ->
    SlicingTypes.Sl_mark.t ->
    rd:Datatype.String.Set.t ->
    wr:Datatype.String.Set.t ->
    eval:Cil_datatype.Stmt.t -> Kernel_function.t -> selections

  val select_func_return : selections -> spare:bool -> Kernel_function.t -> selections

  val select_func_calls_to :
    selections -> spare:bool -> Kernel_function.t -> selections

  val select_func_calls_into :
    selections -> spare:bool -> Kernel_function.t -> selections

  val select_func_annots :
    selections ->
    SlicingTypes.Sl_mark.t ->
    spare:bool ->
    threat:bool ->
    user_assert:bool ->
    slicing_pragma:bool ->
    loop_inv:bool -> loop_var:bool -> Kernel_function.t -> selections

  val select_func_zone :
    SlicingCmds.set ->
    SlicingTypes.sl_mark ->
    Locations.Zone.t -> Cil_types.kernel_function -> SlicingCmds.set

  val select_stmt_term :
    SlicingCmds.set ->
    SlicingTypes.sl_mark ->
    Cil_types.term ->
    Cil_types.stmt -> Cil_types.kernel_function -> SlicingCmds.set

  val select_stmt_pred :
    SlicingCmds.set ->
    SlicingTypes.sl_mark ->
    Cil_types.predicate ->
    Cil_types.stmt -> Cil_types.kernel_function -> SlicingCmds.set

  val select_stmt_annot :
    SlicingCmds.set ->
    SlicingTypes.sl_mark ->
    spare:bool ->
    Cil_types.code_annotation ->
    Cil_types.stmt -> Cil_types.kernel_function -> SlicingCmds.set

  val select_stmt_zone :
    SlicingCmds.set ->
    SlicingTypes.sl_mark ->
    Locations.Zone.t ->
    before:bool ->
    Cil_types.stmt -> Cil_types.kernel_function -> SlicingCmds.set

  val select_pdg_nodes :
    SlicingCmds.set ->
    SlicingTypes.sl_mark ->
    PdgTypes.Node.t list -> Cil_types.kernel_function -> SlicingCmds.set

  val get_function : SlicingTypes.sl_select -> Cil_types.kernel_function

  val merge_internal :
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val add_to_selects_internal :
    Cil_datatype.Varinfo.Map.key * SlicingInternals.fct_user_crit ->
    SlicingInternals.fct_user_crit Cil_datatype.Varinfo.Map.t ->
    SlicingInternals.fct_user_crit Cil_datatype.Varinfo.Map.t

  val iter_selects_internal :
    (Cil_datatype.Varinfo.Map.key * 'a -> unit) ->
    'a Cil_datatype.Varinfo.Map.t -> unit

  val fold_selects_internal :
    ('a -> Cil_datatype.Varinfo.Map.key * 'b -> 'a) ->
    'a -> 'b Cil_datatype.Varinfo.Map.t -> 'a

  val select_stmt_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Cil_types.stmt ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_label_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Cil_types.logic_label ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_min_call_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Cil_types.stmt ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_stmt_zone_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Cil_types.stmt ->
    before:bool ->
    Locations.Zone.t ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_zone_at_entry_point_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Locations.Zone.t ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_zone_at_end_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Locations.Zone.t ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_modified_output_zone_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Locations.Zone.t ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_stmt_ctrl_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Cil_types.stmt ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_entry_point_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_return_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_decl_var_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    Cil_types.varinfo ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  val select_pdg_nodes_internal :
    Kernel_function.t ->
    ?select:Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit ->
    PdgTypes.Node.t list ->
    SlicingTypes.sl_mark ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit

  (** {2 Debug} *)

  val pretty :
    Format.formatter ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit -> unit

end

(* ---------------------------------------------------------------------- *)

(** {1 Slice} *)
module Slice : sig

  type t = SlicingTypes.sl_fct_slice
  val dyn_t : SlicingTypes.Sl_fct_slice.t Type.t

  (** {2 Functions with journalized side effects } *)

  val create : Kernel_function.t -> SlicingTypes.Sl_fct_slice.t

  val remove : SlicingTypes.Sl_fct_slice.t -> unit

  val remove_uncalled : unit -> unit

  (** {2 No needs of Journalization} *)

  val get_all : Kernel_function.t -> SlicingInternals.fct_slice list

  val get_function :
    SlicingInternals.fct_slice -> Cil_types.kernel_function

  val get_callers :
    SlicingInternals.fct_slice -> SlicingInternals.fct_slice list

  val get_called_slice :
    SlicingInternals.fct_slice ->
    Cil_types.stmt -> SlicingInternals.fct_slice option

  val get_called_funcs :
    SlicingInternals.fct_slice ->
    Cil_types.stmt -> Kernel_function.Hptset.elt list

  val get_mark_from_stmt :
    SlicingInternals.fct_slice ->
    Cil_types.stmt -> SlicingInternals.pdg_mark

  val get_mark_from_label :
    SlicingInternals.fct_slice ->
    Cil_types.stmt -> Cil_types.label -> SlicingInternals.pdg_mark

  val get_mark_from_local_var :
    SlicingInternals.fct_slice ->
    Cil_types.varinfo -> SlicingInternals.pdg_mark

  val get_mark_from_formal :
    SlicingInternals.fct_slice ->
    Cil_datatype.Varinfo.t -> SlicingInternals.pdg_mark

  val get_user_mark_from_inputs :
    SlicingInternals.fct_slice -> SlicingInternals.pdg_mark

  val get_num_id : SlicingInternals.fct_slice -> int

  val from_num_id :
    Kernel_function.t -> int -> SlicingInternals.fct_slice

  (** {2 Debug} *)

  val pretty : Format.formatter -> SlicingInternals.fct_slice -> unit

end

(* ---------------------------------------------------------------------- *)

(** {1 Slicing request} *)
module Request : sig

  (** {2 Functions with journalized side effects } *)

  val apply_all : propagate_to_callers:bool -> unit

  val apply_all_internal : unit -> unit

  val apply_next_internal : unit -> unit

  val propagate_user_marks : unit -> unit

  val copy_slice :
    SlicingTypes.Sl_fct_slice.t -> SlicingTypes.Sl_fct_slice.t

  val split_slice :
    SlicingTypes.Sl_fct_slice.t -> SlicingTypes.Sl_fct_slice.t list

  val merge_slices :
    SlicingTypes.Sl_fct_slice.t ->
    SlicingTypes.Sl_fct_slice.t ->
    replace:bool -> SlicingTypes.Sl_fct_slice.t

  val add_call_slice :
    caller:SlicingTypes.Sl_fct_slice.t ->
    to_call:SlicingTypes.Sl_fct_slice.t -> unit

  val add_call_fun :
    caller:SlicingTypes.Sl_fct_slice.t ->
    to_call:Kernel_function.t -> unit

  val add_call_min_fun :
    caller:SlicingTypes.Sl_fct_slice.t ->
    to_call:Kernel_function.t -> unit

  val add_selection : Select.selections -> unit

  val add_persistent_selection : Select.selections -> unit

  val add_persistent_cmdline : unit -> unit

  (** {2 No needs of Journalization} *)

  val is_request_empty_internal : unit -> bool

  val add_slice_selection_internal :
    SlicingInternals.fct_slice ->
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit -> unit

  val add_selection_internal :
    Cil_datatype.Varinfo.t * SlicingInternals.fct_user_crit -> unit

  (** {2 Debug} *)

  val pretty : Format.formatter -> unit

end
