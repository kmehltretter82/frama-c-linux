open Cil_types

(** {3 Visitor behavior} *)
type t
  (** How the visitor should behave in front of mutable fields: in
      place modification or copy of the structure. This type is abstract.
      Use one of the two values below in your classes.
      @plugin development guide *)

val inplace_visit: unit -> t
  (** In-place modification. Behavior of the original cil visitor.
      @plugin development guide *)

val copy_visit: Project.t -> t
  (** Makes fresh copies of the mutable structures.
      - preserves sharing for varinfo.
      - makes fresh copy of varinfo only for declarations. Variables that are
      only used in the visited AST are thus still shared with the original
      AST. This allows for instance to copy a function with its
      formals and local variables, and to keep the references to other
      globals in the function's body.
      @plugin development guide *)

val refresh_visit: Project.t -> t
  (** Makes fresh copies of the mutable structures and provides fresh id
      for the structures that have ids. Note that as for {!copy_visit}, only
      varinfo that are declared in the scope of the visit will be copied and
      provided with a new id.
   *)

(** true iff the behavior provides fresh id for copied structs with id.
    Always [false] for an inplace visitor.
*)
val is_fresh: t -> bool

(** true iff the behavior is a copy behavior. *)
val is_copy: t -> bool

val get_project: t -> Project.t option

val reset_varinfo: t -> unit
(** resets the internal tables used by the given t.  If you use
    fresh instances of visitor for each round of transformation, this should
    not be needed. In place modifications do not need that at all.
    @plugin development guide
 *)

val reset_compinfo: t -> unit
val reset_enuminfo: t -> unit
val reset_enumitem: t -> unit
val reset_typeinfo: t -> unit
val reset_stmt: t -> unit
val reset_logic_info: t -> unit
val reset_logic_type_info: t -> unit
val reset_fieldinfo: t -> unit
val reset_model_info: t -> unit
val reset_logic_var: t -> unit
val reset_kernel_function: t -> unit
val reset_fundec: t -> unit

val get_varinfo: t -> varinfo -> varinfo
(** retrieve the representative of a given varinfo in the current
    state of the visitor
    @plugin development guide
 *)

val get_compinfo: t -> compinfo -> compinfo
val get_enuminfo: t -> enuminfo -> enuminfo
val get_enumitem: t -> enumitem -> enumitem
val get_typeinfo: t -> typeinfo -> typeinfo
val get_stmt: t -> stmt -> stmt
(** @plugin development guide *)

val get_logic_info: t -> logic_info -> logic_info
val get_logic_type_info: t -> logic_type_info -> logic_type_info
val get_fieldinfo: t -> fieldinfo -> fieldinfo
val get_model_info: t -> model_info -> model_info
val get_logic_var: t -> logic_var -> logic_var
val get_kernel_function: t -> kernel_function -> kernel_function
(** @plugin development guide *)

val get_fundec: t -> fundec -> fundec

val get_original_varinfo: t -> varinfo -> varinfo
  (** retrieve the original representative of a given copy of a varinfo
      in the current state of the visitor.
    @plugin development guide
   *)

val get_original_compinfo: t -> compinfo -> compinfo
val get_original_enuminfo: t -> enuminfo -> enuminfo
val get_original_enumitem: t -> enumitem -> enumitem
val get_original_typeinfo: t -> typeinfo -> typeinfo
val get_original_stmt: t -> stmt -> stmt
val get_original_logic_info: t -> logic_info -> logic_info
val get_original_logic_type_info:
  t -> logic_type_info -> logic_type_info
val get_original_fieldinfo: t -> fieldinfo -> fieldinfo
val get_original_model_info: t -> model_info -> model_info
val get_original_logic_var: t -> logic_var -> logic_var
val get_original_kernel_function:
  t -> kernel_function -> kernel_function
val get_original_fundec: t -> fundec -> fundec

