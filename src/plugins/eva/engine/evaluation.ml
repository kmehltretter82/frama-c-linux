(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(* Evaluation of expressions to values. *)

open Cil_types
open Eval

(* The forward evaluation of an expression [e] gives a value to each subterm
   of [e], from its variables to the root expression [e]. It also computes the
   set of alarms which may occur in the evaluation of each subterm.
   All these intermediate results of an evaluation are stored in a cache, whose
   type is described in eval.mli. The cache is the complete result of the
   evaluation. *)

(* The forward evaluation of an expression relies on queries of the abstract
   domain, which must be able to assign a value to some expression (see
   abstract_domain.mli for more details).
   An oracle for the value of expressions is also given to the domain,
   which may use it to build its answer. This oracle is the main forward
   evaluation function itself, so the domain may initiate the evaluation
   of some new expressions.
   To avoid loops in the use of the oracle:
   - before any computation or an expression [e], Value.top is stored
     in the cache; this dummy value will be erased at the end of the
     computation, but in the meantime, any evaluation of [e] (by the oracle)
     returns top immediately.
   - fuel is used to limit the depth of the use of the oracle. The fuel level is
     decremented at each use of the oracle up to zero, where the oracle returns
     top.
     The fuel level with which an expression has been evaluated is stored in the
     cache. The recomputation of an expression may be performed with a higher
     fuel than before, if needed. *)

(* Reductions may happen in the forward evaluation when:
   – a domain returns a value more precise than the one internally computed;
   – alarms are emitted by an operation on values. In particular, locations
     are reduced to their valid part for a read or write operation.
   These reductions are propagated to the sub-expressions by a backward
   evaluation, after the forward evaluation has finished.
   The backward evaluation also propagates the reduction stemming from an if
   statement, where the condition may be reduced to zero or non-zero. *)

(* An expression is deemed volatile if it contains an access to a volatile
   location. The forward evaluation computes this syntactically, by checking
   for volatile qualifiers on sub-lvalues and intermediate types. A 'volatile'
   flag is propagated through the expression. This flag prevents the update of
   the value computed by the initial forward evaluation. *)

(* When a backward reduction has been successfully performed, the domain may
   initiate new reductions, via the reduce_further function.
   A fuel level is used in the same way as for the forward evaluation to
   avoid reduction loops. *)


(* The fuel level with which an expression has been evaluated. *)
type fuel =
  | Loop
  (* No evaluation at all: the value in the cache is a dummy value, set
     to avoid a loop in the use of the oracle. *)
  | Finite of int
  (* An evaluation with a finite level of fuel, which has been consumed. *)
  | Infty
  (* The evaluation never used all its fuel. *)

let less_fuel_than n = function
  | Loop     -> true
  | Finite f -> f >= n
  | Infty    -> true

type reduction_kind = | Neither | Forward | Backward

let update_reduction reduction b = match reduction with
  | Neither -> if b then Neither else Forward
  | x -> x

(* Some information about a forward evaluation. *)
type forward_report = {
  fuel: fuel;                (* The fuel used for the evaluation. *)
  reduction: reduction_kind; (* Whether a reduction has occur, which may be
                                propagated to the sub-terms. *)
  volatile: bool;         (* If true, the expression may contain an access
                             to a volatile location, and thus cannot be safely
                             reduced. *)
}

(* Parameters of the evaluation of the location of a left value. *)
type loc_report = {
  for_writing: bool;
  with_reduction: bool;
}

(* If a value is cached by an external source, we assume that it was
   computed with infty fuel, that possible reduction have been
   propagated backward, and that the expression cannot be volatile. *)
let extern_report = { fuel = Infty; reduction = Neither; volatile = false }

let no_fuel = -1
let root_fuel () = Parameters.OracleDepth.get ()
let backward_fuel () = Parameters.ReductionDepth.get ()

let already_precise_loc_report ~for_writing ~reduction loc_report =
  (not for_writing || loc_report.for_writing)
  && (not reduction || loc_report.with_reduction)


let rec may_be_reduced_offset = function
  | NoOffset -> false
  | Field (_, offset) -> may_be_reduced_offset offset
  | Index _ -> true

let may_be_reduced_lval (host, offset) = match host with
  | Var _ -> may_be_reduced_offset offset
  | Mem _ -> true

let warn_pointer_comparison typ =
  match Parameters.WarnPointerComparison.get () with
  | "none" -> false
  | "all" -> true
  | "pointer" -> Cil.isPointerType (Cil.unrollType typ)
  | _ -> assert false

let propagate_all_pointer_comparison typ =
  not (Cil.isPointerType typ)
  || Parameters.UndefinedPointerComparisonPropagateAll.get ()

let comparison_kind = function
  | Eq | Ne -> Some Abstract_value.Equality
  | Le | Lt
  | Ge | Gt -> Some Abstract_value.Relation
  | _ -> None

let signed_ikind = function
  | IBool                   -> IBool
  | IChar | ISChar | IUChar -> ISChar
  | IInt | IUInt            -> IInt
  | IShort | IUShort        -> IShort
  | ILong | IULong          -> ILong
  | ILongLong | IULongLong  -> ILongLong

let rec signed_counterpart typ =
  match Cil.unrollType typ with
  | TInt (ik, attrs) -> TInt (signed_ikind ik, attrs)
  | TEnum ({ekind = ik} as info, attrs) ->
    let info = { info with ekind = signed_ikind ik} in
    TEnum (info, attrs)
  | TPtr _ -> signed_counterpart Cil.(theMachine.upointType)
  | _ -> assert false

module MemoDowncastConvertedAlarm =
  State_builder.Hashtbl
    (Cil_datatype.Exp.Hashtbl)
    (Cil_datatype.Exp)
    (struct
      let name = "Value.Evaluation.MemoDowncastConvertedAlarm"
      let size = 16
      let dependencies = [ Ast.self ]
    end)
let exp_alarm_signed_converted_downcast =
  MemoDowncastConvertedAlarm.memo
    (fun exp ->
       let src_typ = Cil.typeOf exp in
       let signed_typ = signed_counterpart src_typ in
       let signed_exp = Cil.new_exp ~loc:exp.eloc (CastE (signed_typ, exp)) in
       signed_exp)

let return t = `Value t, Alarmset.none

(* Intersects [alarms] with the only possible alarms from the dereference of
   the left-value [lval] of type [typ].
   Useful if the abstract domain returns a non-closed AllBut alarmset for
   some lvalues. *)
let close_dereference_alarms lval alarms =
  let init_alarm = Alarms.Uninitialized lval
  and escap_alarm = Alarms.Dangling lval in
  let init_status = Alarmset.find init_alarm alarms
  and escap_status = Alarmset.find escap_alarm alarms in
  let closed_alarms = Alarmset.set init_alarm init_status Alarmset.none in
  let closed_alarms = Alarmset.set escap_alarm escap_status closed_alarms in
  closed_alarms

let define_value value =
  { v = `Value value; initialized = true; escaping = false }

(* [record] and [alarms] must be the value and the alarms resulting from the
   evaluation of the lvalue [lval].
   This function removes the alarms about the initialization and the
   escaping of [lval], and sets accordingly the initialized and escaping flags
   of the computed value. *)
let indeterminate_copy lval result alarms =
  let init_alarm = Alarms.Uninitialized lval
  and escap_alarm = Alarms.Dangling lval in
  let initialized = Alarmset.find init_alarm alarms = Alarmset.True
  and escaping = not (Alarmset.find escap_alarm alarms = Alarmset.True) in
  let alarms =
    if not (initialized)
    then Alarmset.set init_alarm Alarmset.True alarms
    else alarms
  in
  let alarms =
    if escaping
    then Alarmset.set escap_alarm Alarmset.True alarms
    else alarms
  in
  let reductness = Unreduced in
  let v, origin = match result with
    | `Bottom -> `Bottom, None
    | `Value (v, origin) -> `Value v, origin
  in
  let value = { v; initialized; escaping } in
  let record = { value; origin; reductness; val_alarms = alarms} in
  record, alarms


module type Value = sig
  include Abstract.Value.External
  val reduce : t -> t
end

module type Queries = sig
  include Abstract_domain.Queries
  include Datatype.S with type t = state
end

module Make
    (Context : Abstract_context.S)
    (Value : Value with type context = Context.t)
    (Loc : Abstract_location.S with type value = Value.t)
    (Domain : Queries with type context = Context.t
                       and type value = Value.t
                       and type location = Loc.location)
