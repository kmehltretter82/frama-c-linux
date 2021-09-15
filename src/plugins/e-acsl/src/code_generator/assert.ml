(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

(** Module with the context to hold the data contributing to an assertion and
    general functions to create assertion statements. *)

open Cil_types

(** Type holding information about the C variable representing the assertion
    data. *)
[@@@ warning "-69"]
type data = {
  (** Indicates if some data have been registered in the context or not. *)
  data_registered: bool;
  (* FIXME: fields added to hold information about the C variable in MR !3288 *)
}

(** External type representing the assertion context. Either [Some data] if we
    want to register some data in the context of [None] if we do not want to. *)
type t = data option

let no_data = None

let empty ~loc kf env =
  (* FIXME: C variable created in MR !3288 *)
  ignore (loc, kf);
  let data = { data_registered = false } in
  Some data , env

let with_data_from ~loc kf env from =
  match from with
  | Some _from ->
    let adata, env = empty ~loc kf env in
    (* FIXME: values copied from [from] to [adata] in MR !3288 *)
    adata, env
  | None -> None, env

let merge_right ~loc kf env adata1 adata2 =
  match adata1, adata2 with
  | Some _adata1, Some adata2 ->
    (* FIXME: values copied from [adata1] to [adata2] in MR !3288 *)
    ignore (loc, kf);
    Some adata2, env
  | None, Some adata -> Some adata, env
  | Some _, None | None, None -> None, env

let register ~loc kf env ?(force=false) name e adata =
  if Options.Assert_print_data.get () then
    match adata, e.enode with
    | Some adata, Const _ when not force ->
      (* By default, do not register constant expressions because the name of
         the data will be its value. For instance in expression [a + 3], the
         data [a] needs to be registered, but [3] already appears in the
         predicate message, and trying to register it will result in a data with
         name "3" and value [3].
         The registration can be forced for expressions like [sizeof(int)] for
         instance that are [Const] values but not directly known. *)
      Some adata, env
    | Some _adata, _ ->
      let adata = { data_registered = true } in
      (* FIXME: value registered to [adata] in MR !3288 *)
      ignore (loc, kf, env, name);
      Some adata, env
    | None, _ -> None, env
  else
    adata, env

let register_term ~loc kf env ?force t e adata =
  let name = Format.asprintf "@[%a@]" Printer.pp_term t in
  register ~loc kf env name ?force e adata

let register_pred ~loc kf env ?force p e adata =
  let name = Format.asprintf "@[%a@]" Printer.pp_predicate p in
  register ~loc kf env name ?force e adata

let kind_to_string loc k =
  Cil.mkString
    ~loc
    (match k with
     | Smart_stmt.Assertion -> "Assertion"
     | Smart_stmt.Precondition -> "Precondition"
     | Smart_stmt.Postcondition -> "Postcondition"
     | Smart_stmt.Invariant -> "Invariant"
     | Smart_stmt.Variant -> "Variant"
     | Smart_stmt.RTE -> "RTE")

let runtime_check_with_msg ~adata ~loc msg ~pred_kind kind kf env e =
  let blocking =
    match pred_kind with
    | Assert -> Cil.one ~loc
    | Check -> Cil.zero ~loc
    | Admit ->
      Options.fatal "No runtime check should be generated for 'admit' clauses"
  in
  let file = (fst loc).Filepath.pos_path in
  let line = (fst loc).Filepath.pos_lnum in
  (* FIXME: [adata] support in MR !3288 *)
  ignore adata;
  let stmt =
    Smart_stmt.rtl_call ~loc
      "assert"
      [ e;
        blocking;
        kind_to_string loc kind;
        Cil.mkString ~loc (Functions.RTL.get_original_name kf);
        Cil.mkString ~loc msg;
        Cil.mkString ~loc (Filepath.Normalized.to_pretty_string file);
        Cil.integer loc line ]
  in
  stmt, env

let runtime_check ~adata ~pred_kind kind kf env e p =
  let loc = p.pred_loc in
  let msg =
    Kernel.Unicode.without_unicode
      (Format.asprintf "%a@?" Printer.pp_predicate) p
  in
  runtime_check_with_msg ~adata ~loc msg ~pred_kind kind kf env e