val set_varinfo: t -> varinfo -> varinfo -> unit
  (** change the representative of a given varinfo in the current
      state of the visitor. Use with care (i.e. makes sure that the old one
      is not referenced anywhere in the AST, or sharing will be lost.
      @plugin development guide
  *)
val set_compinfo: t -> compinfo -> compinfo -> unit
val set_enuminfo: t -> enuminfo -> enuminfo -> unit
val set_enumitem: t -> enumitem -> enumitem -> unit
val set_typeinfo: t -> typeinfo -> typeinfo -> unit
val set_stmt: t -> stmt -> stmt -> unit
val set_logic_info: t -> logic_info -> logic_info -> unit
val set_logic_type_info:
  t -> logic_type_info -> logic_type_info -> unit
val set_fieldinfo: t -> fieldinfo -> fieldinfo -> unit
val set_model_info: t -> model_info -> model_info -> unit
val set_logic_var: t -> logic_var -> logic_var -> unit
val set_kernel_function:
  t -> kernel_function -> kernel_function -> unit
val set_fundec: t -> fundec -> fundec -> unit

val set_orig_varinfo: t -> varinfo -> varinfo -> unit
  (** change the reference of a given new varinfo in the current
      state of the visitor. Use with care
  *)
val set_orig_compinfo: t -> compinfo -> compinfo -> unit
val set_orig_enuminfo: t -> enuminfo -> enuminfo -> unit
val set_orig_enumitem: t -> enumitem -> enumitem -> unit
val set_orig_typeinfo: t -> typeinfo -> typeinfo -> unit
val set_orig_stmt: t -> stmt -> stmt -> unit
val set_orig_logic_info: t -> logic_info -> logic_info -> unit
val set_orig_logic_type_info:
  t -> logic_type_info -> logic_type_info -> unit
val set_orig_fieldinfo: t -> fieldinfo -> fieldinfo -> unit
val set_orig_model_info: t -> model_info -> model_info -> unit
val set_orig_logic_var: t -> logic_var -> logic_var -> unit
val set_orig_kernel_function:
  t -> kernel_function -> kernel_function -> unit
val set_orig_fundec: t -> fundec -> fundec -> unit

val unset_varinfo: t -> varinfo -> unit
  (** remove the entry associated to the given varinfo in the current
      state of the visitor. Use with care (i.e. make sure that you will never
      visit again this varinfo in the same visiting context).
      @plugin development guide
  *)
val unset_compinfo: t -> compinfo -> unit
val unset_enuminfo: t -> enuminfo -> unit
val unset_enumitem: t -> enumitem -> unit
val unset_typeinfo: t -> typeinfo -> unit
val unset_stmt: t -> stmt -> unit
val unset_logic_info: t -> logic_info -> unit
val unset_logic_type_info: t -> logic_type_info -> unit
val unset_fieldinfo: t -> fieldinfo -> unit
val unset_model_info: t -> model_info -> unit
val unset_logic_var: t -> logic_var -> unit
val unset_kernel_function: t -> kernel_function -> unit
val unset_fundec: t -> fundec -> unit

val unset_orig_varinfo: t -> varinfo -> unit
  (** remove the entry associated with the given new varinfo in the current
      state of the visitor. Use with care
  *)
val unset_orig_compinfo: t -> compinfo -> unit
val unset_orig_enuminfo: t -> enuminfo -> unit
val unset_orig_enumitem: t -> enumitem -> unit
val unset_orig_typeinfo: t -> typeinfo -> unit
val unset_orig_stmt: t -> stmt -> unit
val unset_orig_logic_info: t -> logic_info -> unit
val unset_orig_logic_type_info: t -> logic_type_info -> unit
val unset_orig_fieldinfo: t -> fieldinfo -> unit
val unset_orig_model_info: t -> model_info -> unit
val unset_orig_logic_var: t -> logic_var -> unit
val unset_orig_kernel_function: t -> kernel_function -> unit
val unset_orig_fundec: t -> fundec -> unit

val memo_varinfo: t -> varinfo -> varinfo
  (** finds a binding in new project for the given varinfo, creating one
      if it does not already exists. *)
val memo_compinfo: t -> compinfo -> compinfo
val memo_enuminfo: t -> enuminfo -> enuminfo
val memo_enumitem: t -> enumitem -> enumitem
val memo_typeinfo: t -> typeinfo -> typeinfo
val memo_stmt: t -> stmt -> stmt
val memo_logic_info: t -> logic_info -> logic_info
val memo_logic_type_info: t -> logic_type_info -> logic_type_info
val memo_fieldinfo: t -> fieldinfo -> fieldinfo
val memo_model_info: t -> model_info -> model_info
val memo_logic_var: t -> logic_var -> logic_var
val memo_kernel_function:
  t -> kernel_function -> kernel_function
val memo_fundec: t -> fundec -> fundec

(** [iter_visitor_varinfo vis f] iterates [f] over each pair of
    varinfo registered in [vis]. Varinfo for the old AST is presented
    to [f] first.
*)
val iter_visitor_varinfo:
  t -> (varinfo -> varinfo -> unit) -> unit
val iter_visitor_compinfo:
  t -> (compinfo -> compinfo -> unit) -> unit
val iter_visitor_enuminfo:
  t -> (enuminfo -> enuminfo -> unit) -> unit
val iter_visitor_enumitem:
  t -> (enumitem -> enumitem -> unit) -> unit
val iter_visitor_typeinfo:
  t -> (typeinfo -> typeinfo -> unit) -> unit
val iter_visitor_stmt:
  t -> (stmt -> stmt -> unit) -> unit
val iter_visitor_logic_info:
  t -> (logic_info -> logic_info -> unit) -> unit
val iter_visitor_logic_type_info:
  t -> (logic_type_info -> logic_type_info -> unit) -> unit
val iter_visitor_fieldinfo:
  t -> (fieldinfo -> fieldinfo -> unit) -> unit
val iter_visitor_model_info:
  t -> (model_info -> model_info -> unit) -> unit
val iter_visitor_logic_var:
  t -> (logic_var -> logic_var -> unit) -> unit
val iter_visitor_kernel_function:
  t -> (kernel_function -> kernel_function -> unit) -> unit
val iter_visitor_fundec:
  t -> (fundec -> fundec -> unit) -> unit

(** [fold_visitor_varinfo vis f] folds [f] over each pair of varinfo registered
    in [vis]. Varinfo for the old AST is presented to [f] first.
*)
val fold_visitor_varinfo:
  t -> (varinfo -> varinfo -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_compinfo:
  t -> (compinfo -> compinfo -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_enuminfo:
  t -> (enuminfo -> enuminfo -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_enumitem:
  t -> (enumitem -> enumitem -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_typeinfo:
  t -> (typeinfo -> typeinfo -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_stmt:
  t -> (stmt -> stmt -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_logic_info:
  t -> (logic_info -> logic_info -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_logic_type_info:
  t ->
  (logic_type_info -> logic_type_info -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_fieldinfo:
  t -> (fieldinfo -> fieldinfo -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_model_info:
  t -> (model_info -> model_info -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_logic_var:
  t -> (logic_var -> logic_var -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_kernel_function:
  t ->
  (kernel_function -> kernel_function -> 'a -> 'a) -> 'a -> 'a
val fold_visitor_fundec:
  t -> (fundec -> fundec -> 'a -> 'a) -> 'a -> 'a


val cfile: t -> file -> file
val cinitinfo: t -> initinfo -> initinfo
val cblock: t -> block -> block
val cfunspec: t -> funspec -> funspec
val cfunbehavior: t -> funbehavior -> funbehavior
val cidentified_term: t -> identified_term -> identified_term
val cidentified_predicate: t -> identified_predicate -> identified_predicate
val cexpr: t -> exp -> exp
val ccode_annotation: t -> code_annotation -> code_annotation
