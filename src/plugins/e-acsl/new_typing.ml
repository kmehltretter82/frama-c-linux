(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2015                                               *)
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
(*  for more details (enclosed in the file license/LGPLv2.1).             *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(* Implement Figure 4 of J. Signoles' JFLA'15 paper "Rester statique pour
   devenir plus rapide, plus précis et plus mince". *)

let dkey = Options.dkey_typing

let compute_quantif_guards_ref
    : (predicate named -> logic_var list -> predicate named ->
       (term * relation * logic_var * relation * term) list) ref
    = Extlib.mk_fun "compute_quantif_guards_ref"

(******************************************************************************)
(** Datatypes and memoization *)
(******************************************************************************)

type integer_ty =
  | Gmp
  | C_type of ikind
  | Other

let join ty1 ty2 = match ty1, ty2 with
  | Other, Other -> Other
  | Other, (Gmp | C_type _) | (Gmp | C_type _), Other ->
    Options.fatal "[typing] join failure: integer and non integer type"
  | Gmp, _ | _, Gmp -> Gmp
  | C_type i1, C_type i2 ->
    let ty = Cil.arithmeticConversion (TInt(i1, [])) (TInt(i2, [])) in
    match ty with
    | TInt(i, _) -> C_type i
    | _ ->
      Options.fatal "[typing] join failure: unexpected result %a"
        Printer.pp_typ ty

let typ_of_integer_ty = function
  | Gmp -> Gmpz.t ()
  | C_type ik -> TInt(ik, [])
  | Other -> Options.fatal "[typing] not an integer type"

let c_int = C_type IInt

let size_t () = match Cil.theMachine.Cil.typeOfSizeOf with
  | TInt(kind, _) -> C_type kind
  | _ -> assert false

include Datatype.Make
(struct
  type t = integer_ty
  let name = "E_ACSL.New_typing.t"
  let reprs = [ Gmp; c_int ]
  include Datatype.Undefined

  let compare ty1 ty2 = match ty1, ty2 with
    | C_type i1, C_type i2 ->
      if i1 = i2 then 0
      else if Cil.intTypeIncluded i1 i2 then -1 else 1
    | (Other | C_type _), Gmp | Other, C_type _ -> -1
    | Gmp, (C_type _ | Other) | C_type _, Other -> 1
    | Gmp, Gmp | Other, Other -> 0

  let equal = Datatype.from_compare

  let pretty fmt = function
    | Gmp -> Format.pp_print_string fmt "GMP"
    | C_type k -> Printer.pp_ikind fmt k
    | Other -> Format.pp_print_string fmt "OTHER"
 end)

type computed_info =
    { ty: t;  (* type required for the term *)
      cast: t option; (* if not [None], type of the context which the term
                         must be casted to. If [None], no cast needed. *)
    }

module Memo: sig
  val memo: (term -> computed_info) -> term -> computed_info
  val get: term -> computed_info
  val clear: unit -> unit
end = struct

  module H = Hashtbl.Make(struct
    type t = term
    let equal (t1:term) t2 = t1 == t2
    let hash = Cil_datatype.Term.hash
  end)

  let tbl = H.create 97

  let get t =
    try H.find tbl t
    with Not_found ->
      Options.fatal
        "[typing] type of term '%a' was never computed."
        Printer.pp_term t

  let memo f t =
    try H.find tbl t
    with Not_found ->
      let x = f t in
      H.add tbl t x;
      x

  let clear () = H.clear tbl

end

(******************************************************************************)
(** {2 Coercion rules} *)
(******************************************************************************)

(* Compute the smallest type (bigger than [int]) which can contain the whole
   interval. It is the \theta operator of the JFLA's paper. *)
let ty_of_interv i =
  let open Interval in
  let is_pos = Integer.ge i.lower Integer.zero in
  try
    let lkind = Cil.intKindForValue i.lower is_pos in
    let ukind = Cil.intKindForValue i.upper is_pos in
    let kind = if Cil.intTypeIncluded lkind ukind then ukind else lkind in
    (* int whenever possible to prevent superfluous casts in the generated
       code *)
    if Cil.intTypeIncluded kind IInt then c_int else C_type kind
  with Cil.Not_representable ->
    Gmp

let coerce ~ctx ty =
  if compare ty ctx = 1 then begin
    (* type larger than the expected context,
       so we must introduce an explicit cast *)
    { ty = ty; cast = Some ctx }
  end else
    (* only add an explicit cast if the context is [Gmp] and [ty] is not *)
    if ctx = Gmp && ty <> Gmp then { ty = ty; cast = Some Gmp }
    else { ty = ty; cast = None }

(******************************************************************************)
(** {2 Type system} *)
(******************************************************************************)

let mk_ctx c = match c with
  | Other -> Other
  | Gmp | C_type _ -> if Options.Gmp_only.get () then Gmp else c

let rec type_term env ~ctx t =
  let ctx = mk_ctx ctx in
  let infer t =
    Cil.CurrentLoc.set t.term_loc;
    match t.term_node with
    | TConst (Integer _ | LChr _ | LEnum _)
    | TSizeOf _
    | TSizeOfStr _
    | TAlignOf _ ->
      (try
         let i = Interval.infer env t in
         ty_of_interv i
       with Interval.Not_an_integer ->
         Other)

    | TLval tlv ->
      (try
         let i = Interval.infer env t in
         type_term_lval env tlv;
         ty_of_interv i
       with Interval.Not_an_integer ->
         Other)

    | Tblock_length(_, t')
    | TSizeOfE t'
    | TAlignOfE t' ->
      (try
         let i = Interval.infer env t in
         (* [t'] must be typed, but it is a pointer *)
         ignore (type_term env ~ctx:Other t');
         ty_of_interv i
       with Interval.Not_an_integer ->
         Other)

    | TBinOp (MinusPP, t1, t2) ->
      (try
         let i = Interval.infer env t in
         (* [t1] and [t2] must be typed, but they are pointers *)
         ignore (type_term env ~ctx:Other t1);
         ignore (type_term env ~ctx:Other t2);
         ty_of_interv i
       with Interval.Not_an_integer ->
         Other)

    | TUnOp (_, t') ->
      let i = Interval.infer env t in
      let i' = Interval.infer env t' in
      let ctx = mk_ctx (ty_of_interv (Interval.join i i')) in
      ignore (type_term env ~ctx t');
      ctx

    | TBinOp((PlusA | MinusA | Mult | Div | Mod | Shiftlt | Shiftrt), t1, t2) ->
      let i = Interval.infer env t in
      let i1 = Interval.infer env t1 in
      let i2 = Interval.infer env t2 in
      let ctx = mk_ctx (ty_of_interv (Interval.join i (Interval.join i1 i2))) in
      ignore (type_term env ~ctx t1);
      ignore (type_term env ~ctx t2);
      ctx
    | TBinOp ((Lt | Gt | Le | Ge | Eq | Ne), t1, t2) ->
      assert (compare ctx c_int >= 0);
      let ctx =
        try
          let i1 = Interval.infer env t1 in
          let i2 = Interval.infer env t2 in
          mk_ctx (ty_of_interv (Interval.join i1 i2))
        with Interval.Not_an_integer ->
          Other
      in
      ignore (type_term env ~ctx t1);
      ignore (type_term env ~ctx t2);
      (match ctx with
      | Other -> c_int
      | Gmp | C_type _ -> ctx)
    | TBinOp ((LAnd | LOr), t1, t2) ->
      assert (compare ctx c_int >= 1);
      let i1 = Interval.infer env t1 in
      let i2 = Interval.infer env t2 in
      (* both operands fit in an int. *)
      ignore (type_term env ~ctx:c_int t1);
      ignore (type_term env ~ctx:c_int t2);
      ty_of_interv (Interval.join i1 i2)

    | TBinOp (BAnd, _, _) -> Error.not_yet "bitwise and"
    | TBinOp (BXor, _, _) -> Error.not_yet "bitwise xor"
    | TBinOp (BOr, _, _) -> Error.not_yet "bitwise or"

    | TCastE(_, t')
    | TCoerce(t', _) ->
      (* in any case, must type the subterms *)
      (try
         let i = Interval.infer env t' in
         (* nothing to do more: [i] is already more precise than what we could
            infer from the arguments of the cast. Also, do not type the internal
            term: possibly it is not even an integer *)
         let ty = ty_of_interv i in
         ignore (type_term env ~ctx:ty t');
         ty
       with Interval.Not_an_integer ->
         ignore (type_term env ~ctx:Other t');
         Other)

    | Tif (t1, t2, t3) ->
      let ctx = mk_ctx c_int in
      ignore (type_term env ~ctx t1);
      let i = Interval.infer env t in
      let ctx =
        try
          let i2 = Interval.infer env t2 in
          let i3 = Interval.infer env t3 in
          mk_ctx (ty_of_interv (Interval.join i (Interval.join i2 i3)))
        with Interval.Not_an_integer ->
          Other
      in
      ignore (type_term env ~ctx t2);
      ignore (type_term env ~ctx t3);
      ctx

    | Tat (t, _)
    | TLogic_coerce (_, t) -> (type_term env ~ctx t).ty

    | TCoerceE (t1, t2) ->
      let i = Interval.infer env t in
      let i1 = Interval.infer env t1 in
      let i2 = Interval.infer env t2 in
      let ty = ty_of_interv (Interval.join i (Interval.join i1 i2)) in
      ignore (type_term env ~ctx:ty t1);
      ignore (type_term env ~ctx:ty t2);
      ty

    | TAddrOf tlv
    | TStartOf tlv ->
      (* it is a pointer, as well as [t], but [t] must be typed. *)
      type_term_lval env tlv;
      Other

    | Toffset(_, t)
    | Tbase_addr (_, t) ->
      (* it is a pointer, as well as [t], but [t] must be typed. *)
      ignore (type_term env ~ctx:Other t);
      Other

    | TBinOp ((PlusPI | IndexPI | MinusPI), t1, t2) ->
      (* it is a pointer, as well as [t1], while [t2] is a size_t.
         Both [t1] and [t2] must be typed. *)
      ignore (type_term env ~ctx:Other t1);
      ignore (type_term env ~ctx:(size_t ()) t2);
      Other

    | Tapp (_,_,_) -> Error.not_yet "logic function application"
    | Tunion _ -> Error.not_yet "tset union"
    | Tinter _ -> Error.not_yet "tset intersection"
    | Tcomprehension (_,_,_) -> Error.not_yet "tset comprehension"
    | Trange (_,_) -> Error.not_yet "trange"
    | Tlet (_,_) -> Error.not_yet "let binding"
    | Tlambda (_,_) -> Error.not_yet "lambda"
    | TDataCons (_,_) -> Error.not_yet "datacons"
    | TUpdate (_,_,_) -> Error.not_yet "update"

    | Tnull
    | TConst (LStr _ | LWStr _ | LReal _)
    | Ttypeof _
    | Ttype _
    | Tempty_set  -> Other
  in
  Memo.memo (fun t -> let ty = infer t in coerce ~ctx ty) t

and type_term_lval env (host, offset) =
  type_term_lhost env host;
  type_term_offset env offset

and type_term_lhost env = function
  | TVar _
  | TResult _ -> ()
  | TMem t -> ignore (type_term env ~ctx:Other t)

and type_term_offset env = function
  | TNoOffset -> ()
  | TField(_, toff)
  | TModel(_, toff) -> type_term_offset env toff
  | TIndex(t, toff) ->
    (* [t] is an array index which must fits into size_t *)
    ignore (type_term env ~ctx:(size_t ()) t);
    type_term_offset env toff

let rec type_predicate_named env p =
  Cil.CurrentLoc.set p.loc;
  let ty = match p.content with
    | Pfalse | Ptrue -> c_int
    | Papp _ -> Error.not_yet "logic function application"
    | Pseparated _ -> Error.not_yet "\\separated"
    | Pdangling _ -> Error.not_yet "\\dangling"
    | Prel(_, t1, t2) ->
      let ctx =
        try
          let i1 = Interval.infer env t1 in
          let i2 = Interval.infer env t2 in
          let i = Interval.join i1 i2 in
          mk_ctx (ty_of_interv i)
        with Interval.Not_an_integer ->
          Other
      in
      ignore (type_term env ~ctx t1);
      ignore (type_term env ~ctx t2);
      (match ctx with
      | Other -> c_int
      | Gmp | C_type _ -> ctx)
    | Pand(p1, p2)
    | Por(p1, p2)
    | Pxor(p1, p2)
    | Pimplies(p1, p2)
    | Piff(p1, p2) ->
      ignore (type_predicate_named env p1);
      ignore (type_predicate_named env p2);
      c_int
    | Pnot p ->
      ignore (type_predicate_named env p);
      c_int
    | Pif(t, p1, p2) ->
      let ctx = mk_ctx c_int in
      ignore (type_term env ~ctx t);
      ignore (type_predicate_named env p1);
      ignore (type_predicate_named env p2);
      c_int
    | Plet _ -> Error.not_yet "let _ = _ in _"
    | Pforall(bounded_vars, { content = Pimplies(hyps, goal) })
    | Pexists(bounded_vars, { content = Pand(hyps, goal) }) ->
      let guards = !compute_quantif_guards_ref p bounded_vars hyps in
      let env =
        List.fold_left
          (fun env (t1, r1, x, r2, t2) ->
            let i1 = Interval.infer env t1 in
            let i1 = match r1 with
              | Rlt -> Interval.add i1 Integer.one
              | Rle -> i1
              | _ -> assert false
            in
            let i2 = Interval.infer env t2 in
            (* add one to [i2], since we increment the loop counter one more
               time before going out the loop. *)
            let i2 = match r2 with
              | Rlt -> i2
              | Rle -> Interval.add i2 Integer.one
              | _ -> assert false
            in
            let i = Interval.join i1 i2 in
            let ctx = mk_ctx (ty_of_interv i) in
            ignore (type_term env ~ctx t1);
            ignore (type_term env ~ctx t2);
            Interval.Env.add x i env)
          env
          guards
      in
      (type_predicate_named env goal).ty

    | Pinitialized(_, t)
    | Pfreeable(_, t)
    | Pallocable(_, t)
    | Pvalid(_, t)
    | Pvalid_read(_, t)
    | Pvalid_function t ->
      ignore (type_term env ~ctx:Other t);
      c_int

    | Pforall _ -> Error.not_yet "unguarded \\forall quantification"
    | Pexists _ -> Error.not_yet "unguarded \\exists quantification"
    | Pat(p, _) -> (type_predicate_named env p).ty
    | Pfresh _ -> Error.not_yet "\\fresh"
    | Psubtype _ -> Error.not_yet "subtyping relation" (* Jessie specific *)
  in
  coerce ~ctx:c_int ty

let type_term ~ctx t =
  Options.feedback ~dkey ~level:4 "typing term '%a' in ctx '%a'."
    Printer.pp_term t pretty ctx;
  ignore (type_term Interval.Env.empty ~ctx t)

let type_named_predicate ?(must_clear=true) p =
  Options.feedback ~dkey ~level:3 "typing predicate '%a'."
    Printer.pp_predicate_named p;
  if must_clear then Memo.clear ();
  ignore (type_predicate_named Interval.Env.empty p)

(******************************************************************************)
(** {2 Getters} *)
(******************************************************************************)

let get_integer_ty t =
  (Memo.get t).ty

let get_integer_ty_of_predicate p =
  (type_predicate_named Interval.Env.empty (* the env is useless *) p).ty

let get_typ t =
  let info = Memo.get t in
  typ_of_integer_ty info.ty

let get_cast t =
  Cil.CurrentLoc.set t.term_loc;
  let info = Memo.get t in
  Extlib.opt_map typ_of_integer_ty info.cast

let get_cast_of_predicate p =
  (* the env is useless *)
  let info = type_predicate_named Interval.Env.empty p in
  Extlib.opt_map typ_of_integer_ty info.cast

let clear = Memo.clear

(*
Local Variables:
compile-command: "make"
End:
*)
