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

type ival_binop = Ival_add | Ival_min | Ival_mul | Ival_div | Ival_join

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
(***************************** Helpers ************************************)
(**************************************************************************)

let rec eval_iexp env = function
  | Iunsupported | Ibinop(_, Iunsupported, _) | Ibinop(_, _, Iunsupported) ->
    Ival.inject_range None None
  | Iconst i -> i
  | Ivar iv -> Ivar.Map.find iv env
  | Ibinop(ibinop, iexp1, iexp2) ->
    let i1 = eval_iexp env iexp1 in
    let i2 = eval_iexp env iexp2 in
    match ibinop with
    | Ival_add -> Ival.add_int i1 i2
    | Ival_min -> Ival.sub_int i1 i2
    | Ival_mul -> Ival.mul i1 i2
    | Ival_div -> Ival.div i1 i2
    | Ival_join -> Ival.join i1 i2

exception Not_an_integer

let is_recursive li = match li.l_body with
  | LBpred _ | LBnone | LBreads _ | LBinductive _ -> false
  | LBterm t ->
    let rec has_recursive_call t = match t.term_node with
    | TConst _ | TLval _ | TSizeOf _ | TSizeOfStr _ | TAlignOf _
    | Tnull | TAddrOf _ | TStartOf _ | Tempty_set | Ttypeof _
    | Ttype _->
      false
    | Tapp(li', _, ts) ->
      String.equal li.l_var_info.lv_name li'.l_var_info.lv_name
      || List.exists has_recursive_call ts
    | TUnOp(_, t) | TSizeOfE t | TCastE(_, t) | Tat(t, _) | Tlambda(_, t)
    | Toffset(_, t) | Tbase_addr(_, t) | TAlignOfE t | Tblock_length(_, t)
    | TLogic_coerce(_, t) | TCoerce(t, _) | Tcomprehension(t, _, _)
    | Tlet(_, t) ->
      has_recursive_call t
    | TBinOp(_, t1, t2) | TCoerceE(t1, t2) | TUpdate(t1, _, t2) ->
      has_recursive_call t1 || has_recursive_call t2
    | Trange(t1_opt, t2_opt) ->
      (match t1_opt with
       | None -> begin match t2_opt with
           | None -> false
           | Some t2 -> has_recursive_call t2
         end
       | Some t1 -> begin match t2_opt with
           | None -> has_recursive_call t1
           | Some t2 -> has_recursive_call t1 || has_recursive_call t2
         end)
    | Tif(t0, t1, t2) ->
      has_recursive_call t0 || has_recursive_call t1 || has_recursive_call t2
    | TDataCons(_, ts) | Tunion ts | Tinter ts ->
      List.exists has_recursive_call ts
    in
    has_recursive_call t

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

(**************************************************************************)
(***************************** Builder ************************************)
(**************************************************************************)

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
      if li.l_type = Some Linteger && is_recursive li then begin
        let args_lty =
          List.map2
            (fun lv arg ->
               try
                 (* speed-up convergence; because of this approximation, no need
                    to associate [i] to [lv] in [Interval.Env]: the very same
                    interval will be computed anyway. *)
                 let i = interv_of_typ_containing_interv (infer arg) in
                 Ctype (TInt(ikind_of_interv i, []))
               with
               | Cil.Not_representable -> Linteger
               | Not_an_integer -> lv.lv_type)
            li.l_profile
            args
        in
        let ivar = { iv_name = li.l_var_info.lv_name; iv_types = args_lty } in
        (* Adding x = g(x) if it is not yet in the system of equations.
           Without this check, the algorithm would not terminate. *)
        let ieqs, ivars =
          if List.exists (fun ivar' -> Ivar.equal ivar ivar') ivars
          then ieqs, ivars
          else
            let iexp, ieqs, ivars =
              aux ieqs (ivar :: ivars) (Misc.term_of_li li)
            in
            (* Adding x = g(x) *)
            let ieqs = Ivar.Map.add ivar iexp ieqs in
            ieqs, ivars
        in
        Ivar ivar, ieqs, ivars
      end else begin
        try Iconst (infer t), ieqs, ivars
        with Not_an_integer -> Iunsupported, ieqs, ivars
      end
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
      Ibinop(Ival_join, iexp1, iexp2), ieqs, ivars
    | _ ->
      Iunsupported, ieqs, ivars
  in
  aux Ivar.Map.empty [] t

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
   - the n-th element of [indexes] is associated to the n-th variable of [ieqs]
   - a variable that is associated to an index [index] ranging in [0..max-1] is
   associated to the finite interval
   [-chain_of_ivalmax.(index), chain_of_ivalmax.(index)]
   - a variable that is associated to an index [index] equals to [max] is
   associated to [Z]. *)
let to_iconsts chain_of_ivalmax indexes ieqs =
  let max = Array.length chain_of_ivalmax in
  let indexes_i = ref 0 in
  Ivar.Map.map
    (fun _ ->
      let ival =
        let index = indexes.(!indexes_i) in
        if index < max then
          let ivalmax = chain_of_ivalmax.(index) in
          Ival.inject_range (Some (Integer.neg ivalmax)) (Some ivalmax)
        else if index = max then Ival.inject_range None None
        else assert false
      in
      indexes_i := !indexes_i + 1;
      ival)
    ieqs

let is_post_fixpoint ieqs env =
  Ivar.Map.for_all
    (fun ivar iexp ->
       let i1 = eval_iexp env iexp in
       let i2 = Ivar.Map.find ivar env in
       Ival.is_included i1 i2)
    ieqs

let rec iterate_till_post_fixpoint chain_of_ivalmax indexes ieqs =
  let iconsts = to_iconsts chain_of_ivalmax indexes ieqs in
  if is_post_fixpoint ieqs iconsts then
    iconsts
  else
    let index_max = Array.length chain_of_ivalmax in
    iterate indexes index_max;
    iterate_till_post_fixpoint chain_of_ivalmax indexes ieqs

let solve chain_of_ivalmax ivar ieqs =
  let dim = Ivar.Map.cardinal ieqs in
  let bottom = Array.make dim 0 in
  let post_fixpoint =
    iterate_till_post_fixpoint chain_of_ivalmax bottom ieqs
  in
  Ivar.Map.find ivar post_fixpoint

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
  let iexp, ieqs, _ivars = build ~infer t in
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
  | Ivar ivar -> solve chain_of_ivalmax ivar ieqs
  | Iconst _ | Ibinop _ | Iunsupported ->
    (* TODO: check this assert false carefully *)
    assert false
