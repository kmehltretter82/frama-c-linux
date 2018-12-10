(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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
open Eval

(* Whether the domain infers non-relational intervals (ivals) to improve the
   precision of the join operation: this avoids losing all relations that have
   been inferred in only one side of the join. Enhances the domain accuracy
   for a minimal drop in efficiency. *)
let infer_intervals = true

(* -------------------------------------------------------------------------- *)
(*                  Basic types: pair of variables and Ival.t                 *)
(* -------------------------------------------------------------------------- *)

(* Variables of the octagons. Should be extended later to also include
   symbolic lvalues. *)
module Variable = struct
  include Cil_datatype.Varinfo
  let id v = v.vid
end

module VariableSet = struct
  include Variable.Set
  let pretty_debug = pretty
end

(* Pairs of related variables in an octagon.
   This module imposes an order between the two variables X and Y in a pair
   to avoid creating octagons about X±Y *and* about Y±X. *)
module Pair = struct
  module D = Datatype.Pair (Variable) (Variable)
  module Info = struct
    let name = "Octagons.Pair"
    let dependencies = [ Ast.self ]
    let initial_values = []
  end

  include State_builder.Hashcons (D) (Info)

  (* Creates a pair, and also returns a boolean that is [true] is x, y are swap
     in the pair. *)
  let make x y =
    assert (x.vid <> y.vid);
    let pair, swap = if x.vid < y.vid then (x, y), false else (y, x), true in
    hashcons pair, swap

  let fst t = fst (get t)
end


(* Kind of relation between two variables X and Y: X+Y or X-Y. *)
type operation = Add | Sub

(* Extended arithmetic operations over Ival.t. *)
module Arith = struct
  open Ival

  let narrow x y =
    let r = narrow x y in
    if is_bottom r then `Bottom else `Value r

  let widen =
    let hints = Integer.zero,
                (Ival.Widen_Hints.default_widen_hints,
                 Fc_float.Widen_Hints.default_widen_hints)
    in
    Ival.widen hints

  (* TODO: do not use Ival.top on floating-point value? *)
  let project_float ival =
    if Ival.(equal top ival) then Fval.top
    else project_float ival

  let neg = function
    | Float f -> inject_float (Fval.neg f)
    | ival -> neg_int ival

  let int_or_float_operation i_op f_op = fun typ ->
    match Cil.unrollType typ with
    | TInt _ | TEnum _ -> i_op
    | TFloat _ -> fun i1 i2 ->
      inject_float (f_op Fval.Real (project_float i1) (project_float i2))
    | _ -> assert false

  let sub = int_or_float_operation Ival.sub_int Fval.sub
  let add = int_or_float_operation Ival.add_int Fval.add

  let apply = function
    | Add -> add
    | Sub -> sub
end

(* -------------------------------------------------------------------------- *)
(*              Rewriting Cil expressions into mathematical octagons          *)
(* -------------------------------------------------------------------------- *)

(* An octagonal relation between two variables : b ≤ X±Y ≤ e *)
type octagon =
  { variables: Pair.t;      (* The two related variables X and Y. *)
    operation: operation;   (* Whether the relation is about X+Y or X-Y. *)
    value: Ival.t;          (* The interval of X±Y. *)
  }

(* Transforms Cil expressions into mathematical octagons.
   Use Ival.t to evaluate expressions. *)
module Rewriting = struct

  (* Checks that the interval [ival] fits in the C type [typ].
     This is used to ensure that an expression cannot overflow: this module
     uses the mathematical semantics of arithmetic operations, and cannot
     soundly translate overflows in the C semantics.  *)
  let fits_in_type typ ival =
    let open Eval_typ in
    match classify_as_scalar typ with
    | None -> assert false (* This should not happen here. *)
    | Some (TSFloat _) -> true
    | Some (TSInt ir | TSPtr ir) ->
      (ir.i_signed && Kernel.SignedOverflow.get ()) ||
      (not ir.i_signed && Kernel.UnsignedOverflow.get ()) ||
      let min = range_lower_bound ir in
      let max = range_upper_bound ir in
      let range = Ival.inject_range (Some min) (Some max) in
      Ival.is_included ival range

  (* Simplified form [±X-coeff] for expressions,
     where X is a variable and coeff an interval. *)
  type var_coeff = { varinfo: varinfo; sign: bool; coeff: Ival.t; }

  (* Negates a simplified form. *)
  let neg { varinfo; sign; coeff } =
    { varinfo; sign = not sign; coeff = Arith.neg coeff }

  (* Is the interval computed for a variable a singleton? *)
  let is_singleton = function
    | `Top -> false
    | `Value ival -> Ival.cardinal_zero_or_one ival

  (* If a needed interval is unknown, stop the current computation and returns
     an empty list. *)
  let (>>) value f = match value with
    | `Top -> []
    | `Value ival -> f ival

  (* Apply [f typ v1 v2] if the operation [e1 op e2] does not overflow,
     where [v1] and [v2] are the intervals for [e1] and [e2], and [typ] is
     the type of [e1]. Returns the empty list otherwise. *)
  let apply_binop f evaluate typ e1 op e2 =
    evaluate e1 >> fun v1 ->
    evaluate e2 >> fun v2 ->
    let typ_e1 = Cil.typeOf e1 in
    let result = Arith.apply op typ_e1 v1 v2 in
    if fits_in_type typ_e1 result && fits_in_type typ result
    then f typ_e1 v1 v2
    else []

  (* Rewrites the Cil expression [expr] into the simplified form [±x-coeff],
     where [x] is a non-singleton variable and [coeff] is an interval. The
     result follows the mathematical semantics.
     If such a simplified form cannot be found, the function returns an empty
     list. If multiple variables occur in the expression, the function tries to
     compute a list of equivalent forms [±x-coeff], one for each variable.  The
     function relies on an evaluation function linking each sub-expression into
     an interval, used for computing sound coefficients. The evaluation may
     return Top for some sub-expression, thus preventing the computation. *)
  let rec rewrite evaluate expr =
    match expr.enode with
    | Lval (Var varinfo, NoOffset) ->
      if Cil.isArithmeticType varinfo.vtype
      && not (Cil.typeHasQualifier "volatile" varinfo.vtype)
      && not (is_singleton (evaluate expr))
      then [ { varinfo; sign = true; coeff = Ival.zero } ]
      else []

    | UnOp (Neg, e, typ) ->
      evaluate e >> fun v ->
      if fits_in_type typ (Arith.neg v)
      then List.map neg (rewrite evaluate e)
      else []

    | BinOp ((PlusA | MinusA as binop), e1, e2, typ) ->
      let op = if binop = PlusA then Add else Sub in
      let rewrite_binop typ v1 v2 =
        let inverse_op = if binop = PlusA then Arith.sub else Arith.add in
        let add_v2 var =
          { var with coeff = inverse_op typ var.coeff v2 }
        in
        let add_v1 var =
          let var = if binop = MinusA then neg var else var in
          { var with coeff = Arith.sub typ var.coeff v1 }
        in
        List.map add_v2 (rewrite evaluate e1) @
        List.map add_v1 (rewrite evaluate e2)
      in
      apply_binop rewrite_binop evaluate typ e1 op e2

    | CastE (typ, e) ->
      if Cil.(isIntegralType typ && isIntegralType (typeOf e)) then
        evaluate e >> fun v ->
        if fits_in_type typ v then rewrite evaluate e else []
      else []

    | Info (e, _) -> rewrite evaluate e

    | _ -> []

  (* Rewrites the operation [e1 ± e2] into equivalent octagons ±(X±Y-value). *)
  let rewrite_binop evaluate e1 binop e2 =
    let vars1 = rewrite evaluate e1 in
    let vars2 = rewrite evaluate e2 in
    let vars2 = if binop = Sub then List.map neg vars2 else vars2 in
    let aux acc var1 var2 =
      if Cil_datatype.Varinfo.equal var1.varinfo var2.varinfo
      then acc
      else
        let variables, swap = Pair.make var1.varinfo var2.varinfo in
        let operation = if var1.sign = var2.sign then Add else Sub in
        let sign = match operation with
          | Add -> var1.sign
          | Sub -> if swap then var2.sign else var1.sign
        in
        let value = Arith.add (Cil.typeOf e1) var1.coeff var2.coeff in
        let value = if sign then value else Arith.neg value in
        (sign, { variables; operation; value }) :: acc
    in
    Extlib.product_fold aux [] vars1 vars2

  (* Returns the range of the expression X-Y when the comparison X#Y holds. *)
  let comparison_range =
    let open Abstract_interp.Comp in
    function
    | Lt -> Ival.inject_range None (Some Integer.minus_one)
    | Gt -> Ival.inject_range (Some Integer.one) None
    | Le -> Ival.inject_range None (Some Integer.zero)
    | Ge -> Ival.inject_range (Some Integer.zero) None
    | Eq -> Ival.zero
    | Ne -> Ival.top

  (* Transforms the constraint [expr] ∈ [ival] into a list of octagonal
     constraints. *)
  let make_octagons evaluate expr ival =
    let make_octagons_from_binop typ e1 op e2 ival =
      (* equivalent octoganal forms ±(X±Y-v) for [e1 op e2]. *)
      let rewritings = rewrite_binop evaluate e1 op e2 in
      (* create the final octagon, knowning that [e1 op e2] ∈ [ival]. *)
      let make_octagon (sign, octagon) =
        let ival = if sign then ival else Arith.neg ival in
        let value = Arith.add typ ival octagon.value in
        { octagon with value }
      in
      List.map make_octagon rewritings
    in
    match expr.enode with
    | BinOp ((PlusA | MinusA as binop), e1, e2, typ) ->
      let op = if binop = PlusA then Add else Sub in
      let make_octagons typ _ _ = make_octagons_from_binop typ e1 op e2 ival in
      apply_binop make_octagons evaluate typ e1 op e2
    | BinOp ((Lt | Gt | Le | Ge | Eq | Ne as binop), e1, e2, _typ) ->
      let typ = Cil.typeOf e1 in
      if not (Cil.isIntegralType typ)
      || (Ival.contains_zero ival && Ival.contains_non_zero ival)
      then []
      else
        let comp = Value_util.conv_comp binop in
        let comp =
          if Ival.is_zero ival then Abstract_interp.Comp.inv comp else comp
        in
        let range = comparison_range comp in
        make_octagons_from_binop typ e1 Sub e2 range
    | _ -> []

  (* Evaluates the Cil expression [expr], by rewriting it into octagonal
     constraints using [evaluate_expr] to evaluate sub-expressions, and
     then using [evaluate_octagon] to evaluate the octagons. *)
  let evaluate_through_octagons evaluate_expr evaluate_octagon expr =
    let evaluate_octagon acc (sign, octagon) =
      match evaluate_octagon octagon with
      | None -> acc
      | Some ival ->
        let ival = if sign then ival else Arith.neg ival in
        Ival.narrow acc ival
    in
    let evaluate_octagons octagons =
      List.fold_left evaluate_octagon Ival.top octagons
    in
    match expr.enode with
    | BinOp ((PlusA | MinusA as binop), e1, e2, typ) ->
      let op = if binop = PlusA then Add else Sub in
      let octagons = rewrite_binop evaluate_expr e1 op e2 in
      let ival = evaluate_octagons octagons in
      if Ival.(equal top ival) then ival else
        let typ_e1 = Cil.typeOf e1 in
        let ival2 =
          match evaluate_expr e1, evaluate_expr e2 with
          | `Value v1, `Value v2 -> Arith.apply op typ_e1 v1 v2
          | _, _ -> Ival.top
        in
        let ival = Ival.narrow ival ival2 in
        if fits_in_type typ ival && fits_in_type typ_e1 ival
        then ival
        else Ival.top
    | BinOp ((Lt | Gt | Le | Ge | Eq as binop), e1, e2, _typ)
      when Cil.isIntegralType (Cil.typeOf e1) ->
      let comp = Value_util.conv_comp binop in
      (* Evaluate [e1 - e2] and compare the resulting interval to the interval
         for which the comparison [e1 # e2] holds. *)
      let range = comparison_range comp in
      let octagons = rewrite_binop evaluate_expr e1 Sub e2 in
      let ival = evaluate_octagons octagons in
      if Ival.is_included ival range then Ival.one
      else if not (Ival.intersects ival range) then Ival.zero else Ival.top
    | _ -> Ival.top

end

(* -------------------------------------------------------------------------- *)
(*           Diamonds and octagons: relations between two variables           *)
(* -------------------------------------------------------------------------- *)

(* This domain infers relations between pairs of variables (X, Y), by inferring
   intervals for the mathematical operations X+Y and X-Y.
   It also infers non-relational intervals for the separate variable X and Y
   (they could be seen as intervals for X+X and Y+Y, but we chose to store them
   in another way). These intervals are used to make the join more precise.
   Geometrically, in a plan, intervals for X and Y shape a straight rectangle,
   while intervals for X+Y and X-Y shape a "leaning" rectangle; the intersection
   of these rectangles shapes an octagon.
   Using a misnomer, we call diamonds the intervals for X+Y and X-Y, and
   octagons the map from variables to diamonds, even if they does not exactly
   shape octagons. *)

(* Relation between a pair of variables (X, Y).
   [add] is an interval for X+Y, and [sub] is an interval for [X-Y]. *)
type diamond = { add: Ival.t; sub: Ival.t }

module DiamondDatatype = struct
  type t = diamond
  include Datatype.Serializable_undefined

  let name = "Octagons.Diamond"
  let structural_descr =
    Structural_descr.t_record [| Ival.packed_descr; Ival.packed_descr |]
  let reprs = [ { add = Ival.top; sub = Ival.top } ]

  let compare x y =
    let c = Ival.compare x.add y.add in
    if c <> 0 then c else Ival.compare x.sub y.sub

  let equal = Datatype.from_compare

  let hash { add; sub } = Hashtbl.hash (Ival.hash add, Ival.hash sub)

  let pretty fmt { add; sub } =
    Format.fprintf fmt "@[<hov>ADD: @[%a@] ; SUB: @[%a@]@]"
      Ival.pretty add Ival.pretty sub
end

module Diamond = struct
  include Datatype.Make (DiamondDatatype)
  let pretty_debug = pretty

  let top = { add = Ival.top; sub = Ival.top }
  let is_top = equal top

  let is_included x y =
    Ival.is_included x.add y.add && Ival.is_included x.sub y.sub

  let join x y =
    { add = Ival.join x.add y.add; sub = Ival.join x.sub y.sub }

  let widen x y =
    { add = Arith.widen x.add y.add; sub = Arith.widen x.sub y.sub }

  let narrow x y =
    Arith.narrow x.add y.add >>- fun add ->
    Arith.narrow x.sub y.sub >>-: fun sub -> {add; sub}

  (* Makes a diamond about (X, Y) from a diamond about (Y, X). *)
  let reverse_variables t = { t with sub = Arith.neg t.sub }
end


(* Maps linking pairs of variables (X, Y) to intervals for X+Y and X-Y. *)
module Octagons = struct
  module Initial_Values = struct let v = [[]] end
  module Dependencies = struct let l = [ Ast.self ] end

  include Hptmap.Make (Pair) (Diamond)
      (Hptmap.Comp_unused) (Initial_Values) (Dependencies)

  let pretty fmt t =
    let iter f = iter (fun k v -> f (k, v)) in
    let pretty fmt (pair, diamond) =
      let x, y = Pair.get pair in
      let pretty_one op ival =
        if not Ival.(equal top ival)
        then
          Format.fprintf fmt "@[@[%a %s %a@]@ ->@ @[%a@]@]"
            Variable.pretty x op Variable.pretty y Ival.pretty ival
      in
      pretty_one "+" diamond.add;
      pretty_one "-" diamond.sub
    in
    Pretty_utils.pp_iter
      ~pre:"@[<v 3>{[ " ~suf:" ]}@]" ~sep:"@ "
      iter pretty fmt t

  let top = empty

  let is_included =
    let cache = Hptmap_sig.PersistentCache "Octagons.Octagons.is_included" in
    let decide_fst _ _ = true in
    let decide_snd _ _ = false in
    let decide_both _ x y = Diamond.is_included x y in
    let decide_fast t1 t2 = decide_fast_inclusion t2 t1 in
    binary_predicate cache UniversalPredicate
      ~decide_fast ~decide_fst ~decide_snd ~decide_both

  exception EBottom

  let narrow_exc =
    let cache = Hptmap_sig.NoCache in
    let decide _pair x y =
      match Diamond.narrow x y with
      | `Value v -> v
      | `Bottom -> raise EBottom
    in
    join ~cache ~symmetric:true ~idempotent:true ~decide

  let narrow x y = try `Value (narrow_exc x y) with EBottom -> `Bottom

  let simple_join =
    let cache = Hptmap_sig.PersistentCache "Octagons.Octagons.join" in
    let decide _pair x y =
      let r = Diamond.join x y in
      if Diamond.is_top r then None else Some r
    in
    inter ~cache ~symmetric:true ~idempotent:true ~decide

  let join ~decide_left ~decide_right =
    let cache = Hptmap_sig.NoCache in
    let decide_left = Traversing decide_left
    and decide_right = Traversing decide_right in
    let decide_both _pair x y =
      let r = Diamond.join x y in
      if Diamond.is_top r then None else Some r
    in
    merge ~cache ~symmetric:false ~idempotent:true
      ~decide_left ~decide_right ~decide_both

  let simple_widen =
    let cache = Hptmap_sig.PersistentCache "Octagons.Octagons.widen" in
    let decide _pair x y =
      let r = Diamond.widen x y in
      if Diamond.is_top r then None else Some r
    in
    inter ~cache ~symmetric:false ~idempotent:true ~decide

  let widen ~decide_left ~decide_right =
    let cache = Hptmap_sig.NoCache in
    let decide_left = Traversing decide_left
    and decide_right = Traversing decide_right in
    let decide_both _pair x y =
      let r = Diamond.widen x y in
      if Diamond.is_top r then None else Some r
    in
    merge ~cache ~symmetric:false ~idempotent:true
      ~decide_left ~decide_right ~decide_both

  let unsafe_add = add

  let add variables diamond t =
    try
      Diamond.narrow diamond (find variables t) >>-: fun diamond ->
      add variables diamond t
    with Not_found -> `Value (add variables diamond t)

  let add_octagon { variables; operation; value; } t =
    let diamond =
      try find variables t
      with Not_found -> Diamond.top
    in
    let diamond =
      match operation with
      | Add ->
        Arith.narrow diamond.add value >>-: fun add ->
        { diamond with add }
      | Sub ->
        Arith.narrow diamond.sub value >>-: fun sub ->
        { diamond with sub }
    in
    diamond >>-: fun diamond -> unsafe_add variables diamond t

  let evaluate octagon t =
    try
      let diamond = find octagon.variables t in
      let ival = match octagon.operation with
        | Add -> diamond.add
        | Sub -> diamond.sub
      in
      if Ival.(equal top ival)
      then None
      else
        let typ = (Pair.fst octagon.variables).vtype in
        let ival = Arith.sub typ ival octagon.value in
        Some ival
    with Not_found -> None
end

(* -------------------------------------------------------------------------- *)
(*                                  Relations                                 *)
(* -------------------------------------------------------------------------- *)

(* Keep track of related variables in an octagon state. *)
module Relations = struct
  module Initial_Values = struct let v = [[]] end
  module Dependencies = struct let l = [ Ast.self ] end

  include Hptmap.Make (Variable) (VariableSet)
      (Hptmap.Comp_unused) (Initial_Values) (Dependencies)

  let inter =
    let cache = Hptmap_sig.PersistentCache "Octagons.Relations.inter" in
    let decide _pair x y =
      let r = Variable.Set.inter x y in
      if Variable.Set.is_empty r then None else Some r
    in
    inter ~cache ~symmetric:true ~idempotent:true ~decide

  let union =
    let cache = Hptmap_sig.PersistentCache "Octagons.Relations.union" in
    let decide _pair x y = Variable.Set.union x y in
    join ~cache ~symmetric:true ~idempotent:true ~decide

  (* Marks y as related to x. *)
  let relate_aux x y t =
    let related =
      try find x t
      with Not_found -> VariableSet.empty
    in
    let updated = VariableSet.add y related in
    add x updated t

  (* Marks x and y as mutually related. *)
  let relate pair t =
    let x, y = Pair.get pair in
    relate_aux y x (relate_aux x y t)

  let add variable set t =
    if VariableSet.is_empty set
    then remove variable t
    else add variable set t
end

(* -------------------------------------------------------------------------- *)
(*                           Non-relational intervals                         *)
(* -------------------------------------------------------------------------- *)

module Intervals = struct
  module Initial_Values = struct let v = [[]] end
  module Dependencies = struct let l = [ Ast.self ] end

  include Hptmap.Make (Variable) (Ival)
      (Hptmap.Comp_unused) (Initial_Values) (Dependencies)

  let top = empty

  let is_included =
    let cache = Hptmap_sig.PersistentCache "Octagons.Intervals.is_included" in
    let decide_fst _ _ = true in
    let decide_snd _ _ = false in
    let decide_both _ x y = Ival.is_included x y in
    let decide_fast t1 t2 = decide_fast_inclusion t2 t1 in
    binary_predicate cache UniversalPredicate
      ~decide_fast ~decide_fst ~decide_snd ~decide_both

  exception EBottom

  let narrow_exc =
    let cache = Hptmap_sig.NoCache in
    let decide _varinfo x y =
      let ival = Ival.narrow x y in
      if Ival.is_bottom ival then raise EBottom else ival
    in
    join ~cache ~symmetric:true ~idempotent:true ~decide

  let narrow x y = try `Value (narrow_exc x y) with EBottom -> `Bottom

  let join =
    let cache = Hptmap_sig.PersistentCache "Octagons.Intervals.join" in
    let decide _varinfo x y =
      let r = Ival.join x y in
      if Ival.(equal top r) then None else Some r
    in
    inter ~cache ~symmetric:true ~idempotent:true ~decide

  let widen =
    let cache = Hptmap_sig.PersistentCache "Octagons.Intervals.widen" in
    let decide _varinfo x y =
      let r = Arith.widen x y in
      if Ival.(equal top r) then None else Some r
    in
    inter ~cache ~symmetric:false ~idempotent:true ~decide
end

(* -------------------------------------------------------------------------- *)
(*                               Octagon states                               *)
(* -------------------------------------------------------------------------- *)

module Zone = Locations.Zone

module State = struct

  type state =
    { octagons: Octagons.t;       (* The intervals for X±Y. *)
      intervals: Intervals.t;     (* The intervals for the variables X,Y… *)
      relations: Relations.t;     (* The related variables in [octagons]. *)
      modified: Locations.Zone.t; (* The memory zone modified by a function. *)
    }

  include Datatype.Make_with_collections
      (struct
        type t = state
        include Datatype.Serializable_undefined

        let name = "Octagons.Octagons"
        let structural_descr =
          Structural_descr.t_record
            [| Octagons.packed_descr;
               Intervals.packed_descr;
               Relations.packed_descr;
               Zone.packed_descr |]
        let reprs =
          [ { octagons = Octagons.top;
              intervals = Intervals.empty;
              relations = Relations.empty;
              modified = Zone.bottom } ]

        let compare s1 s2 =
          let c = Octagons.compare s1.octagons s2.octagons in
          if c <> 0 then c else
            let c = Intervals.compare s1.intervals s2.intervals in
            if c <> 0 then c else
              Zone.compare s1.modified s2.modified

        let equal = Datatype.from_compare

        let hash t =
          Hashtbl.hash (Octagons.hash t.octagons,
                        Relations.hash t.relations,
                        Zone.hash t.modified)

        let pretty fmt { octagons; intervals } =
          Format.fprintf fmt
            "@[<hov>%a@ %a@]"
            Octagons.pretty octagons Intervals.pretty intervals
      end)

  let top =
    { octagons = Octagons.top;
      intervals = Intervals.top;
      relations = Relations.empty;
      modified = Zone.top; }

  let empty () =
    { octagons = Octagons.top;
      intervals = Intervals.top;
      relations = Relations.empty;
      modified = Zone.bottom; }

  let is_included t1 t2 =
    Octagons.is_included t1.octagons t2.octagons
    && Intervals.is_included t1.intervals t2.intervals
    && Zone.is_included t1.modified t2.modified

  let join t1 t2 =
    let octagons =
      if not infer_intervals
      then Octagons.simple_join t1.octagons t2.octagons
      else
        let decide_empty intervals pair diamond =
          let v1, v2 = Pair.get pair in
          try
            let i1 = Intervals.find v1 intervals
            and i2 = Intervals.find v2 intervals in
            let add = Arith.add v1.vtype i1 i2
            and sub = Arith.sub v1.vtype i1 i2 in
            let diamond = Diamond.join diamond { add; sub } in
            if Diamond.is_top diamond then None else Some diamond
          with Not_found -> None
        in
        let decide_left = decide_empty t2.intervals
        and decide_right = decide_empty t1.intervals in
        Octagons.join ~decide_left ~decide_right t1.octagons t2.octagons
    in
    let relations =
      if infer_intervals
      then Relations.union t1.relations t2.relations
      else Relations.inter t1.relations t2.relations
    in
    { octagons; relations;
      intervals = Intervals.join t1.intervals t2.intervals;
      modified = Zone.join t1.modified t2.modified; }

  let widen _kf _hints t1 t2 =
    let octagons =
      if not infer_intervals
      then Octagons.simple_widen t1.octagons t2.octagons
      else
        let decide_empty b intervals pair diamond =
          let v1, v2 = Pair.get pair in
          try
            let i1 = Intervals.find v1 intervals
            and i2 = Intervals.find v2 intervals in
            let add = Arith.add v1.vtype i1 i2
            and sub = Arith.sub v1.vtype i1 i2 in
            let diamond =
              if b
              then Diamond.widen { add; sub } diamond
              else Diamond.widen diamond { add; sub }
            in
            if Diamond.is_top diamond then None else Some diamond
          with Not_found -> None
        in
        let decide_left = decide_empty false t2.intervals
        and decide_right = decide_empty true t1.intervals in
        Octagons.widen ~decide_left ~decide_right t1.octagons t2.octagons
    in
    let relations =
      if infer_intervals
      then Relations.union t1.relations t2.relations
      else Relations.inter t1.relations t2.relations
    in
    { octagons; relations;
      intervals = Intervals.widen t1.intervals t2.intervals;
      modified = Zone.join t1.modified t2.modified; }

  let narrow t1 t2 =
    Octagons.narrow t1.octagons t2.octagons >>- fun octagons ->
    Intervals.narrow t1.intervals t2.intervals >>- fun intervals ->
    let relations = Relations.union t1.relations t2.relations in
    let modified = Zone.narrow t1.modified t2.modified in
    `Value { octagons; intervals; relations; modified; }

  let add_octagon state octagon =
    if Ival.(equal top octagon.value)
    then `Value state
    else
      Octagons.add_octagon octagon state.octagons >>-: fun octagons ->
      let relations = Relations.relate octagon.variables state.relations in
      { state with octagons; relations }

  let remove state x =
    let intervals = Intervals.remove x state.intervals in
    let state = { state with intervals } in
    try
      let relations = Relations.find x state.relations in
      let remove_one y state =
        try
          let yrelations = Relations.find y state.relations in
          let yrelations = VariableSet.remove x yrelations in
          let relations = Relations.add y yrelations state.relations in
          let pair, _ = Pair.make x y in
          let octagons = Octagons.remove pair state.octagons in
          { state with octagons; relations }
        with Not_found -> state
      in
      let state = VariableSet.fold remove_one relations state in
      let relations = Relations.remove x state.relations in
      { state with relations }
    with Not_found -> state

  let related_octagons state x =
    try
      let related = Relations.find x state.relations in
      let aux y acc =
        let pair, swap = Pair.make x y in
        try
          let diamond = Octagons.find pair state.octagons in
          let diamond =
            if swap
            then Diamond.reverse_variables diamond
            else diamond
          in
          (y, diamond) :: acc
        with Not_found -> acc
      in
      VariableSet.fold aux related []
    with Not_found -> []

  (* x' = ±x - delta *)
  let sub_delta ~inverse state x delta =
    let intervals = Intervals.remove x state.intervals in
    let state = { state with intervals } in
    let x_related = Relations.find x state.relations in
    let aux y state =
      let pair, order = Pair.make x y in
      try
        let diamond = Octagons.find pair state.octagons in
        let diamond =
          if inverse
          then
            let op = if order then Arith.neg else fun x -> x in
            { add = op diamond.sub;
              sub = op diamond.add }
          else diamond
        in
        let typ = x.vtype in
        let op = if order then Arith.sub else Arith.add in
        let add =
          if Ival.(equal top diamond.add)
          then diamond.add
          else Arith.sub typ diamond.add delta
        and sub =
          if Ival.(equal top diamond.sub)
          then diamond.sub
          else op typ diamond.sub delta
        in
        let diamond' = { add; sub } in
        let octagons = Octagons.unsafe_add pair diamond' state.octagons in
        { state with octagons }
      with Not_found -> state
    in
    VariableSet.fold aux x_related state
end

(* -------------------------------------------------------------------------- *)
(*                               Octagon domain                               *)
(* -------------------------------------------------------------------------- *)

module Domain = struct

  include State

  type value = Cvalue.V.t
  type location = Precise_locs.precise_location

  type origin = unit
  let top_value = `Value (Cvalue.V.top, ()), Alarmset.all

  let extract_expr oracle state expr =
    let evaluate_expr expr =
      match fst (oracle expr) with
      | `Bottom -> `Top (* should not happen *)
      | `Value cvalue ->
        try `Value (Cvalue.V.project_ival cvalue)
        with Cvalue.V.Not_based_on_null -> `Top
    in
    let evaluate_octagon octagon = Octagons.evaluate octagon state.octagons in
    let ival =
      Rewriting.evaluate_through_octagons evaluate_expr evaluate_octagon expr
    in
    if Ival.(equal ival top)
    then top_value
    else if Ival.is_bottom ival
    then `Bottom, Alarmset.all
    else `Value (Cvalue.V.inject_ival ival, ()), Alarmset.all

  let extract_lval _oracle _t _lval _typ _loc = top_value

  let backward_location _t _lval _typ loc value = `Value (loc, value)

  let reduce_further state expr value =
    match expr.enode with
    | Lval (Var x, NoOffset) ->
      begin
        try
          let x_ival = Cvalue.V.project_ival value in
          let octagons = State.related_octagons state x in
          let reduce acc (y, octagons) =
            let y_ival1 =
              if Ival.(equal top octagons.add)
              then Ival.top
              else Arith.sub x.vtype octagons.add x_ival
            in
            let y_ival2 =
              if Ival.(equal top octagons.sub)
              then Ival.top
              else Arith.sub x.vtype x_ival octagons.sub
            in
            let y_ival = Ival.narrow y_ival1 y_ival2 in
            if Ival.(equal top y_ival) then acc else
              let y_enode = Lval (Var y, NoOffset) in
              let y_expr = Cil.new_exp ~loc:expr.eloc y_enode in
              let y_cvalue = Cvalue.V.inject_ival y_ival in
              (y_expr, y_cvalue) :: acc
          in
          List.fold_left reduce [] octagons
        with Cvalue.V.Not_based_on_null -> []
      end
    | _ -> []


  let kill_base base state =
    try
      let varinfo = Base.to_varinfo base in
      State.remove state varinfo
    with Base.Not_a_C_variable -> state

  let kill zone state =
    if Locations.Zone.(equal zone top)
    then top
    else
      let modified = Locations.Zone.join state.modified zone in
      let state = Zone.fold_bases kill_base zone state in
      { state with modified }

  module Transfer
      (Valuation: Abstract_domain.Valuation with type value = value
                                             and type loc = location)
  = struct

    (* Evaluation function of expressions to ival, from a [valuation]. *)
    let evaluation_function valuation = fun expr ->
      match Valuation.find valuation expr with
      | `Top -> `Top
      | `Value record ->
        match record.Eval.value.v with
        | `Bottom -> `Top (* TODO: why this keeps happening? *)
        | `Value cvalue ->
          try `Value (Cvalue.V.project_ival cvalue)
          with Cvalue.V.Not_based_on_null -> `Top

    exception EBottom

    let infer_octagons evaluate expr ival state =
      let octagons = Rewriting.make_octagons evaluate expr ival in
      let add_octagon state octagon =
        match State.add_octagon state octagon with
        | `Bottom -> raise EBottom
        | `Value state -> state
      in
      List.fold_left add_octagon state octagons

    let infer_interval expr ival state =
      if not infer_intervals
      then state
      else
        match expr.enode with
        | Lval (Var varinfo, NoOffset)
          when Cil.isArithmeticType varinfo.vtype ->
          let intervals = Intervals.add varinfo ival state.intervals in
          { state with intervals }
        | _ -> state

    let update valuation state =
      let evaluate = evaluation_function valuation in
      let aux expr record state =
        let value = record.Eval.value in
        match record.reductness, value.v, value.initialized, value.escaping with
        | (Created | Reduced), `Value cvalue, true, false ->
          begin
            try
              let ival = Cvalue.V.project_ival cvalue in
              let state = infer_octagons evaluate expr ival state in
              infer_interval expr ival state
            with Cvalue.V.Not_based_on_null -> state
          end
        | _ -> state
      in
      try `Value (Valuation.fold aux valuation state)
      with EBottom -> `Bottom

    let assign_interval varinfo assigned state =
      if not infer_intervals
      then state
      else
        match assigned with
        | Assign v
        | Copy (_, { v = `Value v; initialized = true; escaping = false }) ->
          begin
            try
              let ival = Cvalue.V.project_ival v in
              let intervals = Intervals.add varinfo ival state.intervals in
              { state with intervals }
            with Cvalue.V.Not_based_on_null -> state
          end
        | _ -> state

    let assign_variable varinfo expr assigned valuation state =
      let evaluate = evaluation_function valuation in
      (* TODO: redundant with rewrite_binop below. *)
      let vars = Rewriting.rewrite evaluate expr in
      let equal_varinfo v = Variable.equal varinfo v.Rewriting.varinfo in
      let state =
        try
          let var = List.find equal_varinfo vars in
          let inverse = not var.Rewriting.sign in
          State.sub_delta ~inverse state varinfo var.Rewriting.coeff
        with Not_found -> State.remove state varinfo
      in
      let state = assign_interval varinfo assigned state in
      let enode = Lval (Var varinfo, NoOffset) in
      let left_expr = Cil.new_exp ~loc:expr.eloc enode in
      (* On the assignment X = E; if X-E can be rewritten as ±(X±Y-v),
         then the octagonal constraint [X±Y ∈ v] holds. *)
      let octagons = Rewriting.rewrite_binop evaluate left_expr Sub expr in
      List.fold_left
        (fun acc (_sign, octagon) ->
           acc >>- fun state -> State.add_octagon state octagon)
        (`Value state) octagons

    let assign _kinstr left_value expr assigned valuation state =
      match left_value.lval with
      | Var varinfo, NoOffset when Cil.isArithmeticType varinfo.vtype ->
        assign_variable varinfo expr assigned valuation state
      | _ ->
        let written_loc = Precise_locs.imprecise_location left_value.lloc in
        let written_zone =
          Locations.(enumerate_valid_bits Write written_loc)
        in
        let state = kill written_zone state in
        `Value state

    let assume _stmt _exp _bool = update

    let start_call _stmt _call _valuation _state = `Value (empty ())

    let finalize_call _stmt _call ~pre ~post =
      let written_zone = post.modified in
      `Value (kill written_zone pre)

    let show_expr _valuation _state _fmt _expr = ()
  end

  let logic_assign _logic_assign location ~pre:_ state =
    let loc = Precise_locs.imprecise_location location in
    let zone = Locations.(enumerate_valid_bits Write loc) in
    kill zone state

  let evaluate_predicate _env _state _pred = Alarmset.Unknown
  let reduce_by_predicate _env state _pred _positive = `Value state

  let enter_scope _kf _varinfos state = state
  let leave_scope _kf varinfos state =
    List.fold_left State.remove state varinfos

  let enter_loop _stmt state = state
  let incr_loop_counter _stmt state = state
  let leave_loop _stmt state = state

  let introduce_globals _varinfos state = state
  let initialize_variable _lval _location ~initialized:_ _value state = state
  let initialize_variable_using_type _kind _varinfo state = state

  let relate _kf _bases _state = Base.SetLattice.empty
  let filter _kf _kind _bases state = state
  let reuse _kf _bases ~current_input:_ ~previous_output = previous_output

  let name = "Octagon domain"
  let log_category = Value_parameters.register_category "d-octagons"

  let storage () = true
end

include Domain_builder.Complete (Domain)
