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

open Cil_types
open Cil
open Cil_datatype

(** Forward reference for [Translate.predicate_to_exp]. *)
let predicate_to_exp_ref
  : (kernel_function -> Env.t -> predicate -> exp * Env.t) ref
  = Extlib.mk_fun "predicate_to_exp_ref"

(** [error_msg quantif msg pp x] creates an error message from the string [msg]
    containing the value [x] pretty-printed by [pp] and the predicate [quantif]
    pretty-printed. *)
let error_msg quantif msg pp x =
  let msg1 = Format.asprintf msg pp x in
  let msg2 =
    Format.asprintf "@[ in quantification@ %a@]"
      Printer.pp_predicate quantif
  in
  msg1 ^ msg2

(** Helper module to process the constraints in the quantification and extract
    guards for the quantified variables. *)
module Constraints: sig
  (** Context type manipulated by the functions of the module. *)
  type t

  (** [empty quantif bounded_vars] creates an empty context from a
      quantification predicate and the list of bounded variables for the
      predicate. *)
  val empty: predicate -> logic_var list -> t

  (** [get_bounded_var ctxt t] returns the logic var corresponding to the given
      term if the term is a variable ([TLval(Tvar _, TNoOffset)]) that is a
      bounded variable for the quantification being processed, or [None]
      otherwise. *)
  val get_bounded_var: term -> t -> logic_var option

  (** [has_unguarded_bounded_vars ctxt] returns true iff some bounded variables
      in [ctxt] do not have a guard extracted from the quantification
      predicate. *)
  val has_unguarded_bounded_vars: t -> bool

  (** [add_lower_bound ctxt t r lv] adds the lower bound [t r lv] to the list
      of guards for the quantification.
      @raises Typing_error if a lower bound already exists for [lv]. *)
  val add_lower_bound: term -> relation -> logic_var -> t -> t

  (** [add_linked_upper_bound ctxt lv1 r lv2] adds a link between two bounded
      variables with still incomplete guards. [lv1] should already have at least
      a lower bound.
      @raises Typing_error if [lv1] do not have an existing lower bound. *)
  val add_linked_upper_bound: logic_var -> relation -> logic_var -> t -> t

  (** [add_upper_bound ctxt lv r t] adds the upper bound [lv r t] to the list of
      guards for the quantification.
      For each existing linked relation [lv' r' lv], also adds the upper bound
      [lv' r'' t] to the list of guards, with [r''] being the strictest relation
      between [r] and [r'].
      @raises Typing_error if either [lv] or [lv'] does not have an existing
      lower bound. *)
  val add_upper_bound: logic_var -> relation -> term -> t -> t

  (** [check_validity ctxt] checks the validity of the quantification after
      processing.
      @raises Typing_error if some bound (lower or upper) cound not be extracted
      from the quantification for each bounded variable. *)
  val check_validity: t -> unit

  (** [retrieve_guards ctxt] returns the list of guards for the bounded
      variables of the quantification, in the order in which they must be
      generated, ie. if [j] depends on [i] then the guard for [i] will be before
      the guard for [j] in the list.
      [check_validity ctxt] must have been called before calling
      [retrieve_guards]. *)
  val retrieve_guards: t -> (term * relation * logic_var * relation * term) list

  (** [raise_error ctxt msg] raises a [Typing_error] exception with the given
      message after appending the quantification from the context. *)
  val raise_error: string -> t -> 'a

  (** [error_invalid_pred ?warn_rel ctxt p] raises a [Typing_error] exception
      with a message indicating that the predicate [p] is not valid in the
      quantification. Depending on the state of [ctxt], more information about
      missing bounds is added to the message. If [warn_rel] is [true], then a
      reminder that only [Rle] and [Rlt] are allowed to guard quantified
      variables is added to the message. *)
  val raise_error_invalid_pred: ?warn_rel:bool -> predicate -> t -> 'a
end = struct
  type t = {
    (** Quantification predicate being analyzed. *)
    quantif: predicate;
    (** Variables of the quantification that still need guards. *)
    bounded_vars: Logic_var.Set.t;
    (** Bounded variables list in reverse order in which they must be
        generated. *)
    rev_order: Logic_var.t list;
    (** Table associating a bounded variable with its guard. *)
    guards: (term * relation * (relation * term) option) Logic_var.Map.t;
    (** Table associating a bounded variable with a relation with another
        bounded variable. *)
    linked_upper_bounds: (logic_var * relation) Logic_var.Map.t;
  }

  let empty quantif bounded_vars =
    (* Check that the bounded vars have integer type and store them in a set. *)
    let bounded_vars =
      List.fold_left
        (fun s v ->
           let v =
             match v.lv_type with
             | Ctype ty when isIntegralType ty -> v
             | Linteger -> v
             | Ltype _ as ty when Logic_const.is_boolean_type ty -> v
             | Ctype _ | Ltype _ | Lvar _ | Lreal | Larrow _ ->
               Error.not_yet
                 (error_msg
                    quantif
                    "@[non integer variable %a@]"
                    Printer.pp_logic_var v)
           in
           Logic_var.Set.add v s
        )
        Logic_var.Set.empty
        bounded_vars
    in
    {
      quantif;
      bounded_vars;
      rev_order = [];
      guards = Logic_var.Map.empty;
      linked_upper_bounds = Logic_var.Map.empty;
    }

  let get_bounded_var t ctxt =
    let rec aux t =
      match t.term_node with
      | TLogic_coerce(_, t) -> aux t
      | TLval(TVar lv, TNoOffset) when Logic_var.Set.mem lv ctxt.bounded_vars ->
        Some lv
      | _ -> None
    in
    aux t

  let has_unguarded_bounded_vars ctxt =
    not (Logic_var.Set.is_empty ctxt.bounded_vars)

  (** Pretty printer for a guard, represented by a tuple
      [(term, relation, logic_var, relation, term)]. *)
  let pp_guard fmt (t1, r1, lv, r2, t2) =
    Format.fprintf
      fmt
      "@[%a %a %a %a %a@]"
      Printer.pp_term t1
      Printer.pp_relation r1
      Printer.pp_logic_var lv
      Printer.pp_relation r2
      Printer.pp_term t2

  (** Pretty printer for a lower bound, represented by the tuple
      [(term, relation, logic_var)]. *)
  let pp_lbound fmt (t, r, lv) =
    Format.fprintf
      fmt
      "@[%a %a %a@]"
      Printer.pp_term t
      Printer.pp_relation r
      Printer.pp_logic_var lv

  (** Pretty printer for a bound between two quantified variables,
      represented by the tuple [(logic_var, relation, logic_var)]. *)
  let pp_linked_bound fmt (lv1, r, lv2) =
    Format.fprintf
      fmt
      "@[%a %a %a@]"
      Printer.pp_logic_var lv1
      Printer.pp_relation r
      Printer.pp_logic_var lv2

  let add_lower_bound t r lv ctxt =
    match Logic_var.Map.find_opt lv ctxt.guards with
    | None ->
      { ctxt with
        guards = Logic_var.Map.add lv (t, r, None) ctxt.guards; }
    | Some (t', r', None) ->
      let msg =
        Format.asprintf
          "@[found existing lower bound %a@ when processing %a@ \
           in quantification@ %a@]"
          pp_lbound (t', r', lv)
          pp_lbound (t, r, lv)
          Printer.pp_predicate ctxt.quantif
      in
      Error.untypable msg
    | Some (t1', r1', Some (r2', t2')) ->
      let msg =
        Format.asprintf
          "@[found existing guard %a@ when processing %a@ \
           in quantification@ %a@]"
          pp_guard (t1', r1', lv, r2', t2')
          pp_lbound (t, r, lv)
          Printer.pp_predicate ctxt.quantif
      in
      Error.untypable msg

  let add_linked_upper_bound lv1 r lv2 ctxt =
    if Logic_var.Map.mem lv1 ctxt.guards then begin
      { ctxt with
        linked_upper_bounds =
          Logic_var.Map.add lv2
            (lv1, r)
            ctxt.linked_upper_bounds; }
    end else
      let msg=
        Format.asprintf
          "@[missing lower bound for %a@ when processing the linked upper \
           bound %a@ in quantification@ %a@]"
          Printer.pp_logic_var lv1
          pp_linked_bound (lv1, r, lv2)
          Printer.pp_predicate ctxt.quantif
      in
      Error.untypable msg

  let add_upper_bound lv r t ctxt =
    (* Select the strictest relation between [r1] and [r2], with both relations
       being either [Rlt] or [Rle]. *)
    let strictest_relation r1 r2 =
      match r1, r2 with
      | (Rlt | Rle), Rlt | Rlt, Rle -> Rlt
      | Rle, Rle -> Rle
      | _, _ ->
        Options.fatal
          "invalid relations %a and %a in quantification %a"
          Printer.pp_relation r1
          Printer.pp_relation r2
          Printer.pp_predicate ctxt.quantif
    in
    (* Replace the guard for [lv] to add the upper bound [lv r t], and
       recursively walk the bounds linked to [lv] to also add upper bounds. *)
    let rec replace_guard lv r t ctxt =
      try
        let lower_bound_t, lower_bound_r, _ =
          Logic_var.Map.find lv ctxt.guards
        in
        let ctxt =
          { ctxt with
            guards =
              Logic_var.Map.add
                lv
                (lower_bound_t, lower_bound_r, Some (r, t))
                ctxt.guards; }
        in
        let ctxt =
          { ctxt with
            bounded_vars = Logic_var.Set.remove lv ctxt.bounded_vars; }
        in
        let need_upper_bound =
          Logic_var.Map.find_opt lv ctxt.linked_upper_bounds
        in
        let ctxt =
          match need_upper_bound with
          | Some (lv', r') ->
            let ctxt =
              { ctxt with
                linked_upper_bounds =
                  Logic_var.Map.remove lv ctxt.linked_upper_bounds; }
            in
            replace_guard lv' (strictest_relation r r') t ctxt
          | None -> ctxt
        in
        { ctxt with rev_order = lv :: ctxt.rev_order }
      with Not_found ->
        Error.untypable
          (error_msg ctxt.quantif
             "@[missing lower bound for %a@]"
             Printer.pp_logic_var lv)
    in
    replace_guard lv r t ctxt

  let check_validity ctxt =
    if not (Logic_var.Map.is_empty ctxt.linked_upper_bounds) then
      let msg =
        let iter_keys f map_seq =
          Seq.iter
            (fun (key, _) -> f key)
            map_seq
        in
        Format.asprintf
          "@[missing upper bound%s for %a@ in quantification@ %a@]"
          (if Logic_var.Map.cardinal ctxt.linked_upper_bounds = 1 then ""
           else "s")
          (Pretty_utils.pp_iter
             ~sep:", "
             iter_keys
             Printer.pp_logic_var)
          (Logic_var.Map.to_seq ctxt.linked_upper_bounds)
          Printer.pp_predicate ctxt.quantif
      in
      Error.untypable msg
    else if not (Logic_var.Set.is_empty ctxt.bounded_vars) then
      let msg =
        Format.asprintf
          "@[missing lower bound%s for %a@ in quantification@ %a@]"
          (if Logic_var.Set.cardinal ctxt.bounded_vars = 1 then "" else "s")
          (Pretty_utils.pp_iter
             ~sep:", "
             Logic_var.Set.iter
             Printer.pp_logic_var)
          ctxt.bounded_vars
          Printer.pp_predicate ctxt.quantif
      in
      Error.untypable msg

  let retrieve_guards ctxt =
    List.fold_left
      (fun acc lv ->
         match Logic_var.Map.find_opt lv ctxt.guards with
         | Some (t1, r1, Some (r2, t2)) ->
           (t1, r1, lv, r2, t2) :: acc

         (* The error cases should not occur if the traversal of the
            quantification was completed and [check_validity] was called
            successfully. *)
         | Some (_, _, None) ->
           Options.fatal
             "Missing upper bound when trying to retrieve the guard for %a"
             Printer.pp_logic_var lv
         | None -> Options.fatal "Missing guard for %a" Printer.pp_logic_var lv
      )
      []
      ctxt.rev_order

  let raise_error msg ctxt =
    let msg2 =
      Format.asprintf "@[ in quantification@ %a@]"
        Printer.pp_predicate ctxt.quantif
    in
    Error.untypable (msg ^ msg2)

  let raise_error_invalid_pred ?(warn_rel=false) p ctxt =
    (* Extract the set of variables that have another variable for upper bound.
       They will be considered valid for the purpose of the error message, ie.
       if we have the relation [0 < i < j] with [0 < i] as an incomplete guard
       and [i < j] as a linked upper bound, then the error is about [j] not
       having an upper bound, not about [i]. *)
    let linked_upper_bounds =
      Logic_var.Map.fold
        (fun _ (lv, _) acc -> Logic_var.Set.add lv acc)
        ctxt.linked_upper_bounds
        Logic_var.Set.empty
    in

    let missing_guards, missing_upper_bounds =
      Logic_var.Set.fold
        (fun lv (missing_guards, missing_upper_bounds) ->
           match Logic_var.Map.find_opt lv ctxt.guards with
           | Some (_, _, None)
             when not (Logic_var.Set.mem lv linked_upper_bounds) ->
             (* A variable with an incomplete constraint and without a linked
                upper bound has a missing upper bound. *)
             missing_guards, lv :: missing_upper_bounds
           | None ->
             (* A variable without a constraint has a missing guard. *)
             lv :: missing_guards, missing_upper_bounds
           | _ ->
             (* Otherwise the variable either has a complete constraint, or an
                incomplete constraint but with a linked upper bound. *)
             missing_guards, missing_upper_bounds)
        ctxt.bounded_vars
        ([], [])
    in

    let msg =
      Format.asprintf
        "@[invalid guard %a@ in quantification@ %a.@ \
         %a@,%a@ \
         %t@]"
        Printer.pp_predicate p Printer.pp_predicate ctxt.quantif
        (Pretty_utils.pp_list
           ~pre:"@[Missing guard for "
           ~sep:",@ "
           ~suf:".@]"
           Printer.pp_logic_var)
        (List.rev missing_guards)
        (Pretty_utils.pp_list
           ~pre:"@[Missing upper bound for "
           ~sep:",@ "
           ~suf:".@]"
           Printer.pp_logic_var)
        (List.rev missing_upper_bounds)
        (fun fmt ->
           if warn_rel then
             Format.fprintf fmt
               "@[Only %a and %a are allowed to guard quantifier variables@]"
               Printer.pp_relation Rlt Printer.pp_relation Rle)
    in
    Error.untypable msg
end

(** [extract_constraint ctxt t1 r t2] populates the quantification context
    [ctxt] with the constraint [t1 r t2], either adding a lower bound if [t2] is
    a bounded variable or adding an upper bound if [t1] is a bounded variable.
    @raises Typing_error if no constraint can be extracted or if the constraint
    is invalid (no bounded variable in [t1] or [t2] for instance). *)
let extract_constraint ctxt t1 r t2 =
  (* Return the logic var corresponding to the given term or [None] if the term
     is not a variable ([TLval(TVar _, TNoOffset)]). *)
  let rec _get_logic_var_opt t =
    match t.term_node with
    | TLogic_coerce(_, t) -> _get_logic_var_opt t
    | TLval(TVar x, TNoOffset) -> Some x
    | _ -> None
  in
  (* Process the given relation *)
  let lv1 = Constraints.get_bounded_var t1 ctxt in
  let lv2 = Constraints.get_bounded_var t2 ctxt in
  match lv1, lv2 with
  | None, Some lv2 -> (* t1 value, t2 variable: store lower bound *)
    Constraints.add_lower_bound t1 r lv2 ctxt
  | Some lv1, None -> (* t1 variable, t2 value: store upper bound *)
    Constraints.add_upper_bound lv1 r t2 ctxt
  | Some lv1, Some lv2 ->
    (* t1 variable, t2 variable: store link between t1 and t2 *)
    let ctxt = Constraints.add_linked_upper_bound lv1 r lv2 ctxt in
    Constraints.add_lower_bound t1 r lv2 ctxt
  | None, None -> (* t1 value, t2 value: error *)
    let msg =
      Format.asprintf
        "@[invalid constraint %a %a %a, both operands are constants or \
         already bounded@]"
        Printer.pp_term t1
        Printer.pp_relation r
        Printer.pp_term t2
    in
    Constraints.raise_error msg ctxt

(** [visit_quantif_relations ~is_forall ctxt p] traverses the predicate [p] of
    the quantification being analyzed in the context [ctxt] from left to right
    as long as the predicate is [Pimplies], [Pand] or [Prel(Rlt | Rle)], and
    calls [extract_constraint] on each relation [Rlt] or [Rle] it encounters
    until all the guards of the quantification have been found or the predicate
    is finished. If [is_forall] is [true] then the predicate being traversed is
    a universal quantification, otherwise it is an existential quantification.
    The function returns a tuple [ctxt, goal_opt] where [ctxt] is the
    quantification context and [goal_opt] is either [None] if the goal of the
    quantification has not been found yet or [Some goal] if [goal] is the
    predicate corresponding to the goal of the quantification.
    @raises Typing_error if the predicate contains something other than
    [Pimplies], [Pand] or [Prel] with a relation that is neither [Rlt] nor
    [Rle]. *)
let rec visit_quantif_relations ~is_forall ctxt p =
  match p.pred_content with
  | Pimplies(lhs, rhs) ->
    let ctxt, _ = visit_quantif_relations ~is_forall ctxt lhs in
    if is_forall then begin
      if Constraints.has_unguarded_bounded_vars ctxt then
        visit_quantif_relations ~is_forall ctxt rhs
      else
        ctxt, Some rhs
    end else
      let msg =
        Format.asprintf
          "@[invalid quantification guard, expecting '%s' to continue@ \
           bounding variables,@ found '%s'@]"
          (if Kernel.Unicode.get () then Utf8_logic.conj else "&&")
          (if Kernel.Unicode.get () then Utf8_logic.implies else "==>")
      in
      Constraints.raise_error msg ctxt
  | Pand(lhs, rhs) ->
    let ctxt, _ = visit_quantif_relations ~is_forall ctxt lhs in
    if Constraints.has_unguarded_bounded_vars ctxt then
      visit_quantif_relations ~is_forall ctxt rhs
    else if not is_forall then
      ctxt, Some rhs
    else
      let msg =
        Format.asprintf
          "@[invalid quantification predicate, expecting '%s' to@ \
           separate the hypotheses from the goal, found '%s'@]"
          (if Kernel.Unicode.get () then Utf8_logic.implies else "==>")
          (if Kernel.Unicode.get () then Utf8_logic.conj else "&&")
      in
      Constraints.raise_error msg ctxt
  | Prel((Rlt | Rle) as r, t1, t2) ->
    let ctxt = extract_constraint ctxt t1 r t2 in
    ctxt, None
  | Prel _ ->
    Constraints.raise_error_invalid_pred ~warn_rel:true p ctxt
  | _ ->
    Constraints.raise_error_invalid_pred p ctxt

(** [compute_quantif_guards ~is_forall quantif bounded_vars p] computes the
    guards for the bounded variables [bounded_vars] of the quantification
    [quantif] from the predicate [p]. If [is_forall] is [true] then [quantif] is
    a universal quantification, otherwise [quantif] is an existential
    quantification.
    The function returns the list of guards for the variables and the goal
    predicate of the quantification. *)
let compute_quantif_guards ~is_forall quantif bounded_vars p =
  (* Traverse the predicate of the quantification to extract the guards of the
     bounded variables. *)
  let ctxt = Constraints.empty quantif bounded_vars in
  let ctxt, goal = visit_quantif_relations ~is_forall ctxt p in
  (* Check the validity of the result of the traversal. *)
  Constraints.check_validity ctxt;
  if Option.is_none goal then
    let msg =
      Format.asprintf
        "@[no goal found in quantification@ %a@]"
        Printer.pp_predicate quantif
    in
    Error.untypable msg
  else
    (* Traversal is valid, the guards and the goal can be retrieved and
       returned. *)
    let guards = Constraints.retrieve_guards ctxt in
    let goal = Option.get goal in
    guards, goal

let () = Typing.compute_quantif_guards_ref := compute_quantif_guards

(* It could happen that the bounds provided for a quantified [lv] are empty
   in the sense that [min <= lv <= max] but [min > max]. In such cases, \true
   (or \false depending on the quantification) should be generated instead of
   nested loops.
   [has_empty_quantif_with_false_negative] partially detects such cases:
   Case 1: an empty quantification was detected for sure, return true.
   Case 2: we don't know, return false. *)
let rec has_empty_quantif_with_false_negative = function
  | [] ->
    (* case 2 *)
    false
  | (t1, rel1, _, rel2, t2) :: guards ->
    let iv1 = Interval.(extract_ival (infer t1)) in
    let iv2 = Interval.(extract_ival (infer t2)) in
    let lower_bound, _ = Ival.min_and_max iv1 in
    let _, upper_bound = Ival.min_and_max iv2 in
    match lower_bound, upper_bound with
    | Some lower_bound, Some upper_bound ->
      let res =
        match rel1, rel2 with
        | Rle, Rle -> Integer.gt lower_bound upper_bound
        | Rle, Rlt | Rlt, Rle -> Integer.ge lower_bound upper_bound
        | Rlt, Rlt -> Integer.ge lower_bound (Z.sub upper_bound Z.one)
        | _ -> assert false
      in
      res (* case 1 *) || has_empty_quantif_with_false_negative guards
    | None, _ | _, None ->
      has_empty_quantif_with_false_negative guards

module Label_ids =
  State_builder.Counter(struct let name = "E_ACSL.Label_ids" end)

let convert kf env loc ~is_forall quantif bounded_vars p =
  (* guarded quantification over integers (or a subtype of integer) *)
  let guards, goal = compute_quantif_guards ~is_forall quantif bounded_vars p in
  match has_empty_quantif_with_false_negative guards, is_forall with
  | true, true ->
    Cil.one ~loc, env
  | true, false ->
    Cil.zero ~loc, env
  | false, _ ->
    begin
      (* create different "initial value", "found value" and guard expression
         for the predicate depending on the type of quantification *)
      let init_val, found_val, mk_guard =
        let z = zero ~loc in
        let o = one ~loc in
        if is_forall then o, z, fun x -> x
        else z, o, fun e -> new_exp ~loc:e.eloc (UnOp(LNot, e, intType))
      in
      (* transform [guards] into [lscope_var list],
         and update logic scope in the process *)
      let lvs_guards, env = List.fold_right
          (fun (t1, rel1, lv, rel2, t2) (lvs_guards, env) ->
             let lvs = Lscope.Lvs_quantif(t1, rel1, lv, rel2, t2) in
             let env = Env.Logic_scope.extend env lvs in
             lvs :: lvs_guards, env)
          guards
          ([], env)
      in
      let var_res, res, env =
        (* variable storing the result of the quantifier *)
        let name = if is_forall then "forall" else "exists" in
        Env.new_var
          ~loc
          ~name
          env
          kf
          None
          intType
          (fun v _ ->
             let lv = var v in
             [ Smart_stmt.assigns ~loc ~result:lv init_val ])
      in
      let end_loop_ref = ref dummyStmt in
      (* innermost block *)
      let mk_innermost_block env =
        (* innermost loop body: store the result in [res] and go out according
           to evaluation of the goal *)
        let named_predicate_to_exp = !predicate_to_exp_ref in
        let test, env = named_predicate_to_exp kf (Env.push env) goal in
        let then_blk = mkBlock [ mkEmptyStmt ~loc () ] in
        let else_blk =
          (* use a 'goto', not a simple 'break' in order to handle 'forall' with
             multiple binders (leading to imbricated loops) *)
          mkBlock
            [ Smart_stmt.assigns ~loc ~result:(var var_res) found_val;
              mkStmt ~valid_sid:true (Goto(end_loop_ref, loc)) ]
        in
        let blk, env =
          Env.pop_and_get
            env
            (Smart_stmt.if_stmt ~loc ~cond:(mk_guard test) then_blk ~else_blk)
            ~global_clear:false
            Env.After
        in
        let blk = Cil.flatten_transient_sub_blocks blk in
        [ Smart_stmt.block_stmt blk ], env
      in
      let stmts, env =
        Loops.mk_nested_loops ~loc mk_innermost_block kf env lvs_guards
      in
      let env =
        Env.add_stmt env kf (Smart_stmt.block_stmt (mkBlock stmts))
      in
      (* where to jump to go out of the loop *)
      let end_loop = mkEmptyStmt ~loc () in
      let label_name = "e_acsl_end_loop" ^ string_of_int (Label_ids.next ()) in
      let label = Label(label_name, loc, false) in
      end_loop.labels <- label :: end_loop.labels;
      end_loop_ref := end_loop;
      let env = Env.add_stmt env kf end_loop in
      res, env
    end

let quantif_to_exp kf env p =
  let loc = p.pred_loc in
  match p.pred_content with
  | Pforall(bounded_vars, ({ pred_content = Pimplies(_, _) } as p')) ->
    convert kf env loc ~is_forall:true p bounded_vars p'
  | Pforall _ -> Error.not_yet "unguarded \\forall quantification"
  | Pexists(bounded_vars, ({ pred_content = Pand(_, _) } as p')) ->
    convert kf env loc ~is_forall:false p bounded_vars p'
  | Pexists _ -> Error.not_yet "unguarded \\exists quantification"
  | _ -> assert false

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
