open Cil_types

val must_translate_ref : (Property.t -> bool) ref
val must_translate_opt_ref : (Property.t option -> bool) ref


val type_program : file -> unit

(* val type_code_annot : Typing.Params_ty.t -> code_annotation -> unit *)

val preprocess_predicate : Typing.Params_ty.t -> predicate -> unit

val preprocess_rte : lenv:Typing.Params_ty.t -> code_annotation -> unit
