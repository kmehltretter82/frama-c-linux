(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2018                                               *)
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

(**************************************************************************)
(******************************* Types ************************************)
(**************************************************************************)

type ival_binop = Ival_add | Ival_min | Ival_mul | Ival_div | Ival_union

type ivar =
  (* it would be possible to get more precise results by storing an ival for
     each argument instead of a logic type, but the system would converge too
     slowly to a solution. *)
    { iv_name: string; iv_types: logic_type list }

type ival_exp =
  | Iconst of Ival.t
  | Ivar of ivar
  | Ibinop of ival_binop * ival_exp * ival_exp
  | Iunsupported

module LT_List =
  Datatype.List_with_collections
    (Cil_datatype.Logic_type)
    (struct let module_name = "E_ACSL.Interval_system.LT_List" end)

module Ivar =
  Datatype.Make_with_collections(struct
    type t = ivar
    let name = "E_ACSL.Interval_system.Ivar"
    let reprs = [ { iv_name = "a"; iv_types = Cil_datatype.Logic_type.reprs } ]
    include Datatype.Undefined
    let compare iv1 iv2 =
      let n = Datatype.String.compare iv1.iv_name iv2.iv_name in
      if n = 0 then LT_List.compare iv1.iv_types iv2.iv_types
      else n
    let equal = Datatype.from_compare
    let hash iv = Datatype.String.hash iv.iv_name + 7 * LT_List.hash iv.iv_types
  end)

(**************************************************************************)
(***************************** Solver *************************************)
(**************************************************************************)

exception Not_an_integer

let rec interv_of_typ ty = match Cil.unrollType ty with
  | TInt (k,_) as ty ->
    let n = Cil.bitsSizeOf ty in
    let l, u =
      if Cil.isSigned k then Cil.min_signed_number n, Cil.max_signed_number n
      else Integer.zero, Cil.max_unsigned_number n
    in
    Ival.inject_range (Some l) (Some u)
  | TEnum(enuminfo, _) -> interv_of_typ (TInt (enuminfo.ekind, []))
  | _ ->
    raise Not_an_integer

let ikind_of_interv i =
  if Ival.is_bottom i then IInt
  else match Ival.min_and_max i with
    | Some l, Some u ->
      let is_pos = Integer.ge l Integer.zero in
      let lkind = Cil.intKindForValue l is_pos in
      let ukind = Cil.intKindForValue u is_pos in
      (* kind corresponding to the interval *)
      let kind = if Cil.intTypeIncluded lkind ukind then ukind else lkind in
      (* convert the kind to [IInt] whenever smaller. *)
      if Cil.intTypeIncluded kind IInt then IInt else kind
    | None, None -> raise Cil.Not_representable (* GMP *)
    | None, Some _ | Some _, None ->
      Kernel.fatal ~current:true "ival: %a" Ival.pretty i

let interv_of_typ_containing_interv i =
  try
    let kind = ikind_of_interv i in
    interv_of_typ (TInt(kind, []))
  with Cil.Not_representable ->
    (* infinity *)
    Ival.inject_range None None

let ivars_contains_ivar ivars ivar =
  List.fold_left (fun b ivar' -> b || Ivar.equal ivar ivar') false ivars

(* Build the system of interval equations for the logic function called
  through [t].
  Example: the following function:
  f(Z n) = n < 0 ? 1 : f(n - 1) * f(n - 2) / f(n - 3)
  when called with f(37)
  will generate the following system of equations:
  X = [1; 1] U Y*Y/Y /\
  Y = [1; 1] U Z*Z/Z /\
  Z = [1; 1] U Z*Z/Z
  where X is the interval for f(int) (since 37 \in int),
  Y the one for f(long) (from int-1, int-2 and int-3)
  and Z the for the f(Z) (from long-1, long-2 and long-3) *)