= struct

  type state = Domain.state
  type context = Context.t
  type value = Value.t
  type origin = Domain.origin
  type loc = Loc.location

  module ECache = Cil_datatype.ExpStructEq.Map
  module LCache = Cil_datatype.LvalStructEq.Map

  (* Imperative cache for the evaluation:
     all intermediate results of an evaluation are cached here.
     See [eval.mli] for more details. *)
  module Cache = struct
    type value = Value.t
    type origin = Domain.origin
    type loc = Loc.location

    (* For expression, the forward_report about the evaluation is also stored. *)
    type t =
      ((value, origin) record_val * forward_report) ECache.t
      * (loc record_loc * (forward_report * loc_report)) LCache.t

    (* Interface of Context.Valuation *)
    let empty : t = ECache.empty, LCache.empty
    let find (cache:t) exp =
      try `Value (fst (ECache.find exp (fst cache)))
      with Not_found -> `Top
    let add (cache:t) exp record =
      let s, t = cache in ECache.add exp (record, extern_report) s, t
    let fold f (cache:t) acc =
      ECache.fold (fun e (r, _) acc -> f e r acc) (fst cache) acc

    (* Functions used by the evaluator, with the boolean for backward
       reduction. *)
    let find' (cache:t) exp = ECache.find exp (fst cache)
    let add' (cache:t) exp record =
      let s, t = cache in ECache.add exp record s, t

    (* Locations of lvalue. *)
    let find_loc (cache:t) lval =
      try `Value (fst (LCache.find lval (snd cache)))
      with Not_found -> `Top

    (* Locations of lvalue. *)
    let find_loc' (cache:t) lval =
      try `Value (LCache.find lval (snd cache))
      with Not_found -> `Top
    let add_loc' (cache:t) lval record =
      let s, t = cache in s, LCache.add lval record t

    let remove (s, t) expr = ECache.remove expr s, t
    let remove_loc (s, t) lval = s, LCache.remove lval t
  end

  (* Imperative cache for the evaluator. A reference is mandatory here, because
     the cache must be also filled by the evaluations initiated by a domain
     through the oracle, but should not leak in the domain queries signature. *)
  let cache = ref Cache.empty

  (* Was the fuel entirely consumed? *)
  let fuel_consumed = ref false

  let bottom_entry val_alarms =
    let value = { v = `Bottom; initialized = true; escaping = false } in
    let record = { value; origin = None; reductness = Dull; val_alarms } in
    let report = { fuel = Infty; reduction = Neither; volatile = false} in
    record, report

  let top_entry =
    let v = `Value Value.top in
    let value = { v; initialized = false; escaping = true } in
    let val_alarms = Alarmset.all in
    let record = { value; origin = None; reductness = Dull; val_alarms } in
    let report = { fuel = Loop; reduction = Neither; volatile = false } in
    record, report

  (* Updates the abstractions stored in the cache for the expression [expr]
     with the given record, report and value. [kind] is the type of the
     reduction (forward or backward). *)
  let reduce_expr_recording kind expr (record, report) value =
    (* Avoids reduction of volatile expressions. *)
    if report.volatile then ()
    else
      let red = record.reductness in
      let reductness =
        if red = Unreduced && kind <> Neither then Reduced else red
      in
      (* TODO: allow to reduce initialized and escaping flags? *)
      let record = { record with value = define_value value; reductness } in
      let report = { report with reduction = kind } in
      cache := Cache.add' !cache expr (record, report)

  (* Updates the abstractions stored in the cache for the expression [expr]
     with the value [value]. [kind] is the type of the reduction.*)
  let reduce_expr_value kind expr value =
    let record, report = Cache.find' !cache expr in
    reduce_expr_recording kind expr (record, report) value

  let reduce_value record =
    let v = record.value.v >>-: Value.reduce in
    { record with value = {record.value with v = v} }

  (* ------------------------------------------------------------------------
                    Forward Operations, Alarms and Reductions
     ------------------------------------------------------------------------ *)

  (* Handles the result of an [assume] function from value abstractions (see
     abstract_values.mli for more details), applied to the initial [value].
     If the value could have been reduced, [reduce] is applied on the new value.
     If the status is not true, [alarm] is used to create the alarm. *)
  let process_truth ~reduce ~alarm value =
    let build_alarm status = Alarmset.singleton ~status (alarm ()) in
    function
    | `Unreachable   -> `Bottom, Alarmset.none
    | `False         -> `Bottom, build_alarm Alarmset.False
    | `Unknown v     -> reduce v; `Value v, build_alarm Alarmset.Unknown
    | `TrueReduced v -> reduce v; `Value v, Alarmset.none
    | `True          -> `Value value, Alarmset.none

  (* Does not register the possible reduction, as the initial [value] has not
     been saved yet. *)
  let interpret_truth ~alarm value truth =
    let reduce _ = () in
    process_truth ~reduce ~alarm value truth

  let reduce_argument (e, v) new_value =
    if not (Value.equal v new_value) then reduce_expr_value Forward e new_value

  (* Registers the new value if it has been reduced. *)
  let reduce_by_truth ~alarm (expr, value) truth =
    let reduce = reduce_argument (expr, value) in
    process_truth ~reduce ~alarm value truth

  (* Processes the results of assume_comparable, that affects both arguments of
     the comparison. *)
  let reduce_by_double_truth ~alarm (e1, v1) (e2, v2) truth =
    let reduce (new_value1, new_value2) =
      Option.iter (fun e1 -> reduce_argument (e1, v1) new_value1) e1;
      reduce_argument (e2, v2) new_value2;
    in
    process_truth ~reduce ~alarm (v1, v2) truth

  let is_true = function
    | `True | `TrueReduced _ -> true
    | _ -> false

  let may_overflow = function
    | Shiftlt | Mult | MinusPP | MinusPI | PlusPI
    | PlusA | Div | Mod | MinusA -> true
    | _ -> false

  let truncate_bound overflow_kind bound bound_kind expr value =
    let alarm () = Alarms.Overflow (overflow_kind, expr, bound, bound_kind) in
    let bound = Abstract_value.Int bound in
    let truth = Value.assume_bounded bound_kind bound value in
    interpret_truth ~alarm value truth

  let truncate_lower_bound overflow_kind expr range value =
    let min_bound = Eval_typ.range_lower_bound range in
    let bound_kind = Alarms.Lower_bound in
    truncate_bound overflow_kind min_bound bound_kind expr value

  let truncate_upper_bound overflow_kind expr range value =
    let max_bound = Eval_typ.range_upper_bound range in
    let bound_kind = Alarms.Upper_bound in
    truncate_bound overflow_kind max_bound bound_kind expr value

  let truncate_integer overflow_kind expr range value =
    truncate_lower_bound overflow_kind expr range value >>= fun value ->
    truncate_upper_bound overflow_kind expr range value

  let handle_integer_overflow context expr range value =
    let signed = range.Eval_typ.i_signed in
    let signed_overflow = signed && Kernel.SignedOverflow.get () in
    let unsigned_overflow = not signed && Kernel.UnsignedOverflow.get () in
    if signed_overflow || unsigned_overflow then
      let overflow_kind = if signed then Alarms.Signed else Alarms.Unsigned in
      truncate_integer overflow_kind expr range value
    else
      let v = Value.rewrap_integer context range value in
      if range.Eval_typ.i_signed && not (Value.equal value v) then
        Self.warning ~wkey:Self.wkey_signed_overflow
          ~current:true ~once:true "2's complement assumed for overflow" ;
      return v

  let restrict_float ?(reduce=false) ~assume_finite expr fkind value =
    let truth = Value.assume_not_nan ~assume_finite fkind value in
    let alarm () =
      if assume_finite
      then Alarms.Is_nan_or_infinite (expr, fkind)
      else Alarms.Is_nan (expr, fkind)
    in
    if reduce
    then reduce_by_truth ~alarm (expr, value) truth
    else interpret_truth ~alarm value truth

  let remove_special_float expr fk value =
    match Kernel.SpecialFloat.get () with
    | "none"       -> return value
    | "nan"        -> restrict_float ~assume_finite:false expr fk value
    | "non-finite" -> restrict_float ~assume_finite:true expr fk value
    | _            -> assert false

  let assume_pointer context expr value =
    let open Evaluated.Operators in
    let+ value =
      if Kernel.InvalidPointer.get () then
        let truth = Value.assume_pointer value in
        let alarm () = Alarms.Invalid_pointer expr in
        interpret_truth ~alarm value truth
      else return value
    in
    (* Rewrap absolute addresses of pointer values, seen as unsigned
       integers, to ensure a consistent representation of pointers. *)
    let range = Eval_typ.pointer_range () in
    Value.rewrap_integer context range value

  let handle_overflow ~may_overflow context expr typ value =
    match Eval_typ.classify_as_scalar typ with
    | Some (Eval_typ.TSInt range) ->
      (* If the operation cannot overflow, truncates the abstract value to the
         range of the type (without emitting alarms). This can regain some
         precision when the abstract operator was too imprecise.
         Otherwise, truncates or rewraps the abstract value according to
         the parameters of the analysis. *)
      if not may_overflow
      then fst (truncate_integer Alarms.Signed expr range value), Alarmset.none
      else handle_integer_overflow context expr range value
    | Some (Eval_typ.TSFloat fk) -> remove_special_float expr fk value
    | Some (Eval_typ.TSPtr _) -> assume_pointer context expr value
    | None -> return value

  (* Assumes that [res] is a valid result for the lvalue [lval] of type [typ].
     Removes NaN and infinite floats and trap representations of bool values. *)
  let assume_valid_value context typ lval res =
    let open Evaluated.Operators in
    let* value, origin = res in
    match typ with
    | TFloat (fkind, _) ->
      let expr = Eva_utils.lval_to_exp lval in
      let+ new_value = remove_special_float expr fkind value in
      new_value, origin
    | TInt (IBool, _) when Kernel.InvalidBool.get () ->
      let one = Abstract_value.Int Integer.one in
      let truth = Value.assume_bounded Alarms.Upper_bound one value in
      let alarm () = Alarms.Invalid_bool lval in
      let+ new_value = interpret_truth ~alarm value truth in
      new_value, origin
    | TPtr _ ->
      let expr = Eva_utils.lval_to_exp lval in
      let+ new_value = assume_pointer context expr value in
      new_value, origin
    | _ -> res

  (* Reduce the rhs argument of a shift so that it fits inside [size] bits. *)
  let reduce_shift_rhs typ expr value =
    let open Evaluated.Operators in
    let size = Cil.bitsSizeOf typ in
    let size_int = Abstract_value.Int (Integer.of_int (size - 1)) in
    let zero_int = Abstract_value.Int Integer.zero in
    let alarm () = Alarms.Invalid_shift (expr, Some size) in
    let truth = Value.assume_bounded Alarms.Lower_bound zero_int value in
    let* value = reduce_by_truth ~alarm (expr, value) truth in
    let truth = Value.assume_bounded Alarms.Upper_bound size_int value in
    reduce_by_truth ~alarm (expr, value) truth

  (* Reduces the right argument of a shift, and if [warn_negative] is true,
     also reduces its left argument to a positive value. *)
  let reduce_shift ~warn_negative typ (e1, v1) (e2, v2) =
    let open Evaluated.Operators in
    let* v2 = reduce_shift_rhs typ e2 v2 in
    if warn_negative && Bit_utils.is_signed_int_enum_pointer typ then
      (* Cannot shift a negative value *)
      let zero_int = Abstract_value.Int Integer.zero in
      let alarm () = Alarms.Invalid_shift (e1, None) in
      let truth = Value.assume_bounded Alarms.Lower_bound zero_int v1 in
      let+ v1 = reduce_by_truth ~alarm (e1, v1) truth in
      v1, v2
    else return (v1, v2)

  (* Emits alarms for an index out of bound, and reduces its value. *)
  let assume_valid_index ~size ~size_expr ~index_expr value =
    let open Evaluated.Operators in
    let size_int = Abstract_value.Int (Integer.pred size) in
    let zero_int = Abstract_value.Int Integer.zero in
    let alarm () = Alarms.Index_out_of_bound (index_expr, None) in
    let truth = Value.assume_bounded Alarms.Lower_bound zero_int value in
    let* value = reduce_by_truth ~alarm (index_expr, value) truth in
    let alarm () = Alarms.Index_out_of_bound (index_expr, Some size_expr) in
    let truth = Value.assume_bounded Alarms.Upper_bound size_int value in
    reduce_by_truth ~alarm (index_expr, value) truth

  let assume_valid_binop typ (e1, v1 as arg1) op (e2, v2 as arg2) =
    let open Evaluated.Operators in
    if Cil.isIntegralType typ then
      match op with
      | Div | Mod ->
        let truth = Value.assume_non_zero v2 in
        let alarm () = Alarms.Division_by_zero e2 in
        let+ v2 = reduce_by_truth ~alarm arg2 truth in
        v1, v2
      | Shiftrt ->
        let warn_negative = Kernel.RightShiftNegative.get () in
        reduce_shift ~warn_negative typ arg1 arg2
      | Shiftlt ->
        let warn_negative = Kernel.LeftShiftNegative.get () in
        reduce_shift ~warn_negative typ arg1 arg2
      | MinusPP when Parameters.WarnPointerSubstraction.get () ->
        let kind = Abstract_value.Subtraction in
        let truth = Value.assume_comparable kind v1 v2 in
        let alarm () = Alarms.Differing_blocks (e1, e2) in
        let arg1 = Some e1, v1 in
        reduce_by_double_truth ~alarm arg1 arg2 truth
      | _ -> return (v1, v2)
    else return (v1, v2)

  (* Pretty prints the result of a comparison independently of the value
     abstractions used. *)
  let pretty_zero_or_one fmt v =
    let print = Format.pp_print_string fmt in
    if Value.(equal v zero) then print "{0}"
    else if Value.(equal v one) then print "{1}"
    else print "{0; 1}"

  let forward_comparison ~compute typ kind (e1, v1) (e2, v2) =
    let truth = Value.assume_comparable kind v1 v2 in
    let alarm () = Alarms.Pointer_comparison (e1, e2) in
    let propagate_all = propagate_all_pointer_comparison typ in
    let args, alarms =
      if warn_pointer_comparison typ then
        if propagate_all
        then `Value (v1, v2), snd (interpret_truth ~alarm (v1, v2) truth)
        else reduce_by_double_truth ~alarm (e1, v1) (e2, v2) truth
      else `Value (v1, v2), Alarmset.none
    in
    let result = let* v1, v2 = args in compute v1 v2 in
    let value =
      if is_true truth || not propagate_all
      then result
      else
        let zero_or_one = Value.(join zero one) in
        if Cil.isPointerType typ then
          Self.result
            ~current:true ~once:true
            ~dkey:Self.dkey_pointer_comparison
            "evaluating condition to {0; 1} instead of %a because of UPCPA"
            (Bottom.pretty pretty_zero_or_one) result;
        `Value zero_or_one
    in
    value, alarms

  let forward_binop context typ (e1, v1 as arg1) op arg2 =
    let open Evaluated.Operators in
    let typ_e1 = Cil.unrollType (Cil.typeOf e1) in
    match comparison_kind op with
    | Some kind ->
      let compute v1 v2 = Value.forward_binop context typ_e1 op v1 v2 in
      (* Detect zero expressions created by the evaluator *)
      let e1 = if Eva_utils.is_value_zero e1 then None else Some e1 in
      forward_comparison ~compute typ_e1 kind (e1, v1) arg2
    | None ->
      let& v1, v2 = assume_valid_binop typ arg1 op arg2 in
      Value.forward_binop context typ_e1 op v1 v2

  let forward_unop context unop (e, v as arg) =
    let typ = Cil.unrollType (Cil.typeOf e) in
    if unop = LNot then
      let kind = Abstract_value.Equality in
      let compute _ v = Value.forward_unop context typ unop v in
      forward_comparison ~compute typ kind (None, Value.zero) arg
    else Value.forward_unop context typ unop v, Alarmset.none

  (* ------------------------------------------------------------------------
                                    Casts
     ------------------------------------------------------------------------ *)

  type integer_range = Eval_typ.integer_range = { i_bits: int; i_signed: bool }

  let cast_integer overflow_kind expr ~src ~dst value =
    let open Evaluated.Operators in
    let* value =
      if Eval_typ.(Integer.lt (range_lower_bound src) (range_lower_bound dst))
      then truncate_lower_bound overflow_kind expr dst value
      else return value
    in
    if Eval_typ.(Integer.gt (range_upper_bound src) (range_upper_bound dst))
    then truncate_upper_bound overflow_kind expr dst value
    else return value

  (* Relaxed semantics for downcasts into signed types:
     first converts the value to the signed counterpart of the source type, and
     then downcasts it into the signed destination type. Emits only alarms for
     the second cast. *)
  let relaxed_signed_downcast context expr ~src ~dst value =
    let expr, src, value =
      if not src.i_signed then
        let signed_src = { src with i_signed = true } in
        let signed_v = Value.rewrap_integer context signed_src value in
        let signed_exp = exp_alarm_signed_converted_downcast expr in
        signed_exp, signed_src, signed_v
      else expr, src, value
    in
    cast_integer Alarms.Signed_downcast expr ~src ~dst value

  let cast_int_to_int context expr ~ptr ~src ~dst value =
    (* Regain some precision in case a transfer function was imprecise.
       This should probably be done in the transfer function, though. *)
    let value =
      if Value.(equal top_int value)
      then Value.rewrap_integer context src value
      else value
    in
    if Eval_typ.range_inclusion src dst
    then return value (* Upcast, nothing to check. *)
    else
      let overflow_kind, warn =
        if ptr
        then Alarms.Pointer_downcast, Kernel.PointerDowncast.get
        else if dst.i_signed
        then Alarms.Signed_downcast, Kernel.SignedDowncast.get
        else Alarms.Unsigned_downcast, Kernel.UnsignedDowncast.get
      in
      if warn ()
      then cast_integer overflow_kind expr ~src ~dst value
      else if dst.i_signed && Parameters.WarnSignedConvertedDowncast.get ()
      then relaxed_signed_downcast context expr ~src ~dst value
      else return (Value.rewrap_integer context dst value)

  (* Re-export type here *)
  type scalar_typ = Eval_typ.scalar_typ =
    | TSInt of integer_range
    | TSPtr of integer_range
    | TSFloat of fkind

  let round fkind f = match fkind with
    | FFloat -> Floating_point.round_to_single_precision_float f
    | FDouble | FLongDouble -> f

  let truncate_float_bound fkind bound bound_kind expr value =
    let next_int, prev_float, is_beyond = match bound_kind with
      | Alarms.Upper_bound -> Integer.succ, Fval.F.prev_float, Integer.ge
      | Alarms.Lower_bound -> Integer.pred, Fval.F.next_float, Integer.le
    in
    let ibound = next_int bound in
    let fbound = round fkind (Integer.to_float ibound) in
    let float_bound =
      if is_beyond (Integer.of_float fbound) ibound
      then prev_float (Fval.kind fkind) fbound
      else fbound
    in
    let alarm () = Alarms.Float_to_int (expr, bound, bound_kind) in
    let bound = Abstract_value.Float (float_bound, fkind) in
    let truth = Value.assume_bounded bound_kind bound value in
    reduce_by_truth ~alarm (expr, value) truth

  let truncate_float fkind dst_range expr value =
    let open Evaluated.Operators in
    let max_bound = Eval_typ.range_upper_bound dst_range in
    let bound_kind = Alarms.Upper_bound in
    let* value = truncate_float_bound fkind max_bound bound_kind expr value in
    let min_bound = Eval_typ.range_lower_bound dst_range in
    let bound_kind = Alarms.Lower_bound in
    truncate_float_bound fkind min_bound bound_kind expr value

  let forward_cast context ~dst expr value =
    let open Evaluated.Operators in
    let src = Cil.typeOf expr in
    match Eval_typ.(classify_as_scalar src, classify_as_scalar dst) with
    | None, _ | _, None -> return value (* Unclear whether this happens. *)
    | Some src_type, Some dst_type ->
      let& value =
        match src_type, dst_type with
        | TSPtr src, TSInt dst ->
          cast_int_to_int context ~ptr:true ~src ~dst expr value
        | TSInt src, (TSInt dst | TSPtr dst) ->
          cast_int_to_int context ~ptr:false ~src ~dst expr value
        | TSFloat src, (TSInt dst | TSPtr dst)  ->
          let reduce = true and assume_finite = true in
          let* value = restrict_float ~reduce ~assume_finite expr src value in
          truncate_float src dst expr value
        | (TSInt _ | TSPtr _), TSFloat _ ->
          (* Cannot overflow with 32 bits float. *)
          return value
        | TSFloat _, TSFloat _ | TSPtr _, TSPtr _ -> return value
      in
      Value.forward_cast context ~src_type ~dst_type value

  (* ------------------------------------------------------------------------
                               Forward Evaluation
     ------------------------------------------------------------------------ *)

  (* The forward evaluation environment: arguments that must be passed through
     the mutually recursive evaluation functions without being modified. *)
  type recursive_environment =
    { (* The abstract domain state in which the evaluation takes place. *)
      state: Domain.t;
      (* The abstract context in which the evaluation takes place. *)
      context: Context.t Abstract_value.enriched;
      (* Is the expression currently processed the "root" expression being
         evaluated, or is it a sub-expression? Useful for domain queries. *)
      root: bool;
      (* Maximum number of subdivisions. See {!Subdivided_evaluation} for
         more details. *)
      subdivision: int;
      (* Is the current evaluation subdivided? *)
      subdivided: bool;
      (* The remaining fuel: maximum number of nested oracle uses, decremented
         at each call to the oracle. *)
      remaining_fuel: int;
      (* The oracle which can be used by abstract domains to get a value for
         some expressions. *)
      oracle: recursive_environment -> exp -> Value.t evaluated;
    }

  (* Builds the query to the domain from the environment. *)
  let make_domain_query query env =
    let { state; oracle; root; subdivision; subdivided; } = env in
    let oracle = oracle env in
    let domain_env = Abstract_domain.{ root; subdivision; subdivided; } in
    query ~oracle domain_env state

  (* Returns the cached value and alarms for the evaluation if it exists;
     call [coop_forward_eval] and caches its result otherwise.
     Also returns a boolean indicating whether the expression is volatile.  *)
  let rec root_forward_eval env expr =
    (* Search in the cache for the result of a previous computation. *)
    try
      let record, report = Cache.find' !cache expr in
      (* If the record was computed with more fuel than [fuel], return it. *)
      if report.fuel = Loop then fuel_consumed := true;
      if less_fuel_than env.remaining_fuel report.fuel
      then (let+ v = record.value.v in v, report.volatile), record.val_alarms
      else raise Not_found
    (* If no result found, evaluate the expression. *)
    with Not_found ->
      let previous_fuel_consumed = !fuel_consumed in
      (* Fuel not consumed for this new evaluation. *)
      fuel_consumed := false;
      (* Fill the cache to avoid loops in the use of the oracle. *)
      cache := Cache.add' !cache expr top_entry;
      (* Evaluation of [expr]. *)
      let result, alarms = coop_forward_eval env expr in
      let value =
        let* record, reduction, volatile = result in
        (* Put the alarms in the record. *)
        let record = { record with val_alarms = alarms } in
        (* Inter-reduction of the value (in case of a reduced product). *)
        let record = reduce_value record in
        (* Cache the computed result with an appropriate report. *)
        let fuel = env.remaining_fuel in
        let fuel = if !fuel_consumed then Finite fuel else Infty in
        let report = {fuel; reduction; volatile} in
        cache := Cache.add' !cache expr (record, report);
        let+ v = record.value.v in v, volatile
      in
      (* Reset the flag fuel_consumed. *)
      fuel_consumed := previous_fuel_consumed || !fuel_consumed;
      value, alarms

  and forward_eval env expr = root_forward_eval env expr >>=: fst

  (* The functions below returns, along with the computed value (when it is not
     bottom):
     - the state of reduction of the current expression: Neither if it has
       not been reduced, Forward otherwise.
     - a boolean indicating whether the expression is volatile. *)

  (* Asks the abstract domain for abstractions (value and alarms) of [expr],
     and performs the narrowing with the abstractions computed by
     [internal_forward_eval].  *)
  and coop_forward_eval env expr =
    match expr.enode with
    | Lval lval -> eval_lval env lval
    | BinOp _ | UnOp _ | CastE _ ->
      let domain_query = make_domain_query Domain.extract_expr env in
      let env = { env with root = false } in
      let intern_value, alarms = internal_forward_eval env expr in
      let domain_value, alarms' = domain_query expr in
      (* Intersection of alarms, as each sets of alarms are correct
         and "complete" for the evaluation of [expr]. *)
      begin match Alarmset.inter alarms alarms' with
        | `Inconsistent ->
          (* May happen for a product of states with no concretization. Such
             cases are reported to the user by transfer_stmt. *)
          `Bottom, Alarmset.none
        | `Value alarms ->
          let v =
            let* intern_value, reduction, volatile = intern_value in
            let* domain_value, origin = domain_value in
            let+ result = Value.narrow intern_value domain_value in
            let reductness =
              if Value.equal domain_value result then Unreduced
              else if Value.(equal domain_value top) then Created else Reduced
            in
            let reduction =
              update_reduction reduction (Value.equal intern_value result)
            and value = define_value result in
            (* The proper alarms will be set in the record by forward_eval. *)
            {value; origin; reductness; val_alarms = Alarmset.all},
            reduction, volatile
          in
          v, alarms
      end
    | _ ->
      let open Evaluated.Operators in
      let+ value, reduction, volatile = internal_forward_eval env expr in
      let value = define_value value and origin = None in
      let reductness = Dull and val_alarms = Alarmset.all in
      { value; origin; reductness; val_alarms }, reduction, volatile

  (* Recursive descent in the sub-expressions. *)
  and internal_forward_eval env expr =
    let open Evaluated.Operators in
    let compute_reduction (v, a) volatile =
      let+ v = (v, a) in
      let reduction = if Alarmset.is_empty a then Neither else Forward in
      v, reduction, volatile
    in
    match expr.enode with
    | Const constant -> internal_forward_eval_constant env expr constant
    | Lval _lval -> assert false

    | AddrOf v | StartOf v ->
      let* loc, _, _ = lval_to_loc env ~for_writing:false ~reduction:false v in
      let* value = Loc.to_value loc, Alarmset.none in
      let v = assume_pointer env.context expr value in
      compute_reduction v false

    | UnOp (op, e, typ) ->
      let* v, volatile = root_forward_eval env e in
      let* v = forward_unop env.context op (e, v) in
      let may_overflow = op = Neg in
      let v = handle_overflow ~may_overflow env.context expr typ v in
      compute_reduction v volatile

    | BinOp (op, e1, e2, typ) ->
      let* v1, volatile1 = root_forward_eval env e1 in
      let* v2, volatile2 = root_forward_eval env e2 in
      let* v = forward_binop env.context typ (e1, v1) op (e2, v2) in
      let may_overflow = may_overflow op in
      let v = handle_overflow ~may_overflow env.context expr typ v in
      compute_reduction v (volatile1 || volatile2)

    | CastE (dst, e) ->
      let* value, volatile = root_forward_eval env e in
      let v = forward_cast env.context ~dst e value in
      let v = match Cil.unrollType dst with
        | TFloat (fkind, _) -> let* v in remove_special_float expr fkind v
        | TPtr _ -> let* v in assume_pointer env.context expr v
        | _ -> v
      in
      compute_reduction v volatile

    | SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _ | AlignOfE _ ->
      match Cil.constFoldToInt expr with
      | Some v -> return (Value.inject_int (Cil.typeOf expr) v, Neither, false)
      | _      -> return (Value.top_int, Neither, false)

  and internal_forward_eval_constant env expr constant =
    let open Evaluated.Operators in
    let+ value =
      match constant with
      | CEnum {eival = e} -> forward_eval env e
      | CReal (_f, fkind, _fstring) ->
        let value = Value.constant env.context expr constant in
        remove_special_float expr fkind value
      (* Integer constants never overflow, because the front-end chooses a
         suitable type. *)
      | _ -> return (Value.constant env.context expr constant)
    in
    value, Neither, false


  (* ------------------------------------------------------------------------
                                Lvalue evaluation
     ------------------------------------------------------------------------ *)

  (* Calls the internal evaluation of an lvalue to a location, and stores the
     result in the cache. If the result is already in the cache, the computation
     is avoided, unless if it may reduce the cache.
     If [reduction] is false, don't reduce the location and the offset by their
     valid parts, and don't emit alarms about their validity.
     If the location is not bottom, the function also returns the typ of the
     lvalue, and a boolean indicating that the lvalue contains a sub-expression
     with volatile qualifier (in its host or offset). *)
  and lval_to_loc env ~for_writing ~reduction lval =
    let compute () =
      let res, alarms = reduced_lval_to_loc env ~for_writing ~reduction lval in
      let res =
        let+ loc, typ_offs, red, volatile = res in
        let fuel = env.remaining_fuel in
        let record = { loc; typ = typ_offs; loc_alarms = alarms }
        and report = { fuel = Finite fuel; reduction = red; volatile }
        and loc_report = { for_writing; with_reduction = reduction } in
        cache := Cache.add_loc' !cache lval (record, (report, loc_report));
        (loc, typ_offs, volatile)
      in
      res, alarms
    in
    let already_precise = already_precise_loc_report ~for_writing ~reduction in
    let not_enough_fuel = less_fuel_than env.remaining_fuel in
    match Cache.find_loc' !cache lval with
    | `Value (record, (report, loc_report)) ->
      if already_precise loc_report && not_enough_fuel report.fuel
      then `Value (record.loc, record.typ, report.volatile), record.loc_alarms
      else compute ()
    | `Top -> compute ()

  (* If [reduction] is false, don't reduce the location and the offset by their
     valid parts, and don't emit alarms about their validity. *)
  and reduced_lval_to_loc env ~for_writing ~reduction lval =
    let open Evaluated.Operators in
    let lval_to_loc = internal_lval_to_loc env ~for_writing ~reduction in
    let* loc, typ, volatile = lval_to_loc lval in
    if reduction then
      let bitfield = Cil.isBitfield lval in
      let truth = Loc.assume_valid_location ~for_writing ~bitfield loc in
      let access = Alarms.(if for_writing then For_writing else For_reading) in
      let alarm () = Alarms.Memory_access (lval, access) in
      let+ valid_loc = interpret_truth ~alarm loc truth in
      let reduction = if Loc.equal_loc valid_loc loc then Neither else Forward in
      valid_loc, typ, reduction, volatile
    else `Value (loc, typ, Neither, volatile), Alarmset.none

  (* Internal evaluation of a lvalue to an abstract location.
     Combination of the evaluation of the right part of an lval (an host) with
     an offset, to obtain a location *)
  and internal_lval_to_loc env ~for_writing ~reduction lval =
    let open Evaluated.Operators in
    let host, offset = lval in
    let typ = Cil.typeOfLhost host in
    let evaluated = eval_offset env ~reduce_valid_index:reduction typ offset in
    let* (offs, typ_offs, offset_volatile) = evaluated in
    if for_writing && Eva_utils.is_const_write_invalid typ_offs then
      let alarm = Alarms.(Memory_access (lval, For_writing)) in
      `Bottom, Alarmset.singleton ~status:Alarmset.False alarm
    else
      let+ loc, host_volatile = eval_host env typ_offs offs host in
      loc, typ_offs, offset_volatile || host_volatile

  (* Host evaluation. Also returns a boolean which is true if the host
     contains a volatile sub-expression. *)
  and eval_host env typ_offset offs = function
    | Var host ->
      let loc = Loc.forward_variable typ_offset host offs in
      (let+ loc in loc, false), Alarmset.none
    | Mem x ->
      let open Evaluated.Operators in
      let& loc_lv, volatile = root_forward_eval env x in
      let open Bottom.Operators in
      let+ loc = Loc.forward_pointer typ_offset loc_lv offs in
      loc, volatile

  (* Offset evaluation. Also returns a boolean which is true if the offset
     contains a volatile sub-expression. *)
  and eval_offset env ~reduce_valid_index typ = function
    | NoOffset -> return (Loc.no_offset, typ, false)
    | Index (index_expr, remaining) ->
      let open Evaluated.Operators in
      let typ_pointed, array_size =
        match Cil.unrollType typ with
        | TArray (t, size, _) -> t, size
        | t -> Self.fatal ~current:true "Got type '%a'" Printer.pp_typ t
      in
      let eval = eval_offset env ~reduce_valid_index typ_pointed remaining in
      let* roffset, typ_offs, remaining_volatile = eval in
      let* index, volatile = root_forward_eval env index_expr in
      let valid_index =
        if not (Kernel.SafeArrays.get ()) || not reduce_valid_index
        then `Value index, Alarmset.none
        else
          try
            (* If possible, reduce the index value by the array size. *)
            let size = Cil.lenOfArray64 array_size in
            (* Handle the special GCCism of zero-sized arrays: Frama-C
               pretends their size is unknown, exactly like GCC. *)
            if Integer.is_zero size
            then `Value index, Alarmset.none
            else
              let size_expr = Option.get array_size in (* array_size exists *)
              assume_valid_index ~size ~size_expr ~index_expr index
          with Cil.LenOfArray _ -> `Value index, Alarmset.none (* unknown array size *)
      in
      let+ index = valid_index in
      Loc.forward_index typ_pointed index roffset, typ_offs,
      remaining_volatile || volatile
    | Field (fi, remaining) ->
      let open Evaluated.Operators in
      let attrs = Cil.filter_qualifier_attributes (Cil.typeAttrs typ) in
      let typ_fi = Cil.typeAddAttributes attrs fi.ftype in
      let evaluated = eval_offset env ~reduce_valid_index typ_fi remaining in
      let+ r, typ_res, volatile = evaluated in
      let off = Loc.forward_field typ fi r in
      off, typ_res, volatile

  and eval_lval ?(indeterminate=false) env lval =
    let open Evaluated.Operators in
    let domain_query = make_domain_query Domain.extract_lval env in
    let env = { env with root = false } in
    (* Computes the location of [lval]. *)
    let evaluated = lval_to_loc env ~for_writing:false ~reduction:true lval in
    let* loc, typ_lv, volatile_expr = evaluated in
    let typ_lv = Cil.unrollType typ_lv in
    (* the lvalue is volatile:
       - if it has qualifier volatile (lval_to_loc propagates qualifiers
         in the proper way through offsets)
       - if it contains a sub-expression which is volatile (volatile_expr)
    *)
    let volatile = volatile_expr || Cil.typeHasQualifier "volatile" typ_lv in
    (* Find the value of the location, if not bottom. *)
    let v, alarms = domain_query lval typ_lv loc in
    let alarms = close_dereference_alarms lval alarms in
    if indeterminate then
      let record, alarms = indeterminate_copy lval v alarms in
      `Value (record, Neither, volatile), alarms
    else
      let v, alarms = assume_valid_value env.context typ_lv lval (v, alarms) in
      let+ value, origin = v, alarms in
      let value = define_value value in
      let reductness, reduction =
        if Alarmset.is_empty alarms then Unreduced, Neither else Reduced, Forward
      in
      (* The proper alarms will be set in the record by forward_eval. *)
      { value; origin; reductness; val_alarms = Alarmset.all },
      reduction, volatile

  (* ------------------------------------------------------------------------
                       Subdivided Forward Evaluation
     ------------------------------------------------------------------------ *)

  (* These two modules could be implemented as mutually recursive, to avoid
     the reference for the oracle given to the domains. *)
  module Forward_Evaluation = struct
    type environment = recursive_environment
    let evaluate ~subdivided environment valuation expr =
      let open Evaluated.Operators in
      cache := valuation;
      let root = not subdivided && environment.root in
      let subdivided = subdivided || environment.subdivided in
      let environment = { environment with root ; subdivided } in
      let+ value, _ = root_forward_eval environment expr in
      !cache, value
  end

  module Subdivided_Evaluation =
    Subdivided_evaluation.Make (Value) (Loc) (Cache) (Forward_Evaluation)

  let oracle env =
    let remaining_fuel = pred env.remaining_fuel in
    if remaining_fuel > 0 then
      fun expr ->
        let valuation = !cache in
        let env = { env with remaining_fuel } in
        let subdivnb = env.subdivision in
        let evaluate = Subdivided_Evaluation.evaluate env valuation in
        let eval, alarms = evaluate ~subdivnb expr in
        (* Always reset the reference to the cached valuation after a subdivided
           evaluation (as the multiple evaluations modify the cache). *)
        match eval with
        | `Bottom ->
          (* The evaluation of the expression requested by a domain returns
             Bottom, but the evaluation of the primary expression may continue.
             Thus bind Bottom to [expr] in the valuation. *)
          cache := Cache.add' valuation expr (bottom_entry alarms);
          `Bottom, alarms
        | `Value (valuation, value) ->
          cache := valuation;
          `Value value, alarms
    else fun _ -> fuel_consumed := true; `Value Value.top, Alarmset.all

  (* Context from state [state]. *)
  let get_context state =
    let+ from_domains = Domain.build_context state in
    Abstract_value.{ from_domains }

  (* Environment for the forward evaluation of a root expression in state [state]
     with maximal precision. *)
  let root_environment ?subdivnb state =
    let+ context = get_context state in
    let subdivided = false and root = true in
    let remaining_fuel = root_fuel () in
    (* By default, use the number of subdivision defined by the global option
       -eva-subdivide-non-linear. *)
    let default () =  Parameters.LinearLevel.get () in
    let subdivision = match subdivnb with None -> default () | Some n -> n in
    { state; context; root; subdivision; subdivided; remaining_fuel; oracle }

  (* Environment for a fast forward evaluation with minimal precision:
     no subdivisions, no calls to the oracle, and the expression is not
     considered as a "root" expression. *)
  let fast_eval_environment state =
    let+ context = get_context state in
    let remaining_fuel = no_fuel and root = false in
    let subdivision = 0 and subdivided = false in
    { state; context; root; subdivision; subdivided; remaining_fuel; oracle }

  let subdivided_forward_eval valuation ?subdivnb state expr =
    let open Evaluated.Operators in
    let* env = root_environment ?subdivnb state, Alarmset.none in
    let subdivnb = env.subdivision in
    Subdivided_Evaluation.evaluate env valuation ~subdivnb expr

  (* ------------------------------------------------------------------------
                           Backward Evaluation
     ------------------------------------------------------------------------ *)

  (* Find the value of a previously evaluated expression. *)
  let find_val expr =
    match Cache.find !cache expr with
    | `Value record -> record.value.v
    | `Top -> assert false (* [expr] must have been evaluated already. *)

  (* Find the record computed for an lvalue.
     Return None if no reduction can be performed. *)
  let find_loc_for_reduction lval =
    if may_be_reduced_lval lval then
      let record, report =
        match Cache.find_loc' !cache lval with
        | `Value all -> all
        | `Top -> assert false
      in
      if (snd report).with_reduction then Some (record, report) else None
    else None

  (* Evaluate an expression before any reduction, if needed. Also return the
     report indicating if a forward reduction during the forward evaluation may
     be propagated backward. *)
  let evaluate_for_reduction state expr =
    try `Value (Cache.find' !cache expr)
    with Not_found ->
      let* env = fast_eval_environment state in
      let+ _ = forward_eval env expr |> fst in
      try Cache.find' !cache expr
      with Not_found -> assert false

  (* The backward propagation at a step is relevant only if:
     - the new value (if any) is more precise than the old one.
       Then the latter is reduced by the former, and the reduction kind is set
       to [Backward].
     - or the old value has been reduced during the forward evaluation.
       Then, [report.reduced] is [Forward], and must be set to [Neither] as
       the reduction is propagated but the value of the current expression is
       unchanged. *)
  let backward_reduction old_value latter_reduction value =
    let forward = latter_reduction = Forward in
    let neither () = Some (old_value, Neither) in
    let propagate_forward_reduction () = if forward then neither () else None in
    match value with
    | None -> `Value (propagate_forward_reduction ())
    | Some new_value ->
      let+ value = Value.narrow old_value new_value in
      if Value.is_included old_value value
      then propagate_forward_reduction ()
      else Some (value, Backward)

  (* [backward_eval state expr value] reduces the the expression [expr] and
     its subterms in the cache, according to the state [state]:
     - the reductions performed during the forward evaluation (due to alarms or
       abstract domains) are propagated backward to the subexpressions;
     - if [value = Some v], then [expr] is assumed to evaluate to [v] (and is
       reduced accordingly). *)
  let rec backward_eval fuel context state expr value =
    (* Evaluate the expression if needed. *)
    let* record, report = evaluate_for_reduction state expr in
    (* Reduction of [expr] by [value]. Also performs further reductions
       requested by the domains. Returns Bottom if one of these reductions
       leads to bottom. *)
    let reduce kind value =
      let continue = `Value () in
      (* Avoids reduction of volatile expressions. *)
      if not report.volatile then
        let value = Value.reduce value in
        reduce_expr_recording kind expr (record, report) value ;
        (* If enough fuel, asks the domain for more reductions. *)
        if fuel > 0 then
          (* The reductions requested by the domains. *)
          let reductions_list = Domain.reduce_further state expr value in
          (* Reduces [expr] to value [v]. *)
          let reduce acc (expr, value) =
            (* If a previous reduction has returned bottom, return bottom. *)
            let* () = acc in
            backward_eval (pred fuel) context state expr (Some value)
          in
          List.fold_left reduce continue reductions_list
        else continue
      else continue
    in
    let* old_value = record.value.v in
    (* Determines the need of a backward reduction. *)
    let* reduced = backward_reduction old_value report.reduction value in
    match reduced with
    | None ->
      (* If no reduction to be propagated, just visit the subterms. *)
      recursive_descent fuel context state expr
    | Some (value, kind) ->
      (* Otherwise, backward propagation to the subterms. *)
      match expr.enode with
      | Lval lval ->
        begin
          (* For a lvalue, we try to reduce its location according to the value;
             this operation may lead to a more precise value for this lvalue,
             which is then reduced accordingly. *)
          let* reduced_loc = backward_loc state lval value in
          match reduced_loc with
          | None ->
            let* () = reduce kind value in
            recursive_descent_lval fuel context state lval
          | Some (loc, new_value) ->
            let included = Value.is_included old_value new_value in
            let kind = if included then Neither else Backward in
            let* () = reduce kind new_value in
            internal_backward_lval fuel context state loc lval
        end
      | _ ->
        let* () = reduce kind value in
        internal_backward fuel context state expr value

  (* Backward propagate the reduction [expr] = [value] to the subterms of the
     compound expression [expr]. *)
  and internal_backward fuel context state expr value =
    match expr.enode with
    | Lval _lv -> assert false
    | UnOp (LNot, e, _) ->
      let cond = Eva_utils.normalize_as_cond e false in
      (* TODO: should we compute the meet with the result of the call to
         Value.backward_unop? *)
      backward_eval fuel context state cond (Some value)
    | UnOp (op, e, _typ) ->
      let typ_arg = Cil.unrollType (Cil.typeOf e) in
      let* arg = find_val e in
      let* v = Value.backward_unop context ~typ_arg op ~arg ~res:value in
      backward_eval fuel context state e v
    | BinOp (binop, e1, e2, typ) ->
      let resulting_type = Cil.unrollType typ in
      let input_type = Cil.typeOf e1 in
      let* left = find_val e1
      and* right = find_val e2 in
      let backward = Value.backward_binop context ~input_type ~resulting_type in
      let* v1, v2 = backward binop ~left ~right ~result:value in
      let* () = backward_eval fuel context state e1 v1 in
      backward_eval fuel context state e2 v2
    | CastE (typ, e) ->
      begin
        let dst_typ = Cil.unrollType typ in
        let src_typ = Cil.unrollType (Cil.typeOf e) in
        let* src_val = find_val e in
        let backward = Value.backward_cast context ~src_typ ~dst_typ in
        let* v = backward ~src_val ~dst_val:value in
        backward_eval fuel context state e v
      end
    | _ -> `Value ()

  and recursive_descent fuel context state expr =
    match expr.enode with
    | Lval lval -> backward_lval fuel context state lval
    | UnOp (_, e, _)
    | CastE (_, e) -> backward_eval fuel context state e None
    | BinOp (_binop, e1, e2, _typ) ->
      let* () = backward_eval fuel context state e1 None in
      backward_eval fuel context state e2 None
    | _ -> `Value ()

  and recursive_descent_lval fuel context state (host, offset) =
    let* () = recursive_descent_host fuel context state host in
    recursive_descent_offset fuel context state offset

  and recursive_descent_host fuel context state = function
    | Var _ -> `Value ()
    | Mem expr -> backward_eval fuel context state expr None

  and recursive_descent_offset fuel context state = function
    | NoOffset               -> `Value ()
    | Field (_, remaining)   ->
      recursive_descent_offset fuel context state remaining
    | Index (exp, remaining) ->
      let* _ = backward_eval fuel context state exp None in
      recursive_descent_offset fuel context state remaining

  (* Even if the value of an lvalue has not been reduced, its memory location
     could have been, and this can be propagated backward. Otherwise, continue
     the recursive descent. *)
  and backward_lval fuel context state lval =
    match find_loc_for_reduction lval with
    | None -> recursive_descent_lval fuel context state lval
    | Some (record, report) ->
      if (fst report).reduction = Forward
      then internal_backward_lval fuel context state record.loc lval
      else recursive_descent_lval fuel context state lval

  (* [backward_loc state lval value] tries to reduce the memory location of the
     lvalue [lval] according to its value [value] in the state [state]. *)
  and backward_loc state lval value =
    match find_loc_for_reduction lval with
    | None -> `Value None
    | Some (record, report) ->
      let backward_location = Domain.backward_location state lval in
      let* loc, new_value = backward_location record.typ record.loc value in
      let+ value = Value.narrow new_value value in
      let b = not (Loc.equal_loc record.loc loc) in
      (* Avoids useless reductions and reductions of volatile expressions. *)
      if b && not (fst report).volatile then
        let record = { record with loc } in
        let report = { (fst report) with reduction = Backward }, snd report in
        cache := Cache.add_loc' !cache lval (record, report);
      else ();
      if b || (fst report).reduction = Forward
      then Some (loc, value)
      else None

  and internal_backward_lval fuel context state location = function
    | Var host, offset ->
      let* loc_offset = Loc.backward_variable host location in
      backward_offset fuel context state host.vtype offset loc_offset
    | Mem expr, offset ->
      match offset with
      | NoOffset ->
        let* loc_value = Loc.to_value location in
        backward_eval fuel context state expr (Some loc_value)
      | _ ->
        let reduce_valid_index = true in
        let typ_lval = Cil.typeOf_pointed (Cil.typeOf expr) in
        let* env = fast_eval_environment state in
        let eval = eval_offset env ~reduce_valid_index typ_lval offset in
        let* loc_offset, _, _ = fst eval in
        let* value = find_val expr in
        let pointer = Loc.backward_pointer value loc_offset location in
        let* pointer_value, loc_offset = pointer in
        let* () = backward_eval fuel context state expr (Some pointer_value) in
        backward_offset fuel context state typ_lval offset loc_offset

  and backward_offset fuel context state typ offset loc_offset =
    match offset with
    | NoOffset -> `Value ()
    | Field (field, remaining)  ->
      let* rem = Loc.backward_field typ field loc_offset in
      backward_offset fuel context state field.ftype remaining rem
    | Index (exp, remaining) ->
      let* v = find_val exp in
      let typ_pointed = Cil.typeOf_array_elem typ in
      let* env = fast_eval_environment state in
      let* rem, _, _ =
        eval_offset env ~reduce_valid_index:true typ_pointed remaining |> fst
      in
      let* v', rem' =
        Loc.backward_index ~index:v ~remaining:rem typ_pointed loc_offset
      in
      let reduced_v = if Value.is_included v v' then None else Some v' in
      let* () = backward_eval fuel context state exp reduced_v in
      backward_offset fuel context state typ_pointed remaining rem'


  (* ------------------------------------------------------------------------
                       Second Pass of Forward Evaluation
     ------------------------------------------------------------------------ *)

  exception Not_Exact_Reduction

  (** Second forward evaluation after a backward propagation for the condition
      of an if statement.
      Allows to forward propagate the backward reductions. Uses the internal
      forward functions to actually perform the computation instead of relying
      on the cache. However, the internal evaluation uses the cache for the sub-
      expressions, so this evaluation is still bottom-up, and update the cache
      progressively.
      Stops the descent as soon as there is no backward propagation to recover
      for an expression. However, more backward reduction could have been done
      below for other reasons (due to alarms or domains).
      Raises Not_Exact_Reduction if at any point, the forward evaluation leads
      to a less precise value than the one stored after the backward evaluation.
      This means that the backward propagation has not been precise enough. *)
  let rec second_forward_eval state expr =
    let find e = try Cache.find' !cache e with Not_found -> assert false in
    let record, report = find expr in
    if report.reduction == Backward then
      let* value = record.value.v in
      let* () = recursive_descent state expr in
      let new_value =
        match expr.enode with
        | Lval lval -> second_eval_lval state lval value
        | _ ->
          let* env = fast_eval_environment state in
          let+ v, _, _ = fst (internal_forward_eval env expr) in v
      in
      let* evaled = new_value in
      let evaled = Value.reduce evaled in
      let+ new_value = Value.narrow value evaled in
      if Value.is_included evaled value then
        let kind = if Value.equal value new_value then Neither else Forward in
        reduce_expr_value kind expr new_value
      else raise Not_Exact_Reduction
    else `Value ()

  and second_eval_lval state lval value =
    if may_be_reduced_lval lval then
      let record, report =
        match Cache.find_loc' !cache lval with
        | `Value all -> all
        | `Top -> assert false
      in
      let* env = fast_eval_environment state in
      let* () =
        if (fst report).reduction = Backward then
          let for_writing = false and reduction = true in
          let+ loc, _, _, _ =
            reduced_lval_to_loc ~for_writing ~reduction env lval |> fst
          in
          (* TODO: Loc.narrow *)
          let record = { record with loc } in
          let in_record loc = Loc.equal_loc record.loc loc in
          let reduction = if in_record loc then Neither else Forward in
          let report = { (fst report) with reduction }, snd report in
          cache := Cache.add_loc' !cache lval (record, report);
        else `Value ()
      in
      let* record, _, _ = eval_lval env lval |> fst in
      record.value.v
    else `Value value

  and recursive_descent state expr =
    match expr.enode with
    | Lval lval -> recursive_descent_lval state lval
    | UnOp (_, e, _)
    | CastE (_, e) -> second_forward_eval state e
    | BinOp (_, e1, e2, _) ->
      let* () = second_forward_eval state e1 in
      second_forward_eval state e2
    | _ -> `Value ()

  and recursive_descent_lval state (host, offset) =
    let* () = recursive_descent_host state host in
    recursive_descent_offset state offset

  and recursive_descent_host state = function
    | Var _ -> `Value ()
    | Mem expr -> second_forward_eval state expr

  and recursive_descent_offset state = function
    | NoOffset               -> `Value ()
    | Field (_, remaining)   -> recursive_descent_offset state remaining
    | Index (exp, remaining) ->
      let* () = second_forward_eval state exp in
      recursive_descent_offset state remaining

  (* ------------------------------------------------------------------------
                              Generic Interface
     ------------------------------------------------------------------------ *)

  module Valuation = Cache

  let to_domain_valuation valuation =
    let find = Valuation.find valuation in
    let fold f acc = Valuation.fold f valuation acc in
    let find_loc = Valuation.find_loc valuation in
    Abstract_domain.{ find ; fold ; find_loc }

  let evaluate ?(valuation=Cache.empty) ?(reduction=true) ?subdivnb state expr =
    let eval, alarms = subdivided_forward_eval valuation ?subdivnb state expr in
    let result =
      if reduction && not (Alarmset.is_empty alarms) then
        let open Bottom.Operators in
        let* valuation, value = eval in
        cache := valuation;
        let fuel = backward_fuel () in
        let* context = get_context state in
        let+ () = backward_eval fuel context state expr None in
        !cache, value
      else eval
    in
    result, alarms

  let copy_lvalue ?(valuation=Cache.empty) ?subdivnb state lval =
    let open Evaluated.Operators in
    let expr = Eva_utils.lval_to_exp lval in
    let* env = root_environment ?subdivnb state, Alarmset.none in
    try
      let record, report = Cache.find' valuation expr in
      if less_fuel_than env.remaining_fuel report.fuel
      then `Value (valuation, record.value), record.val_alarms
      else raise Not_found
    with Not_found ->
      cache := valuation;
      let+ record, _, volatile = eval_lval env ~indeterminate:true lval in
      let record = reduce_value record in
      (* Cache the computed result with an appropriate report. *)
      let fuel = Finite (root_fuel ()) in
      let report = { fuel; reduction = Neither; volatile } in
      let valuation = Cache.add' !cache expr (record, report) in
      valuation, record.value

  (* When evaluating an lvalue, we use the subdivided evaluation for the
     expressions included in the lvalue. *)
  let rec evaluate_offsets valuation ?subdivnb state = function
    | NoOffset             -> `Value valuation, Alarmset.none
    | Field (_, offset)    -> evaluate_offsets valuation ?subdivnb state offset
    | Index (expr, offset) ->
      let open Evaluated.Operators in
      let* valuation, _ =
        subdivided_forward_eval valuation ?subdivnb state expr
      in
      evaluate_offsets valuation ?subdivnb state offset

  let evaluate_host valuation ?subdivnb state = function
    | Var _ -> `Value valuation, Alarmset.none
    | Mem e -> subdivided_forward_eval valuation ?subdivnb state e >>=: fst

  let lvaluate ?(valuation=Cache.empty) ?subdivnb ~for_writing state lval =
    let open Evaluated.Operators in
    (* If [for_writing] is true, the location of [lval] is reduced by removing
       const bases. Use [for_writing:false] if const bases can be written
       through a mutable field or an initializing function. *)
    let for_writing = for_writing && not (Cil.is_mutable_or_initialized lval) in
    let host, offset = lval in
    let* valuation = evaluate_host valuation ?subdivnb state host in
    let* valuation = evaluate_offsets valuation ?subdivnb state offset in
    cache := valuation;
    let* env = root_environment ?subdivnb state, Alarmset.none in
    let& _, typ, _ = lval_to_loc env ~for_writing ~reduction:true lval in
    let open Bottom.Operators in
    let+ () = backward_lval (backward_fuel ()) env.context state lval in
    match Cache.find_loc !cache lval with
    | `Value record -> !cache, record.loc, typ
    | `Top -> assert false

  let reduce ?valuation:(valuation=Cache.empty) state expr positive =
    let open Evaluated.Operators in
    (* Generate [e == 0] *)
    let expr = Eva_utils.normalize_as_cond expr (not positive) in
    cache := valuation;
    (* Currently, no subdivisions are performed during the forward evaluation
       in this function, which is used to evaluate the conditions of if(…)
       statements in the analysis. *)
    let* env = root_environment ~subdivnb:0 state, Alarmset.none in
    let& _, volatile = root_forward_eval env expr in
    let open Bottom.Operators in
    (* Reduce by [(e == 0) == 0] *)
    let fuel = backward_fuel () in
    let* () = backward_eval fuel env.context state expr (Some Value.zero) in
    try let+ () = second_forward_eval state expr in !cache
    with Not_Exact_Reduction ->
      (* Avoids reduce_by_enumeration on volatile expressions. *)
      if not volatile then
        let* env = fast_eval_environment state in
        Subdivided_Evaluation.reduce_by_enumeration env !cache expr false
      else `Value !cache

  let assume ?valuation:(valuation=Cache.empty) state expr value =
    cache := valuation;
    let fuel = backward_fuel () in
    let* context = get_context state in
    let+ () = backward_eval fuel context state expr (Some value) in
    !cache


  (* ------------------------------------------------------------------------
                                      Misc
     ------------------------------------------------------------------------ *)

  (* Aborts the analysis when a function pointer is completely imprecise. *)
  let top_function_pointer funcexp =
    if not (Parameters.Domains.mem "cvalue") then
      Self.abort ~current:true
        "Calls through function pointers are not supported without the cvalue \
         domain.";
    if Function_calls.partial_results () then
      Self.abort ~current:true
        "Function pointer evaluates to anything. Try deactivating \
         option(s) -eva-no-results and -eva-no-results-function."
    else
      Self.fatal ~current:true
        "Function pointer evaluates to anything. function %a"
        Printer.pp_exp funcexp

  (* For pointer calls, we retro-propagate which function is being called
     in the abstract state. This may be useful:
     - inside the call for languages with OO (think 'self')
     - everywhere, because we may remove invalid values for the pointer
     - after if enough slevel is available, as states obtained in
       different functions are not merged by default. *)
  let backward_function_pointer valuation state expr kf =
    (* Builds the expression [exp_f != &f], and assumes it is false. *)
    let vi_f = Kernel_function.get_vi kf in
    let addr = Cil.mkAddrOfVi vi_f in
    let expr = Cil.mkBinOp ~loc:expr.eloc Ne expr addr in
    fst (reduce ~valuation state expr false)

  let eval_function_exp ?subdivnb funcexp ?args state =
    match funcexp.enode with
    | Lval (Var vinfo, NoOffset) ->
      `Value [Globals.Functions.get vinfo, Valuation.empty], Alarmset.none
    | Lval (Mem v, NoOffset) ->
      begin
        let open Evaluated.Operators in
        let* valuation, value = evaluate ?subdivnb state v in
        let kfs, alarm = Value.resolve_functions value in
        match kfs with
        | `Top -> top_function_pointer funcexp
        | `Value kfs ->
          let typ = Cil.typeOf funcexp in
          let kfs, alarm' = Eval_typ.compatible_functions typ ?args kfs in
          let reduce = backward_function_pointer valuation state v in
          let process acc kf =
            let res = reduce kf >>-: fun valuation -> kf, valuation in
            Bottom.add_to_list res acc
          in
          let list = List.fold_left process [] kfs in
          let status =
            if kfs = [] then Alarmset.False
            else if alarm || alarm' then Alarmset.Unknown
            else Alarmset.True
          in
          let alarm = Alarms.Function_pointer (v, args) in
          let alarms = Alarmset.singleton ~status alarm in
          Bottom.bot_of_list list, alarms
      end
    | _ -> assert false
end

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
