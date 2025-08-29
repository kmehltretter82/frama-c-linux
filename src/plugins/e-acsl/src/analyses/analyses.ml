(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let analyses_feedback msg =
  Options.feedback ~level:2 "%s in %a" msg Project.pretty (Project.current ())

let preprocess () =
  let ast = Ast.get () in
  analyses_feedback "preprocessing annotations";
  Logic_normalizer.preprocess ast;
  analyses_feedback "normalizing quantifiers";
  Bound_variables.preprocess ast;
  analyses_feedback "infering interval of annotations";
  Interval.infer_program ast;
  analyses_feedback "typing annotations";
  Typing.type_program ast;
  analyses_feedback
    "computing future locations of labeled predicates and terms";
  Labels.preprocess ast

let reset () =
  Memory_tracking.reset ();
  Literal_strings.reset ();
  Bound_variables.clear_guards ();
  Logic_normalizer.clear ();
  Inductive.clear ();
  Interval.clear ();
  Typing.clear ();
  Labels.reset ()