let build ~infer t =
  let rec aux ieqs ivars t = match t.term_node with
  | Tapp(li, _, args) ->
    if li.l_type = Some Linteger && Misc.is_recursive li then begin
      let args_lty = List.map2
        (fun lv arg ->
          try
            (* speed-up convergence; because of this approximation, no need to
               associate [i] to [lv] in [Interval.Env]: the very same interval
               will be computed anyway. *)
            let i = interv_of_typ_containing_interv (infer arg) in
            Ctype (TInt(ikind_of_interv i, []))
          with
          | Cil.Not_representable -> Linteger
          | Not_an_integer -> lv.lv_type)
        li.l_profile
        args
      in
      (* x *)
      let ivar =
        { iv_name = li.l_var_info.lv_name; iv_types = args_lty }
      in
      (* Adding x = g(x) if it is not yet in the system of equations.
        Without this check, the algorithm would not terminate. *)
      let ieqs, ivars =
        if ivars_contains_ivar ivars ivar then ieqs, ivars
        else
          let (iexp:ival_exp), ieqs, ivars =
            aux ieqs (ivar :: ivars) (Misc.term_of_li li)
          in
          (* Adding x = g(x) *)
          let ieqs = Ivar.Map.add ivar iexp ieqs in
          ieqs, ivars
      in
      Ivar ivar, ieqs, ivars
    end else
      (try Iconst(infer t), ieqs, ivars
      with Not_an_integer -> Iunsupported, ieqs, ivars)
  | TConst _ ->
    (try Iconst(infer t), ieqs, ivars
    with Not_an_integer -> Iunsupported, ieqs, ivars)
  | TLval(TVar _, _) ->
    (try Iconst(infer t), ieqs, ivars
    with Not_an_integer -> Iunsupported, ieqs, ivars)
  | TBinOp (PlusA, t1, t2) ->
    let iexp1, ieqs, ivars = aux ieqs ivars t1 in
    let iexp2, ieqs, ivars = aux ieqs ivars t2 in
    Ibinop(Ival_add, iexp1, iexp2), ieqs, ivars
  | TBinOp (MinusA, t1, t2) ->
    let iexp1, ieqs, ivars = aux ieqs ivars t1 in
    let iexp2, ieqs, ivars = aux ieqs ivars t2 in
    Ibinop(Ival_min, iexp1, iexp2), ieqs, ivars
  | TBinOp (Mult, t1, t2) ->
    let iexp1, ieqs, ivars = aux ieqs ivars t1 in
    let iexp2, ieqs, ivars = aux ieqs ivars t2 in
    Ibinop(Ival_mul, iexp1, iexp2), ieqs, ivars
  | TBinOp (Div, t1, t2) ->
    let iexp1, ieqs, ivars = aux ieqs ivars t1 in
    let iexp2, ieqs, ivars = aux ieqs ivars t2 in
    Ibinop(Ival_div, iexp1, iexp2), ieqs, ivars
  | Tif(_, t1, t2) ->
    let iexp1, ieqs, ivars = aux ieqs ivars t1 in
    let iexp2, ieqs, ivars = aux ieqs ivars t2 in
    Ibinop(Ival_union, iexp1, iexp2), ieqs, ivars
  | _ ->
    Iunsupported, ieqs, ivars
  in
  aux Ivar.Map.empty [] t


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
  Ivar.Map.map (fun iexp -> normalize_iexp iexp) ieqs

let get_ival_of_iconst ieqs ivar = match Ivar.Map.find ieqs ivar with
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
  Ivar.Map.map
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
  | Ivar iv ->
    Ivar.Map.find iv iconsts
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

let is_post_fixpoint ieqs iconsts = Ivar.Map.fold
  (fun ivar iexp b ->
    let iconst1 = eval_iexp iexp iconsts in
    let iconst2 = Ivar.Map.find ivar iconsts in
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
  let dim = Ivar.Map.cardinal ieqs in
  let bottom = Array.make dim 0 in
  let post_fixpoint =
    iterate_till_post_fixpoint ieqs bottom chain_of_ivalmax
  in
  get_ival_of_iconst ivar post_fixpoint

let build_and_solve ~infer t =
  (* 1) Build a system of interval equations that constrain the solution: do so
     by returning a variable when encoutering a call of a recursive function
     instead of performing the usual interval inference.

     BEWARE: we might be tempted to memoize the solution for a given function
     signature HOWEVER: it cannot be done in a straightforward manner due to the
     cases of functions that use C (global) variables in their definition (as
     the values of those variables can change between two function calls).

     TODO: I do not understand the remark above. The interval of a C global
     variable is computed from its type. *)
  let iexp, ieqs, _ = build ~infer t in
  (*  2) Solve it:
      The problem is probably undecidable in the general case.
      Thus we just look for reasonably precise approximations
      without being too computationally expensive:
      simply iterate over a finite set of pre-defined intervals.
      See [Interval_system_solver.solve] for details. *)
  let chain_of_ivalmax =
    [| Integer.one; Integer.billion_one; Integer.max_int64 |]
    (* This set can be changed based on experimental evidences,
       but it works fine for now. *)
  in
  match iexp with
  | Ivar ivar -> solve ieqs ivar chain_of_ivalmax
  | Iconst _ | Ibinop _ | Iunsupported -> assert false
