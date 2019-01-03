(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

open Cil_types

type ival_binop = Ival_add | Ival_min | Ival_mul | Ival_div | Ival_union

type ival_exp =
  | Iconst of Ival.t
  | Ivar of string * logic_type list
  | Ibinop of ival_binop * ival_exp * ival_exp
  | Iunsupported

let equal_ivar ivar1 ivar2  = match ivar1, ivar2 with
  | Ivar(str1, ltys1), Ivar(str2, ltys2) ->
    str1 = str2 &&
    List.fold_left2
      (fun b lty1 lty2 -> b && Cil_datatype.Logic_type.equal lty1 lty2)
      true
      ltys1
      ltys2
  | _ ->
    Options.fatal "not an ivar"

module Ieqs: sig
  type t
  val empty: t
  val add: ival_exp -> ival_exp -> t -> t
  val find: ival_exp -> t -> ival_exp
  val cardinal: t -> int
  val fold: (ival_exp -> ival_exp -> 'a -> 'a) -> t -> 'a -> 'a
  val map: (ival_exp -> ival_exp) -> t -> t
end = struct
  module H = Map.Make(struct
    type t = ival_exp (* an Ivar to be precise *)
    let compare ivar1 ivar2 = if equal_ivar ivar1 ivar2 then 0 else 1
  end)
  type t = ival_exp H.t
  let empty = H.empty
  let add ivar iexp ieqs = match ivar with
    | Ivar _ -> H.add ivar iexp ieqs
    | _ -> Options.fatal "left-hand side is NOT an ivar"
  let find = H.find
  let map = H.map
  let fold = H.fold
  let cardinal = H.cardinal
end

(* Normalize the expression.
  An expression is said to be normalized if it is:
    - either Iunsupported
    - or an expression that contains no Iunsupported *)
let normalize_iexp iexp =
  let rec has_unsupported iexp = match iexp with
    | Iunsupported | Ibinop(_, Iunsupported, _) | Ibinop(_, _, Iunsupported) ->
      true
    | Ibinop(_, (Iconst _ | Ivar _), (Iconst _ | Ivar _))
    | Iconst _ | Ivar _ ->
      false
    | Ibinop(_, iexp1, iexp2) ->
      has_unsupported iexp1 || has_unsupported iexp2
  in
  if has_unsupported iexp then Iunsupported else iexp

let normalize_ieqs ieqs =
  Ieqs.map (fun iexp -> normalize_iexp iexp) ieqs

let ivars_contains_ivar ivars ivar =
  List.fold_left (fun b ivar' -> b || equal_ivar ivar ivar') false ivars

let get_ival_of_iconst ieqs ivar = match Ieqs.find ieqs ivar with
  | Iconst i -> i
  | Ivar _ | Ibinop _| Iunsupported -> Options.fatal "not an Iconst"

(*************************************************************************)
(******************************** Solver *********************************)
(*************************************************************************)

(* [iterate indexes max] increases by 1 the leftmost element of [indexes] that
  is less or equal to [max].
  Eg: from index=[| 0; 0; 0 |] and max=2, the successive iterates
    until reaching index=[| max; max; max |] are as follows:
      [| 0; 0; 0 |]
      [| 1; 0; 0 |]
      [| 1; 1; 0 |]
      [| 1; 1; 1 |]
      [| 2; 1; 1 |]
      [| 2; 2; 1 |]
      [| 2; 2; 2 |]
  Note that the number [N] of iterates is linear in [max*l] where [l] is the
  length of [index]: [N=max*l+1].
  [int array] (instead of [int list]) is the proper data structure for storing
  [indexes], at least because its length is known in advance: the number of
  variables. *)
let iterate indexes max =
  let min_i = ref 0 in
  for indexes_i = 1 to Array.length indexes - 1 do
    if indexes.(indexes_i) < indexes.(!min_i) then min_i := indexes_i
  done;
  if indexes.(!min_i) + 1 <= max then
    (* The if-test is because the last iterate cannot be increased *)
    indexes.(!min_i) <- indexes.(!min_i) + 1

(* Returns an assignement to each variable of [ieqs] such that:
    - the first (resp. the second... the last) element of [indexes] is
      associated to the first (resp. the second... the last) variable of [ieqs]
    - a variable that is associated to an index [index] ranging in
      [0..max-1] will be given the interval of finite bounds:
      [-chain_of_ivalmax.(index), chain_of_ivalmax.(index)]
    - a variable that is associated to an index [index] equaling [max] will
      be given the whole interval of integers [Z]. *)
let to_iconsts indexes ieqs chain_of_ivalmax =
  let max = Array.length chain_of_ivalmax in
  let indexes_i = ref 0 in
  Ieqs.map
    (fun _ ->
      let ival =
        let index = indexes.(!indexes_i) in
        if index < max then
          let ivalmax = chain_of_ivalmax.(index) in
          Ival.inject_range (Some (Integer.neg ivalmax)) (Some ivalmax)
        else if
          index = max then Ival.inject_range None None
        else
          assert false
      in
      indexes_i := !indexes_i + 1;
      Iconst ival)
    ieqs

(* Assumes [iexp] to be a normalized [ival_exp] and evaluates it when each of
  its variable is replaced by the corresponding interval from [iconsts]. *)
let rec eval_iexp iexp iconsts =
  match iexp with
  | Iunsupported ->
    Iconst (Ival.inject_range None None)
  | Iconst _ ->
    iexp
  | Ivar _ ->
    Ieqs.find iexp iconsts
  | Ibinop(_, Iunsupported, _) | Ibinop(_, _, Iunsupported) ->
    assert false (* because [iexp] has been normalized *)
  | Ibinop(ibinop, iexp1, iexp2) ->
    let i1 = match eval_iexp iexp1 iconsts with
      | Iconst i -> i
      | Iunsupported | Ivar _ | Ibinop _ -> assert false
    in
    let i2 = match eval_iexp iexp2 iconsts with
      | Iconst i -> i
      | Iunsupported | Ivar _ | Ibinop _ -> assert false
    in
    match ibinop with
      | Ival_add -> Iconst (Ival.add_int i1 i2)
      | Ival_min -> Iconst (Ival.sub_int i1 i2)
      | Ival_mul -> Iconst (Ival.mul i1 i2)
      | Ival_div -> Iconst (Ival.div i1 i2)
      | Ival_union -> Iconst (Ival.join i1 i2)

let equal_iconst iconst1 iconst2 =
  let i1 = match iconst1 with
    | Iconst i -> i
    | Iunsupported | Ivar _ | Ibinop _ -> assert false
  in
  let i2 = match iconst2 with
    | Iconst i -> i
    | Iunsupported | Ivar _ | Ibinop _ -> assert false
  in
  Ival.is_included i1 i2

let is_post_fixpoint ieqs iconsts = Ieqs.fold
  (fun ivar iexp b ->
    let iconst1 = eval_iexp iexp iconsts in
    let iconst2 = Ieqs.find ivar iconsts in
    b && equal_iconst iconst1 iconst2)
  ieqs
  true

let rec iterate_till_post_fixpoint ieqs indexes chain_of_ivalmax =
  let iconsts = to_iconsts indexes ieqs chain_of_ivalmax in
  if is_post_fixpoint ieqs iconsts then
    iconsts
  else
    let index_max = Array.length chain_of_ivalmax in
    iterate indexes index_max;
    iterate_till_post_fixpoint ieqs indexes chain_of_ivalmax

let solve ieqs ivar chain_of_ivalmax =
  let ieqs = normalize_ieqs ieqs in
  let dim = Ieqs.cardinal ieqs in
  let bottom = Array.make dim 0 in
  let post_fixpoint =
    iterate_till_post_fixpoint ieqs bottom chain_of_ivalmax
  in
  get_ival_of_iconst ivar post_fixpoint