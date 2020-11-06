(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(* Heuristic for automatic loop unrolling: when the number of iterations of a
   loop can be bounded under a given limit, then unroll the loop.
   The limit is defined by the option -eva-auto-loop-unroll. *)

(* Gist of the heuristic:
   - collect loop exit conditions [cond] from statements "if (cond) break;"
   - find a loop exit condition in which only one lvalue [lval] is modified
     within the loop; all other lvalues must be constant in the loop.
   - find a value [v_exit] such that [lval] ∈ [v_exit] ⇒ [cond] holds.
   - evaluate [lval] to its initial value [v_init] in the loop entry state.
   - compute an over-approximation of the increment [v_delta] of [lval] in one
     iteration of the loop.

   If [v_init] + k × [v_delta] ⊂ [v_exit], then the number of iterations
   is bounded by [k].

   The heuristic is syntactic and limited to the current function: it does not
   handle assignment through pointers or function calls.
   Thus, the condition [cond] should only contains direct accesses to variables
   whose address is never taken (they cannot be modified through pointers). If
   the loop contains a function call, the condition [cond] should not contain
   global variables (as they may be modified in the function called).
   A first analysis of the loop gathers all such variables modified within the
   loop; all others are constant, and can be evaluated in the loop entry state.

   When computing the increment [v_delta] of a lvalue [v] in the loop, the
   heuristic searches assignments "v = v ± i;". Otherwise, if [v] is only
   modified within the loop through an assignement "v = v2", the heuristic
   computes the initial value and delta increment of variable [v2] instead.
   This is required to deal with temporary variables introduced by the Frama-C
   normalization.
   Any other assignment of [v] cancels the heuristic. *)

open Cil_types

let is_true = function
  | `True | `TrueReduced _ -> true
  | _ -> false

(* Does a block exits a loop? *)
let is_break block =
  match block.bstmts with
  | [{skind = Break _}] -> true
  | _ -> false

(* Returns a list of loop exit conditions. Each condition is expressed as an
   expression and whether it must be zero or non-zero to exit the loop. *)
let find_loop_exit_condition loop =
  let rec aux = function
    | [] -> []
    | stmt :: tl ->
      match stmt.skind with
      | If (cond, b1, b2, _) when is_break b1 || is_break b2 ->
        if is_break b1
        then (cond, true) :: aux (b2.bstmts @ tl)
        else (cond, false) :: aux (b1.bstmts @ tl)
      | Block b -> aux (b.bstmts @ tl)
      | _ -> aux tl
  in
  aux loop.bstmts

let is_frama_c_builtin exp =
  match exp.enode with
  | Lval (Var vi, NoOffset) -> Ast_info.is_frama_c_builtin vi.vname
  | _ -> false

(* Effects of a loop:
   - set of varinfos that are directly modified within the loop. Pointer
     accesses are ignored.
   - does the loop contain a call? If so, any global variable may also be
     modified in the loop. *)
type loop_effect =
  { written_vars: Cil_datatype.Varinfo.Set.t;
    pointer_writes: bool;
    call: bool; }

(* Visitor to compute the effects of a loop. *)
let loop_effect_visitor = object (self)
  inherit Visitor.frama_c_inplace

  val mutable written_vars = Cil_datatype.Varinfo.Set.empty
  val mutable pointer_writes = false
  val mutable call = false
  val mutable assembly = false

  (* Returns None if the loop contains assembly code. *)
  method compute_effect block =
    written_vars <- Cil_datatype.Varinfo.Set.empty;
    pointer_writes <- false;
    call <- false;
    assembly <- false;
    ignore Visitor.(visitFramacBlock (self :> frama_c_inplace) block);
    if assembly then None else Some { written_vars; pointer_writes; call; }

  method !vinst instr =
    let () = match instr with
      | Set ((Var varinfo, _), _, _)
      | Call (Some (Var varinfo, _), _, _, _) ->
        written_vars <- Cil_datatype.Varinfo.Set.add varinfo written_vars;
      | Set ((Mem _, _), _, _)
      | Call (Some (Mem _, _), _, _, _) ->
        pointer_writes <- true;
      | _ -> ()
    in
    let () = match instr with
      | Asm _ -> assembly <- true
      | Call (_, exp, _, _) when not (is_frama_c_builtin exp) -> call <- true
      | _ -> ()
    in
    Cil.SkipChildren
end

(* The status of a lvalue for the automatic loop unroll heuristic. *)
type var_status =
  | Constant  (* The lvalue is probably constant within the loop. *)
  | Candidate (* The lvalue is a good candidate for the heuristic:
                 integer type, access to a varinfo whose address is not taken,
                 modified within the loop but not in another function called
                 in the loop. *)
  | Unsuitable (* Cannot be used for the heuristic. *)

let is_integer lval = Cil.isIntegralType (Cil.typeOfLval lval)

(* Computes the status of a lvalue for the heuristic, according to the
   loop effects. *)
let classify eval_ptr loop_effect lval =
  let is_written varinfo =
    Cil_datatype.Varinfo.Set.mem varinfo loop_effect.written_vars
  in
  let rec is_const_expr expr =
    match expr.enode with
    | Lval lval -> classify_lval lval = Constant
    | UnOp (_, e, _) | CastE (_, e) | Info (e, _) -> is_const_expr e
    | BinOp (_, e1, e2, _) -> is_const_expr e1 && is_const_expr e2
    | Const _ | SizeOf _ | SizeOfE _ | SizeOfStr _
    | AlignOf _ | AlignOfE _ | AddrOf _ | StartOf _ -> true
  and classify_lval = function
    | Var varinfo, offset ->
      if (varinfo.vglob && loop_effect.call)
      || not (is_const_offset offset)
      then Unsuitable
      else if is_written varinfo
      then
        if is_integer lval && not varinfo.vaddrof then Candidate else Unsuitable
      else
        (* If the address of the variable is taken, it could be modified within
           the loop. We suppose here that this is not the case, but this could
           lead to some untimely loop unrolling. *)
        Constant
    | Mem expr, offset ->
      if not (loop_effect.pointer_writes || loop_effect.call)
      && is_const_expr expr && is_const_offset offset
      then
        match eval_ptr expr with
        | Some pointed when not (List.exists is_written pointed) -> Constant
        | _ -> Unsuitable
      else Unsuitable
  and is_const_offset = function
    | NoOffset -> true
    | Field (_, offset) -> is_const_offset offset
    | Index (e, offset) -> is_const_expr e && is_const_offset offset
  in
  classify_lval lval

(* Returns the list of all lvalues appearing in an expression. *)
let rec get_lvalues expr =
  match expr.enode with
  | Lval lval -> [ lval ]
  | UnOp (_, e, _) | CastE (_, e) | Info (e, _) -> get_lvalues e
  | BinOp (_op, e1, e2, _typ) -> get_lvalues e1 @ get_lvalues e2
  | Const _ | SizeOf _ | SizeOfE _ | SizeOfStr _
  | AlignOf _ | AlignOfE _ | AddrOf _ | StartOf _ -> []

(* Finds the unique candidate lvalue for the automatic loop unrolling
   heuristic in the expression [expr], if it exists. Returns None otherwise.  *)
let find_lonely_candidate eval_ptr loop_effect expr =
  let lvalues = get_lvalues expr in
  let rec aux acc list =
    match list with
    | [] -> acc
    | lval :: tl ->
      match classify eval_ptr loop_effect lval with
      | Unsuitable -> None
      | Constant   -> aux acc tl
      | Candidate  -> if acc = None then aux (Some lval) tl else None
  in
  aux None lvalues

(* Returns true if the instruction does not modify [lval]. *)
let is_safe_instruction lval = function
  | Set (lv, _, _)
  | Call (Some lv, _, _, _) -> not (Cil_datatype.LvalStructEq.equal lval lv)
  | Call (None, _, _, _) | Local_init _ | Skip _ | Code_annot _ -> true
  | Asm _ -> false

(* Returns true if the statement [stmt] of function [kf] does not modify [lval].
   [lval] is a candidate for the automatic loop unrolling of [loop]. *)
let is_constant kf ~loop lval stmt =
  let rec is_safe_stmt ~goto stmt =
    match stmt.skind with
    | Instr instr -> is_safe_instruction lval instr
    | Return _ | Break _ | Continue _ -> true
    | If (_, b_then, b_else, _) ->
      is_safe_block ~goto b_then && is_safe_block ~goto b_else
    | Block b
    | Switch (_, b, _, _)
    | Loop (_, b, _, _, _) -> is_safe_block ~goto b
    | UnspecifiedSequence list ->
      List.for_all (fun (stmt, _, _, _, _) -> is_safe_stmt ~goto stmt) list
    | Goto (dest, _) ->
      (* If [goto] holds, we are already checking a block for a [goto]. Do not
         process goto statements again here. *)
      goto ||
      let first_stmt = List.hd loop.bstmts in
      (* If the loop cannot be reached from [dest], then it is safe. *)
      not (Stmts_graph.stmt_can_reach kf !dest first_stmt) ||
      (* Otherwise, if the goto leaves the loop, then it forms another loop
         that contains the current loop, which we don't want to unroll. *)
      let dest_blocks = Kernel_function.find_all_enclosing_blocks !dest in
      List.exists (Cil_datatype.Block.equal loop) dest_blocks &&
      (* Otherwise, the goto stays within the loop. *)
      begin
        (* If the successors all exits the loop block, then the goto is safe.
           This is the case for gotos coming from "continue" statement.  *)
        let all_stmts = Stmts_graph.get_block_stmts loop in
        let is_outside_loop s = not (Cil_datatype.Stmt.Set.mem s all_stmts) in
        List.for_all is_outside_loop !dest.succs ||
        (* Otherwise, check that the block englobing both the source and the
           destination is safe. If this block is the loop itself, then it is
           not safe, as [lval] is modified within the loop. *)
        let block = Kernel_function.common_block !dest stmt in
        not (block == loop) && is_safe_block ~goto:true block
      end
    | _ -> false
  (* A block is safe if all its statements are safe. *)
  and is_safe_block ~goto b = List.for_all (is_safe_stmt ~goto) b.bstmts in
  is_safe_stmt ~goto:false stmt


module Make (Abstract: Abstractions.Eva) = struct

  open Eval
  open Abstract
  module Valuation = Abstract.Eval.Valuation
  module Clear_Valuation = Clear_Valuation (Valuation)

  let (>>) v f = match v with `Value v -> f v | _ -> None
  let (>>=) v f = match v with Some v -> f v | None -> None

  let cvalue_complement typ cvalue =
    let open Eval_typ in
    match Eval_typ.classify_as_scalar typ with
    | Some (TSFloat _ | TSPtr _) | None -> None
    | Some (TSInt ik) ->
      try
        let ival = Cvalue.V.project_ival cvalue in
        Ival.complement_int_under ~size:ik.i_bits ~signed:ik.i_signed ival
        >> fun ival -> Some (Cvalue.V.inject_ival ival)
      with Cvalue.V.Not_based_on_null -> None

  (* Reduces the condition "[condition] = [positive]" to a sufficient hypothesis
     on the value of the expression [expr]: computes a value [v] such that
     if the expression [expr] evaluates to [v], then [condition] = [positive].
     [valuation] contains additional hypotheses, i.e. the value of some constant
     lvalues of the [condition]. All computations must be done in the top state
     and in the given valuation. *)
  let reduce_to_expr valuation ~expr ~condition ~positive =
    let state = Abstract.Dom.top in
    (* Reduces [expr] by assuming that [condition] is [positive]. *)
    let reduce positive =
      (* Assumes that [condition] is [positive]. *)
      fst (Eval.reduce ~valuation state condition positive) >> fun valuation ->
      (* Finds the value of [expr] in the resulting valuation. *)
      Valuation.find valuation expr >> fun record ->
      record.value.v >> fun value ->
      (* If the new value of [expr] is top, no reduction has been performed. *)
      if Val.(equal top value) then None else Some (value, record)
    in
    (* Assumes that [condition] is [positive]. Returns an over-approximation
       of the values for which [condition] is [positive]. *)
    reduce positive >>= fun (value, record) ->
    (* Evaluates [condition] with the hypothesis [expr] ∈ [value], to check
       whether [expr] ∈ [value] ⇒ [condition] = [positive]. *)
    let valuation = Valuation.add valuation expr record in
    fst (Eval.evaluate ~valuation ~reduction:false state condition)
    >> fun (_valuation, v) ->
    let satisfied =
      if positive
      then not Val.(is_included zero v)
      else Val.(equal zero v)
    in
    (* If the condition is satisfied, returns [value]. Otherwise, uses a
       specific feature to cvalue (if possible) to compute a better value. *)
    if satisfied then Some value else
      Val.get Main_values.CVal.key >>= fun get_cvalue ->
      (* Assumes that [condition] is NOT [positive]. *)
      reduce (not positive) >>= fun (value, _record) ->
      (* [value] is an over-approximation of the values of [expr] for which
         [condition] is NOT positive; its complement is an under-approximation
         of the values for which [condition] is positive. *)
      let cvalue = get_cvalue value in
      cvalue_complement (Cil.typeOf expr) cvalue >>= fun cvalue ->
      Some (Val.set Main_values.CVal.key cvalue Val.top)

  (* Same as [reduce_to_expr] above, but builds the proper valuation from the
     [state]. [state] is the entry state of the loop, and [expr] is the only
     part of [condition] that is not constant within the loop. [state] can thus
     be used to evaluate all other subparts of [condition], before computing
     the value of [expr] that satisfies [condition]. *)
  let reduce_to_lval_from_state state lval condition positive =
    let expr = Cil.new_exp ~loc:condition.eloc (Lval lval) in
    (* Evaluate the [condition] in the given [state]. *)
    fst (Eval.evaluate state condition) >> fun (valuation, _v) ->
    (* In the resulting valuation, replace the value of [expr] by [top_int]
       and removes all expressions depending on [expr]. *)
    Valuation.find valuation expr >> fun record ->
    let value = { record.value with v = `Value Val.top_int } in
    let record = { record with value } in
    let valuation =
      Clear_Valuation.clear_englobing_exprs
        valuation ~expr:condition ~subexpr:expr
    in
    let valuation = Valuation.add valuation expr record in
    reduce_to_expr valuation ~expr ~condition ~positive

  (* Over-approximation of the increment of a lvalue in one loop iteration.*)
  type delta =
    { current: Val.t or_bottom; (* current delta being computed*)
      final: Val.t or_bottom;   (* final delta after a continue statement. *)
    }

  let join_delta d1 d2 =
    { current = Bottom.join Val.join d1.current d2.current;
      final = Bottom.join Val.join d1.final d2.final; }

  let final_delta delta = Bottom.join Val.join delta.current delta.final

  (* Raised when no increment can be computed for the given lvalue in one
     loop iteration. *)
  exception NoIncrement

  (* Adds or subtracts the integer value of [expr] to the current delta
     [delta.current], according to [binop] which can be PlusA or MinusA.
     Raises NoIncrement if [expr] is not a constant integer expression. *)
  let add_to_delta binop delta expr =
    let typ = Cil.typeOf expr in
    match Cil.constFoldToInt expr with
    | None -> raise NoIncrement
    | Some i ->
      let value = Val.inject_int typ i in
      let current = match delta.current with
        | `Bottom -> `Value value
        | `Value v -> Val.forward_binop typ binop v value
      in
      { delta with current }

  (* Adds to [delta] the increment from the assignement of [lval] to the value
     of [expr]. Raises NoIncrement if this is not an increment of [lval]. *)
  let rec delta_assign lval delta expr =
    (* Is the expression [e] equal to the lvalue [lval] (modulo cast)? *)
    let rec is_lval e = match e.enode with
      | Lval lv -> Cil_datatype.LvalStructEq.equal lval lv
      | CastE (typ, e) -> Cil.isIntegralType typ && is_lval e
      | Info (e, _) -> is_lval e
      | _ -> false
    in
    match expr.enode with
    | BinOp ((PlusA | MinusA) as binop, e1, e2, _) ->
      if is_lval e1
      then add_to_delta binop delta e2
      else if is_lval e2 && binop = PlusA
      then add_to_delta binop delta e1
      else raise NoIncrement
    | CastE (typ, e) when Cil.isIntegralType typ -> delta_assign lval delta e
    | Info (e, _) -> delta_assign lval delta e
    | _ -> raise NoIncrement

  let delta_instruction lval delta = function
    | Set (lv, expr, _loc) ->
      if Cil_datatype.LvalStructEq.equal lval lv
      then delta_assign lval delta expr
      else delta
    | Call (Some lv, _, _, _) ->
      if Cil_datatype.LvalStructEq.equal lval lv
      then raise NoIncrement (* No increment can be computed for a call. *)
      else delta
    | Call (None, _, _, _) | Local_init _ | Skip _ | Code_annot _ -> delta
    | Asm _ -> raise NoIncrement

  (* Computes an over-approximation of the increment of [lval] in the block
     [loop]. Only syntactic assignments of [lval] are considered, so [lval]
     should be a direct access to a variable whose address is not taken,
     and which should not be global if the loop contains function calls.
     Returns None if no increment can be computed. *)
  let compute_delta kf lval loop =
    let rec delta_stmt acc stmt =
      match stmt.skind with
      | Instr instr -> delta_instruction lval acc instr
      | Break _ ->
        (* No increment, as the statement leaves the loop. *)
        { current = `Bottom; final = `Bottom }
      | Continue _ ->
        (* The current increment becomes the final increment. *)
        { current = `Bottom; final = final_delta acc }
      | If (_e, b1, b2, _loc) ->
        join_delta (delta_block acc b1) (delta_block acc b2)
      | Block b -> delta_block acc b
      | UnspecifiedSequence list ->
        List.fold_left (fun acc (s, _, _, _, _) -> delta_stmt acc s) acc list
      | _ ->
        (* For other statements, we only check that they do not modify [lval]. *)
        if is_constant kf ~loop lval stmt then acc else raise NoIncrement
    and delta_block acc block =
      List.fold_left delta_stmt acc block.bstmts
    in
    try
      let zero_delta = { current = `Value Val.zero; final = `Bottom; } in
      let delta = delta_block zero_delta loop in
      final_delta delta >> fun d ->
      if is_true (Val.assume_non_zero d) then Some d else None
    with NoIncrement -> None

  (* If in the block [loop], [lval] is assigned once to the value of another
     lvalue, returns this new lvalue. Otherwise, returns [lval]. *)
  let cross_equality lval loop =
    (* If no such single equality can be found, return [lval] unchanged. *)
    let exception No_equality in
    let rec find_lval acc expr =
      if acc <> None then raise No_equality else
        match expr.enode with
        | Lval lval -> Some lval
        | Info (e, _) -> find_lval acc e
        | _ -> raise No_equality
    in
    let cross_instr acc = function
      | Set (lv, expr, _loc) when Cil_datatype.LvalStructEq.equal lv lval ->
        find_lval acc expr
      | Local_init (varinfo, AssignInit (SingleInit expr), _loc)
        when Cil_datatype.LvalStructEq.equal (Cil.var varinfo) lval ->
        find_lval acc expr
      | Call (Some lv, _, _, _) when Cil_datatype.LvalStructEq.equal lval lv ->
        raise No_equality
      | _ -> acc
    in
    let rec cross_stmt acc stmt =
      match stmt.skind with
      | Instr instr -> cross_instr acc instr
      | Block block -> cross_block acc block
      | UnspecifiedSequence list ->
        List.fold_left (fun acc (s, _, _, _, _) -> cross_stmt acc s) acc list
      | If (_, {bstmts=[{skind=Break _}]}, block, _)
      | If (_, block, {bstmts=[{skind=Break _}]}, _) -> cross_block acc block
      | _ -> acc
    and cross_block acc block =
      List.fold_left cross_stmt acc block.bstmts
    in
    match cross_block None loop with
    | None -> lval
    | Some lval -> lval
    | exception No_equality -> lval

  (* If [lval] is a varinfo out-of-scope at statement [stmt] of function [kf],
     introduces it to the [state]. *)
  let enter_scope state kf stmt lval =
    match lval with
    | Var vi, _ when not (vi.vglob || vi.vformal
                          || Kernel_function.var_is_in_scope stmt vi) ->
      let kind = Abstract_domain.Local kf in
      let state = Abstract.Dom.enter_scope kind [vi] state in
      let location = Abstract.Loc.eval_varinfo vi in
      Abstract.Dom.logic_assign None location state
    | _ -> state

  (* Evaluates the lvalue [lval] in the state [state]. Returns None if the value
     may be undeterminate. *)
  let evaluate_lvalue state lval =
    fst (Eval.copy_lvalue state lval) >> fun (_valuation, flagged_value) ->
    if not flagged_value.initialized || flagged_value.escaping
    then None
    else flagged_value.v >> fun v -> Some v

  (* TODO *)
  let evaluate_pointer state expr =
    Val.get Main_values.CVal.key >>= fun get_cvalue ->
    fst (Eval.evaluate state expr) >> fun (_valuation, v) ->
    let cvalue = get_cvalue v in
    match Cvalue.V.get_bases cvalue with
    | Base.SetLattice.Top -> None
    | Base.SetLattice.Set bases ->
      try
        let varinfo_list =
          Base.Hptset.fold (fun base acc -> Base.to_varinfo base :: acc) bases []
        in
        Some varinfo_list
      with Base.Not_a_C_variable -> assert false

  let (>>:) v f = match v with Some v -> f v | None -> false

  (* Is the number of iterations of a loop bounded by [limit]?
     [state] is the loop entry state, and [loop_block] the block of the loop. *)
  let is_bounded_loop kf stmt state limit loop_block =
    (* Computes the effect of the loop. Stops if it contains assembly code. *)
    loop_effect_visitor#compute_effect loop_block >>: fun loop_effect ->
    (* Finds loop exit conditions. *)
    let exit_conditions = find_loop_exit_condition loop_block in
    (* Does the condition [condition = positive] limits the number of iterations
       of the loop by [limit]? *)
    let is_bounded_by_condition (condition, positive) =
      let eval_ptr = evaluate_pointer state in
      (* Finds the unique integer lvalue modified within the loop in [condition].
         Stops if it does not exist is not a good candidate for the heuristic. *)
      find_lonely_candidate eval_ptr loop_effect condition >>: fun lval ->
      (* If [lval] is not in scope at [stmt], introduces it into [state] so that
         [lval] can be properly evaluated in [state]. *)
      let state = enter_scope state kf stmt lval in
      (* Reduce [condition] to a sufficient hypothesis over the [lval] value:
         if [lval] ∈ [v_exit] then [condition = positive]. *)
      reduce_to_lval_from_state state lval condition positive >>: fun v_exit ->
      (* If [lval] is only assigned to the value of another lvalue, uses it
         instead. This is especially useful to deal with temporary variables
         introduced by the Frama-C normalization. *)
      let lval = cross_equality lval loop_block in
      (* Evaluates the initial value [v_init] of [lval] in the loop entry state. *)
      evaluate_lvalue state lval >>: fun v_init ->
      (* Computes an over-approximation [v_delta] of the increment of [lval]
         in one iteration of the loop. *)
      compute_delta kf lval loop_block >>: fun v_delta ->
      let typ = Cil.typeOfLval lval in
      let binop op v1 v2 = Bottom.non_bottom (Val.forward_binop typ op v1 v2) in
      (* Possible iterations numbers to exit the loop. *)
      let iter_nb = binop Div (binop MinusA v_exit v_init) v_delta in
      let bound = Abstract_value.Int (Integer.of_int limit) in
      (* Use the iteration number if it is always smaller than the [limit].
         Otherwise use [limit]. *)
      let limit =
        if is_true (Val.assume_bounded Alarms.Upper_bound bound iter_nb)
        then iter_nb
        else Val.inject_int typ (Integer.of_int limit)
      in
      (* Checks whether [v_init] + [limit] × [v_delta] ⊂ [v_exit]. *)
      let value = binop PlusA v_init (binop Mult limit v_delta) in
      Val.is_included value v_exit
    in
    (* Tests whether at least one of the exit conditions limits the number of
       iteration by [limit]. *)
    List.exists is_bounded_by_condition exit_conditions

  (* Computes an automatic loop unrolling for statement [stmt] in state [state],
     with a maximum limit. Returns None for no automatic loop unrolling. *)
  let compute ~max_unroll state stmt =
    try
      let kf = Kernel_function.find_englobing_kf stmt in
      let loop_stmt = Kernel_function.find_enclosing_loop kf stmt in
      match loop_stmt.skind with
      | Loop (_code_annot, block, _loc, _, _) ->
        if is_bounded_loop kf stmt state max_unroll block
        then Some max_unroll
        else None
      | _ -> None
    with Not_found -> None
end
