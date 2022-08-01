(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

open Cil
open Cil_types
open Cil_datatype

exception Error of Cil_types.location * string
exception Unbound of string

let find_var kf kinstr ?label var =
  let vi =
    try
      let vi = Globals.Vars.find_from_astinfo var (VLocal kf) in
      (match kinstr with
       | Kglobal -> vi (* don't refine search: the Kglobal here
                          does not indicate the function contract, but merely
                          the fact that we do not have any information about
                          the targeted program point. Hence, no scope check
                          can be performed or we might reject many legitimate
                          terms and predicates.
                       *)
       | Kstmt stmt ->
         let scope =
           match label with
           | None | Some "Here" | Some "Post" | Some "Old" -> stmt
           | Some "Pre" -> raise Not_found (* no local variable in scope. *)
           | Some "Init" -> raise Not_found (* no local variable in scope. *)
           | Some "LoopEntry" | Some "LoopCurrent" ->
             if not (Kernel_function.stmt_in_loop kf stmt) then
               Kernel.fatal
                 "Use of LoopEntry or LoopCurrent outside of a loop";
             Kernel_function.find_enclosing_loop kf stmt
           | Some l ->
             (try let s = Kernel_function.find_label kf l in !s
              with Not_found ->
                Kernel.fatal
                  "Use of label %s that does not exist in function %a"
                  l Kernel_function.pretty kf)
         in
         if Kernel_function.var_is_in_scope scope vi then vi
         else raise Not_found)
    with Not_found ->
    try
      Globals.Vars.find_from_astinfo var (VFormal kf)
    with Not_found ->
      Globals.Vars.find_from_astinfo var VGlobal
  in
  cvar_to_lvar vi

(** Create a logic typer, the interpretation being done for the given
    kernel_function and stmt (the stmt is used check that loop invariants
    are allowed). *)
(* It is theoretically possible to use a first-class module instead, but the
   required signatures are not exported in Logic_typing. *)
module DefaultLT (X:
                  sig
                    val kf: Kernel_function.t
                    val kinstr: Cil_types.kinstr
                  end) =
  Logic_typing.Make
    (struct
      let anonCompFieldName = Cabs2cil.anonCompFieldName
      let conditionalConversion = Cabs2cil.logicConditionalConversion

      let is_loop () =
        match X.kinstr with
        | Kglobal -> false
        | Kstmt s -> Kernel_function.stmt_in_loop X.kf s

      let find_macro _ = raise Not_found

      let find_var ?label var = find_var X.kf X.kinstr ?label var

      let find_enum_tag x =
        try
          Globals.Types.find_enum_tag x
        with Not_found ->
          (* The ACSL typer tries to parse a string, first as a variable,
             then as an enum. We report the "Unbound variable" message
             here, as it is nicer for the user. However, this short-circuits
             the later stages of resolution, for example global logic
             variables. *)
          raise (Unbound ("Unbound variable " ^ x))

      let find_comp_field info s =
        let field = Cil.getCompField info s in
        Field(field,NoOffset)

      let find_type = Globals.Types.find_type

      let find_label s = Kernel_function.find_label X.kf s
      include Logic_env

      let add_logic_function =
        add_logic_function_gen Logic_utils.is_same_logic_profile

      let remove_logic_info =
        remove_logic_info_gen Logic_utils.is_same_logic_profile

      let integral_cast ty t =
        raise
          (Failure
             (Format.asprintf
                "term %a has type %a, but %a is expected."
                Printer.pp_term t
                Printer.pp_logic_type Linteger
                Printer.pp_typ ty))

      let error loc msg =
        Pretty_utils.ksfprintf (fun e -> raise (Error (loc, e))) msg

      let on_error f rollback x =
        try f x with Error (loc,msg) as exn -> rollback (loc,msg); raise exn

    end)

(** Set up the parser for the infamous 'C hack' needed to parse typedefs *)
let sync_typedefs () =
  Logic_env.reset_typenames ();
  Globals.Types.iter_types
    (fun name _ ns ->
       if ns = Logic_typing.Typedef then Logic_env.add_typename name)

let wrap f parsetree loc =
  match parsetree with
  | None -> raise (Error (loc, "Syntax error in annotation"))
  | Some annot -> try f annot with Unbound s -> raise (Error (loc, s))

let code_annot kf stmt s =
  sync_typedefs ();
  let module LT = DefaultLT(struct
      let kf = kf
      let kinstr = Kstmt stmt
    end) in
  let loc = Stmt.loc stmt in
  let pa =
    Option.bind
      (Logic_lexer.annot (fst loc,s))
      (function (_, Logic_ptree.Acode_annot (_,a)) -> Some a | _ -> None)
  in
  let parse pa =
    LT.code_annot
      (Stmt.loc stmt)
      (Logic_utils.get_behavior_names (Annotations.funspec kf))
      (Ctype (Kernel_function.get_return_type kf)) pa
  in
  wrap parse pa loc

let default_term_env () =
  Logic_typing.append_here_label (Logic_typing.Lenv.empty())

let term kf ?(loc=Location.unknown) ?(env=default_term_env ()) s =
  sync_typedefs ();
  let module LT = DefaultLT(struct
      let kf = kf
      let kinstr = Kglobal
    end) in
  let pa_expr = Option.map snd (Logic_lexer.lexpr (fst loc, s)) in
  let parse pa_expr = LT.term env pa_expr in
  wrap parse pa_expr loc

let term_lval kf ?(loc=Location.unknown) ?(env=default_term_env ()) s =
  match (term kf ~loc ~env s).term_node with
  | TLval lv -> lv
  | _ -> raise (Error (loc, "Syntax error (expecting an lvalue)"))

let predicate kf ?(loc=Location.unknown) ?(env=default_term_env ()) s =
  sync_typedefs ();
  let module LT = DefaultLT(struct
      let kf = kf
      let kinstr = Kglobal
    end) in
  let pa_expr = Option.map snd (Logic_lexer.lexpr (fst loc, s)) in
  let parse pa_expr = LT.predicate env pa_expr in
  wrap parse pa_expr loc
