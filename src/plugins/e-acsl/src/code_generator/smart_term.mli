open Cil_types

val is_pointer_type : typ -> bool

val deref_cty : typ -> typ

val lval : ?cty:typ -> loc:location -> term_lval -> term

val deref : ?cty:typ ->  loc:location -> term -> term

val array_at0 : loc:location -> term -> term
