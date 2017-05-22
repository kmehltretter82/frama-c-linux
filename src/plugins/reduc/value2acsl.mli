open Cil_types

(* [value_to_predicate_opt loc t value] may create a predicate given a [value]
   about some [term].
   @return None if no such predicate can be created. *)
val value_to_predicate_opt: ?loc:location -> term -> Cvalue.V.t -> predicate option

val lval_to_predicate: ?loc:location -> Cvalue.Model.t -> lval -> predicate option
val exp_to_predicate: ?loc:location -> Cvalue.Model.t -> exp -> predicate option
