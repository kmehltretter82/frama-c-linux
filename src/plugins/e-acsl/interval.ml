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

(* Implement Figure 3 of J. Signoles' JFLA'15 paper "Rester statique pour
   devenir plus rapide, plus précis et plus mince". *)

exception Not_an_integer

(* ********************************************************************* *)
(* Basic datatypes and operations *)
(* ********************************************************************* *)

(* constructors *)

let singleton_of_int n = Ival.inject_singleton (Integer.of_int n)

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

(* TODO: why is it useful? Crash if not here, but why? *)
(* Return the interval over which ranges the smallest typ containing [i]. *)
let interv_of_typ_containing_interv i =
  try
    let kind = ikind_of_interv i in
    interv_of_typ (TInt(kind, []))
  with Cil.Not_representable ->
    (* infinity *)
    Ival.inject_range None None

let interv_of_unknown_block =
  (* since we have no idea of the size of this block, we take the largest
     possible one which is unfortunately quite large *)
  lazy
    (Ival.inject_range (Some Integer.zero) (Some (Bit_utils.max_byte_address ())))

(* imperative environments *)

module Env = struct
  open Cil_datatype
  let tbl: Ival.t Logic_var.Hashtbl.t = Logic_var.Hashtbl.create 7
  let clear () = Logic_var.Hashtbl.clear tbl
  let add = Logic_var.Hashtbl.add tbl
  let remove = Logic_var.Hashtbl.remove tbl
  let replace = Logic_var.Hashtbl.replace tbl
  let find_all = Logic_var.Hashtbl.find_all tbl
  let find = Logic_var.Hashtbl.find tbl
end

(* ********************************************************************* *)
(* Main algorithm *)
(* ********************************************************************* *)

let infer_sizeof ty =
  try singleton_of_int (Cil.bytesSizeOf ty)
  with Cil.SizeOfError _ -> interv_of_typ Cil.theMachine.Cil.typeOfSizeOf

let infer_alignof ty = singleton_of_int (Cil.bytesAlignOf ty)

let rec infer t =
  let get_cty t = match t.term_type with Ctype ty -> ty | _ -> assert false in
  match t.term_node with
  | TConst (Integer (n,_)) -> Ival.inject_singleton n
  | TConst (LChr c) ->
    let n = Cil.charConstToInt c in
    Ival.inject_singleton n
  | TConst (LEnum enumitem) ->
    let rec find_idx n = function
      | [] -> assert false
      | ei :: l -> if ei == enumitem then n else find_idx (n + 1) l
    in
    let n = Integer.of_int (find_idx 0 enumitem.eihost.eitems) in
    Ival.inject_singleton n
  | TLval lv -> infer_term_lval lv
  | TSizeOf ty -> infer_sizeof ty
  | TSizeOfE t -> infer_sizeof (get_cty t)
  | TSizeOfStr str -> singleton_of_int (String.length str + 1 (* '\0' *))
  | TAlignOf ty -> infer_alignof ty
  | TAlignOfE t -> infer_alignof (get_cty t)

  | TUnOp (Neg, t) ->
    Ival.neg_int (infer t)
  | TUnOp (BNot, t) ->
    Ival.bitwise_signed_not (infer t)
  | TUnOp (LNot, _)

  | TBinOp ((Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr), _, _) ->
    Ival.zero_or_one
  | TBinOp (PlusA, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    Ival.add_int i1 i2
  | TBinOp (MinusA, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    Ival.sub_int i1 i2
  | TBinOp (Mult, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    Ival.mul i1 i2
  | TBinOp (Div, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    Ival.div i1 i2
  | TBinOp (Mod, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    Ival.c_rem i1 i2
  | TBinOp (Shiftlt , _, _) -> Error.not_yet "right shift"
  | TBinOp (Shiftrt , _, _) -> Error.not_yet "left shift"
  | TBinOp (BAnd, _, _) -> Error.not_yet "bitwise and"
  | TBinOp (BXor, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    Ival.bitwise_xor i1 i2
  | TBinOp (BOr, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    Ival.bitwise_or i1 i2
  | TCastE (ty, t)
  | TCoerce (t, ty) ->
    (try
       let it = infer t in
       let ity = interv_of_typ ty in
       Ival.meet it ity
     with Not_an_integer ->
       if Cil.isIntegralType ty then begin
         (* heterogeneous cast from a non-integral term to an integral type:
            consider that one eventually gets an integral type even if it is
            not sure. *)
         Options.warning
           ~once:true "possibly unsafe cast from term '%a' to type '%a'."
           Printer.pp_term t
           Printer.pp_typ ty;
         interv_of_typ ty
       end else
         raise Not_an_integer)
  | Tif (_, t2, t3) ->
    let i2 = infer t2 in
    let i3 = infer t3 in
    Ival.join i2 i3
  | Tat (t, _) -> infer t
  | TBinOp (MinusPP, t, _) ->
    (match Cil.unrollType (get_cty t) with
     | TArray(_, _, { scache = Computed n (* size in bits *) }, _) ->
       (* the second argument must be in the same block than [t]. Consequently
          the result of the difference belongs to [0; \block_length(t)] *)
       let nb_bytes = if n mod 8 = 0 then n / 8 else n / 8 + 1 in
       Ival.inject_range (Some Integer.zero) (Some (Integer.of_int nb_bytes))
     | TArray _ | TPtr _ -> Lazy.force interv_of_unknown_block
     | _ -> assert false)
  | Tblock_length (_, t)
  | Toffset(_, t) ->
    (match Cil.unrollType (get_cty t) with
     | TArray(_, _, { scache = Computed n (* size in bits *) }, _) ->
       let nb_bytes = if n mod 8 = 0 then n / 8 else n / 8 + 1 in
       singleton_of_int nb_bytes
     | TArray _ | TPtr _ -> Lazy.force interv_of_unknown_block
     | _ -> assert false)
  | Tnull  -> singleton_of_int 0
  | TLogic_coerce (_, t) -> infer t
  | TCoerceE (t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    Ival.meet i1 i2

  | Tapp (li, _, _args) ->
    (match li.l_type with
    | None -> assert false (* [None] only possible for predicates *)
    | Some Linteger ->
      begin match li.l_body with
      | LBpred _ ->
        Ival.zero_or_one
      | LBterm t' ->
        let i =
          if Misc.is_recursive li then
            (*  1) Build a system of interval equations that
                constrain the solution:
                do so by returning a variable when encoutering
                a call of a recursive function instead of
                performing the usual interval inference
                BEWARE: we might be tempted to memoize the
                  solution for a given function signature
                  HOWEVER: it cannot be done in a straightforward
                    manner due to the cases of functions that use
                    C (global) variables in their definition (as the values of
                    those variables can change between two function calls). *)
            let ieqs = Fixpoint.Ieqs.empty in
            let ivar, ieqs, _ = build_ieqs t ieqs [] in
            (*  2) Solve it:
                The problem is probably undecidable in the general case.
                Thus we just look for reasonably precise approximations
                without being too computationally expensive:
                simply iterate over a finite set of pre-defined intervals.
                See [Fixpoint.solve] for details. *)
            let chain_of_ivalmax =
              [| Integer.one; Integer.billion_one; Integer.max_int64 |]
              (* This set can be changed based on experimental evidences,
                 but it works fine for now. *)
            in
            let i = Fixpoint.solve ieqs ivar chain_of_ivalmax in
            i
          else begin
            List.iter2
              (fun lv arg ->
                try
                  let i = interv_of_typ_containing_interv (infer arg) in
                  Env.add lv i
                with Not_an_integer ->
                  ())
              li.l_profile
              _args;
            let i =
              try infer t'
              with Not_an_integer -> Ival.inject_range None None
            in
            List.iter (fun lv -> Env.remove lv) li.l_profile;
            i
          end
        in
        i
      | LBnone ->
        Error.not_yet "logic functions with no definition nor reads clause"
      | LBreads _ ->
        Error.not_yet "logic functions performing read accesses"
      | LBinductive _ ->
        Error.not_yet "logic functions inductively defined"
      end
    | Some (Ctype ty) -> interv_of_typ ty
    | Some _ -> raise Not_an_integer)
  | Tunion _ -> Error.not_yet "tset union"
  | Tinter _ -> Error.not_yet "tset intersection"
  | Tcomprehension (_,_,_) -> Error.not_yet "tset comprehension"
  | Trange(Some n1, Some n2) ->
    let i1 = infer n1 in
    let i2 = infer n2 in
    Ival.join i1 i2
  | Trange(None, _) | Trange(_, None) ->
    Options.abort "unbounded ranges are not part of E-ACSl"

  | Tlet (li,t) ->
    let li_t = Misc.term_of_li li in
    let li_v = li.l_var_info in
    let i = infer li_t in
    Env.add li_v i;
    let i = infer t in
    Env.remove li_v;
    i
  | TConst (LStr _ | LWStr _ | LReal _)
  | TBinOp (PlusPI,_,_)
  | TBinOp (IndexPI,_,_)
  | TBinOp (MinusPI,_,_)
  | TAddrOf _
  | TStartOf _
  | Tlambda (_,_)
  | TDataCons (_,_)
  | Tbase_addr (_,_)
  | TUpdate (_,_,_)
  | Ttypeof _
  | Ttype _
  | Tempty_set  -> raise Not_an_integer

and infer_term_lval (host, offset as tlv) =
  match offset with
  | TNoOffset -> infer_term_host host
  | _ ->
    let ty = Logic_utils.logicCType (Cil.typeOfTermLval tlv) in
    interv_of_typ ty

and infer_term_host h = match h with
  | TVar v ->
    (try Env.find v
    with Not_found ->
      match v.lv_type with
      | Linteger ->
        Ival.inject_range None None
      | Ctype (TFloat _) -> (* TODO: handle in MR !226 *)
        raise Not_an_integer
      | Lreal ->
        Error.not_yet "real numbers"
      | Ctype _ ->
        interv_of_typ (Logic_utils.logicCType v.lv_type)
      | Ltype _ | Lvar _ | Larrow _ ->
        Options.fatal "unexpected logic type")
  | TResult ty -> interv_of_typ ty
  | TMem t ->
    let ty = Logic_utils.logicCType t.term_type in
    match Cil.unrollType ty with
    | TPtr(ty, _) | TArray(ty, _, _, _) -> interv_of_typ ty
    | _ ->
      Options.fatal "unexpected type %a for term %a"
        Printer.pp_typ ty
        Printer.pp_term t

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
and build_ieqs t ieqs ivars =
  match t.term_node with
  | Tapp(li, _, args) ->
    if li.l_type = Some Linteger && Misc.is_recursive li then begin
      let args_lty = List.map2
        (fun lv arg ->
          try
            let i = interv_of_typ_containing_interv (infer arg) in
            Env.add lv i;
            Ctype (TInt(ikind_of_interv i, []))
          with
          | Cil.Not_representable -> Linteger
          | Not_an_integer -> lv.lv_type)
        li.l_profile
        args
      in
      (* x *)
      let ivar = Fixpoint.Ivar(li.l_var_info.lv_name, args_lty) in
      (* Adding x = g(x) if it is not yet in the system of equations.
        Without this check, the algorithm would not terminate. *)
      let ieqs, ivars =
        if Fixpoint.ivars_contains_ivar ivars ivar then ieqs, ivars
        else
          let iexp, ieqs, ivars =
            build_ieqs (Misc.term_of_li li) ieqs (ivar :: ivars)
          in
          let ieqs = Fixpoint.Ieqs.add ivar iexp ieqs in (* Adding x = g(x) *)
          ieqs, ivars
      in
      List.iter (fun lv -> Env.remove lv) li.l_profile;
      ivar, ieqs, ivars
    end else
      (try Fixpoint.Iconst(infer t), ieqs, ivars
      with Not_an_integer -> Fixpoint.Iunsupported, ieqs, ivars)
  | TConst _ ->
    (try Fixpoint.Iconst(infer t), ieqs, ivars
    with Not_an_integer -> Fixpoint.Iunsupported, ieqs, ivars)
  | TLval(TVar _, _) ->
    (try Fixpoint.Iconst(infer t), ieqs, ivars
    with Not_an_integer -> Fixpoint.Iunsupported, ieqs, ivars)
  | TBinOp (PlusA, t1, t2) ->
    let iexp1, ieqs, ivars = build_ieqs t1 ieqs ivars in
    let iexp2, ieqs, ivars = build_ieqs t2 ieqs ivars in
    Fixpoint.Ibinop(Fixpoint.Ival_add, iexp1, iexp2), ieqs, ivars
  | TBinOp (MinusA, t1, t2) ->
    let iexp1, ieqs, ivars = build_ieqs t1 ieqs ivars in
    let iexp2, ieqs, ivars = build_ieqs t2 ieqs ivars in
    Fixpoint.Ibinop(Fixpoint.Ival_min, iexp1, iexp2), ieqs, ivars
  | TBinOp (Mult, t1, t2) ->
    let iexp1, ieqs, ivars = build_ieqs t1 ieqs ivars in
    let iexp2, ieqs, ivars = build_ieqs t2 ieqs ivars in
    Fixpoint.Ibinop(Fixpoint.Ival_mul, iexp1, iexp2), ieqs, ivars
  | TBinOp (Div, t1, t2) ->
    let iexp1, ieqs, ivars = build_ieqs t1 ieqs ivars in
    let iexp2, ieqs, ivars = build_ieqs t2 ieqs ivars in
    Fixpoint.Ibinop(Fixpoint.Ival_div, iexp1, iexp2), ieqs, ivars
  | Tif(_, t1, t2) ->
    let iexp1, ieqs, ivars = build_ieqs t1 ieqs ivars in
    let iexp2, ieqs, ivars = build_ieqs t2 ieqs ivars in
    Fixpoint.Ibinop(Fixpoint.Ival_union, iexp1, iexp2), ieqs, ivars
  | _ ->
    Fixpoint.Iunsupported, ieqs, ivars

(*
Local Variables:
compile-command: "make"
End:
 *)
