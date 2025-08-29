(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)


open Cabs
open Format

val pp_cabsloc : formatter -> cabsloc -> unit
val pp_storage : formatter -> storage -> unit
val pp_cvspec : formatter -> cvspec -> unit
val pp_const : formatter -> constant -> unit
val pp_labels : formatter -> string list -> unit
val pp_typeSpecifier : formatter -> typeSpecifier -> unit
val pp_spec_elem : formatter -> spec_elem -> unit
val pp_spec : formatter -> specifier -> unit
val pp_decl_type : formatter -> decl_type -> unit
val pp_name_group : formatter -> name_group -> unit
val pp_field_group : formatter -> field_group -> unit
val pp_field_groups : formatter -> field_group list -> unit
val pp_init_name_group : formatter -> init_name_group -> unit
val pp_name : formatter -> name -> unit
val pp_init_name : formatter -> init_name -> unit
val pp_single_name : formatter -> single_name -> unit
val pp_enum_item : formatter -> enum_item -> unit
val pp_def : formatter -> definition -> unit
val pp_block : formatter -> block -> unit
val pp_raw_stmt : formatter -> raw_statement -> unit
val pp_stmt : formatter -> statement -> unit
val pp_for_clause : formatter -> for_clause -> unit
val pp_bin_op : formatter -> binary_operator -> unit
val pp_un_op : formatter -> unary_operator -> unit
val pp_exp : formatter -> expression -> unit
val pp_exp_node : formatter -> cabsexp -> unit
val pp_init_exp : formatter -> init_expression -> unit
val pp_initwhat : formatter -> initwhat -> unit
val pp_attr : formatter -> attribute -> unit
val pp_attrs : formatter -> attribute list -> unit
val pp_file : formatter -> file -> unit
