open Cil_types

val preprocess : file -> unit

val preprocess_annot : code_annotation -> unit

val preprocess_predicate : predicate -> unit

val get_preprocessed_form : predicate -> Lscope.pred_or_term
