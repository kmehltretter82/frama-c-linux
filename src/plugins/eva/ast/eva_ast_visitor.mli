(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Eva_ast_types

(** Rewriting visitor *)

module Rewrite :
sig
  type visitor = {
    exp : exp -> exp;
    lval : lval -> lval;
    varinfo : varinfo -> varinfo;
    offset : offset -> offset;
  }

  type rewriter = {
    rewrite_exp : visitor:visitor -> exp -> exp;
    rewrite_lval : visitor:visitor -> lval -> lval;
    rewrite_varinfo : visitor:visitor -> varinfo -> varinfo;
    rewrite_offset : visitor:visitor -> offset -> offset;
  }

  val default : rewriter
  val visit_exp : rewriter -> exp -> exp
  val visit_lval : rewriter -> lval -> lval
end


(** Folding visitor *)

module Fold :
sig
  type 'a visitor = {
    neutral : 'a;
    combine : 'a -> 'a -> 'a;
    exp : exp -> 'a;
    lval : lval -> 'a;
    varinfo : varinfo -> 'a;
    offset : offset -> 'a;
  }

  type 'a folder = {
    fold_exp : visitor:'a visitor -> exp -> 'a;
    fold_lval : visitor:'a visitor -> lval -> 'a;
    fold_varinfo : visitor:'a visitor -> varinfo -> 'a;
    fold_offset : visitor:'a visitor -> offset -> 'a;
  }

  val default : 'a folder
  val visit_exp : neutral:'a -> combine:('a -> 'a -> 'a) ->
    'a folder -> exp -> 'a
  val visit_lval : neutral:'a -> combine:('a -> 'a -> 'a) ->
    'a folder -> lval -> 'a
end
