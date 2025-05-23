(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

let dkey = Options.Dkey.inductive

module Vars = struct
  include Logic_var.Set

  let of_list l = of_seq @@ List.to_seq l
  let unions = List.fold_left union empty
end

include struct (* auxiliary functions *)

  let li_use_updater lv li = object
    inherit Visitor.frama_c_inplace
    method! vlogic_info_use {l_var_info = lv'} =
      if Logic_var.equal lv lv' then ChangeTo li else DoChildren
  end

  let li_use_finder ~res ~lv_rec = object
    inherit Visitor.frama_c_inplace
    method! vlogic_info_use li =
      if Logic_var.equal lv_rec li.l_var_info
      then (res := true; SkipChildren)
      else DoChildren
  end

  let predicate_has_rec_occurrence ~lv_rec p =
    let res = ref false in
    let _ = Visitor.visitFramacPredicate (li_use_finder ~res ~lv_rec) p in
    !res

  let rec extract_foralls = function
    | {pred_content = Pat (p', labels)} as p ->
      let qs, p'' = extract_foralls p' in
      qs, {p with pred_content = Pat (p'', labels)}
    | {pred_content = Pforall (qs, p)} ->
      let qs', p' = extract_foralls p in
      Vars.union (Vars.of_list qs) qs', p'
    | p -> Vars.empty, p

  let without_foralls p = snd @@ extract_foralls p

  let var_of_term t = match t.term_node with
    | TLval (TVar v, TNoOffset) -> Some v
    | _ -> None

  let pp_logic_info fmt li =
    Printer.pp_global_annotation fmt (Dfun_or_pred (li, Location.unknown))

  let freshen_up_logic_var lv = {lv with lv_id = Cil_const.new_raw_id ()}

  let substitute old_profile new_profile =
    let formal_substitutions =
      Logic_var.Map.of_seq @@ List.to_seq @@ List.combine old_profile new_profile
    in
    object
      inherit Visitor.frama_c_inplace

      method! vlogic_var_use lv =
        match Logic_var.Map.find_opt lv formal_substitutions with
        | None -> DoChildren
        | Some lv' -> ChangeTo lv'
    end

  let free_vars = Cil.extract_free_logicvars_from_term
  let free_vars_pred = Cil.extract_free_logicvars_from_predicate
end (* auxiliary functions *)

let is_inductive = function {l_body = LBinductive _; _} -> true | _ -> false

exception Unsupported (* predicate form not supported *)

let unsupported ?loc x y z =
  Options.feedback ~dkey ?source:(Option.map fst loc) x y z;
  raise Unsupported


(* There are two translation modes, complete and incomplete:
   The complete mode [Complete] serves to generate logic predicates.
   The incomplete mode [Incomplete i] serves to generate logic functions.
   There, [i] designates the argument representing the computed function's
   result. For now [i] is always the last argument, but it will not necessarily
   be the case in the future. *)
type mode = Complete | Incomplete of int

module Mode : sig
  type t = mode

  val compare : t -> t -> int
  val pretty : Format.formatter -> t -> unit
  val to_int : t -> int

  val in_out_args : mode:t -> 'a list -> 'a list * 'a option
  val out_arg : mode:t -> 'a list -> 'a option
  val incomplete_in_out_args : mode:int -> 'a list -> 'a list * 'a
  val select_mode : usable_vars:Vars.t -> li:logic_info -> term list -> t list -> t
  val all_modes : li:logic_info -> t list
end = struct
  type t = mode

  (** We express by the comparison a preference for complete over incomplete
      extractions, and it the case of the latter a preference for the highest
      index possible for the result argument. *)
  let compare x y = match x, y with
    | Complete, Complete -> 0
    | Complete, _ -> -1
    | _, Complete -> 1
    | Incomplete i, Incomplete j -> compare j i

  let to_int = function
    | Complete -> 0
    | Incomplete m -> m

  let preferred_opt modes =
    match List.sort compare modes with
    | m :: _ -> Some m
    | [] -> None

  let preferred ~li modes =
    match preferred_opt modes with
    | Some m -> m
    | None -> unsupported "no valid mode found for: %a" Printer.pp_logic_info li

  let pretty fmt = function
    | Complete -> Format.pp_print_string fmt "complete"
    | Incomplete i -> Format.fprintf fmt "incomplete in %d" i

  let list_fold_lefti f init l =
    snd @@ List.fold_left
      (fun (i, acc) x -> succ i, f acc i x)
      (0, init)
      l

  let in_out_args ~mode args =
    list_fold_lefti
      (fun (in_arg, out_arg) i arg ->
         if mode = Incomplete (i + 1)
         then in_arg, Some arg
         else in_arg @ [arg], out_arg)
      ([], None)
      args

  let out_arg ~mode args = snd @@ in_out_args ~mode args

  let incomplete_in_out_args ~mode:i args =
    let in_args, out_arg = in_out_args ~mode:(Incomplete i) args in
    in_args, Option.get out_arg

  let all_modes ~li =
    Complete :: List.mapi (fun i _ -> Incomplete (i + 1)) li.l_profile

  let select_mode ~usable_vars ~li args modes =
    let check_mode mode =
      let in_args, _ = in_out_args ~mode args in
      let fvs = Vars.unions @@ List.map free_vars in_args in
      Vars.subset fvs usable_vars
    in
    let usable_modes = List.filter check_mode modes in
    preferred ~li usable_modes
end

(** [Modus.t] is a [mode] enriched with a set of substitutees. When the mode
    analysis of a constructor finishes by descending to its conclusion, the
    mode is determined. At that point also the set of variables that are to be
    to be substituted by the new predicate's/function's formal parameters is
    known. This information is retained along with the mode as it is useful to
    re-use by the normalization. *)
module Modus : sig
  type t = {mode : mode; substitutees : Vars.t}

  val pretty : Format.formatter -> t -> unit

  val unions : t list -> t
  val preferred_opt : t list -> t option
  val preferred : li:logic_info -> t list -> t
end = struct
  type t = {mode : mode; substitutees : Vars.t}

  let compare {mode = m1} {mode = m2} = Mode.compare m1 m2

  let unions = function
    | [] -> Options.fatal "Modus.unions []"
    | {mode} :: _ as modi ->
      assert (List.for_all (fun m -> m.mode = mode) modi);
      {mode;
       substitutees = Vars.unions @@ List.map (fun m -> m.substitutees) modi}

  let preferred_opt modes =
    match List.sort compare modes with
    | m :: _ -> Some m
    | [] -> None

  let preferred ~li modes =
    match preferred_opt modes with
    | Some m -> m
    | None -> unsupported "no valid mode found for: %a" Printer.pp_logic_info li

  let pretty fmt {mode; substitutees} =
    Format.fprintf fmt "%a%a"
      Mode.pretty mode
      Vars.pretty substitutees
end

module rec Constructor : sig
  type t = {
    name : string;
    labels : logic_label list;
    poly_id : string list;
    predicate : predicate
  }

  val analyze_mode : lv_rec:logic_var -> predicate -> mode -> Modus.t option
  (** determine whether [mode] is a viable mode for predicate [p]. [lv_rec] is
      the inductive definition of the [p]'s constructor. *)

  val normalize : li_rec:logic_info -> mode:Modus.t -> t -> t
  (* The result is a valid inductive definition except for the fact that all
     the cases are quantified over the same set of variables, i.e. the formal
     parameters of the predicate/function being defined.
     In addition to those quantifiers a case may additional quantifiers proper
     to itself for each variable that a \let binding is to be generated for. *)

end = struct
  type t = {
    name : string;
    labels : logic_label list;
    poly_id : string list;
    predicate : predicate (* generalized Horn clauses *)
  }

  (* Equalities are a collection of substitutions and equations, generated by
     the normalization. Substitutions are generated when arguments of the
     conclusion are quantified variables that will be substituted by the
     corresponding formal parameters. When such a substitution already exists an
     equation is generated instead. Example: \forall ℤ a; ... ==> add(a, 0, a);
     Otherwise equations come from constants as for the second parameter here. *)
  module Equalities = struct
    type t = {substitutions : logic_var Logic_var.Map.t;
              equations : (term * term) list}

    let empty = {substitutions = Logic_var.Map.empty; equations = []}

    let pp_substitution fmt (v, t) =
      Format.fprintf fmt "@[@[%a@] %t @[%a@]@]"
        Printer.pp_logic_var v
        Unicode.pp_right_arrow
        Printer.pp_logic_var t

    let pp_equation fmt (t1, t2) =
      Format.fprintf fmt "@[@[%a@] %t @[%a@]@]"
        Printer.pp_term t1
        Unicode.pp_eq
        Printer.pp_term t2

    let pretty fmt {substitutions = subs; equations} =
      Pretty_utils.pp_list ~sep:"@;<2>" pp_substitution fmt (Logic_var.Map.bindings subs);
      if equations <> [] then Format.fprintf fmt "@;<2>";
      Pretty_utils.pp_list ~sep:"@;<2>" pp_equation fmt equations

    let add_equation eq eqs =
      Options.debug ~dkey ~level:6 "adding equation %a" pp_equation eq;
      {eqs with equations = eq :: eqs.equations}

    let add_substitution ~loc eqs (orig, by) =
      Options.debug ~dkey ~level:6 "adding substitution %a" pp_substitution (orig, by);
      match Logic_var.Map.find_opt orig eqs.substitutions with
      | Some substitute2 ->
        let t1 = Logic_const.tvar ~loc by in
        let t2 = Logic_const.tvar ~loc substitute2 in
        add_equation (t1, t2) eqs
      | None -> {eqs with substitutions = Logic_var.Map.add orig by eqs.substitutions}

    let apply_equations ~eqs p =
      List.fold_left
        (fun p (lhs, rhs) ->
           let eq = Logic_const.prel ~loc:lhs.term_loc (Req, lhs, rhs) in
           {eq with pred_content = Pimplies (eq, p)})
        p
        eqs.equations

    let apply_substitutions =
      let solution_applier substs = object
        inherit Visitor.frama_c_inplace
        method !vterm t = match var_of_term t with
          | None -> DoChildren
          | Some v ->
            try ChangeTo (Logic_const.tvar @@ Logic_var.Map.find v substs)
            with Not_found -> DoChildren
      end in
      fun substs -> Visitor.visitFramacPredicate (solution_applier substs)
  end

  let analyze_mode ~lv_rec p mode =
    let is_rec_occurrence li = Logic_var.equal li.l_var_info lv_rec in
    (* fv: free variables that have been used up to the current point *)
    (* they will need to be substituted for in the conclusion unless they have
       been let-bound. *)
    (* lb: (future) let-bound variables; do not add variables that have already
       been used before. *)
    let rec test_mode ~lb ~fv p =
      let recurse ?(lb = lb) ?(fv=fv) = test_mode ~lb ~fv in
      let add_fv fv terms = Vars.unions @@ fv :: List.map free_vars terms in
      Options.debug ~dkey ~level:5 "test_mode@ ~lb:%a ~fv:%a@ ~mode:%a@ %a"
        Vars.pretty lb
        Vars.pretty fv
        Mode.pretty mode
        Printer.pp_predicate p;
      let predicate_call ~mode args pr =
        let in_args, out_arg = Mode.in_out_args ~mode args in
        let fv = add_fv fv in_args in
        let lb = match Option.bind var_of_term out_arg with
          | Some v -> if Vars.mem v fv then lb else Vars.add v lb
          | None -> lb
        in
        let fv = match out_arg with Some a -> Vars.union fv (free_vars a) | None -> fv in
        recurse ~lb ~fv pr
      in
      match p.pred_content with
      | Pimplies ({pred_content = Pand (p1, p2)} as pl, pr)
        when predicate_has_rec_occurrence ~lv_rec pl ->
        (* treat  p ∧ q ⇒ r  as  p ⇒ q ⇒ r *)
        let pl' = {pl with pred_content = Pimplies (p2, pr)} in
        let p' = {p with pred_content = Pimplies (p1, pl')} in
        recurse p'
      | Pimplies ({pred_content = Papp (li, _, args)}, pr) when is_rec_occurrence li ->
        predicate_call ~mode args pr
      | Pimplies (pl, _) when predicate_has_rec_occurrence ~lv_rec pl ->
        unsupported ~loc:p.pred_loc
          "deep recursive occurrence of %a in incomplete mode"
          Printer.pp_logic_var lv_rec;
      | Pimplies ({pred_content = Papp (li, _, args)}, pr) when is_inductive li -> (* foreign predicate *)
        let try_with_mode {Modus.mode = m} = predicate_call ~mode:m args pr in
        let modi = List.filter_map try_with_mode (InductiveDefinition.analyze_modes li) in
        Modus.preferred_opt modi
      | Pimplies (pl, pr) -> (* simple hypothesis *)
        let fv = Vars.union fv @@ free_vars_pred pl in
        recurse ~fv pr
      | Plet ({l_var_info = v; l_body = LBterm t}, pin) ->
        recurse ~lb:(Vars.add v lb) ~fv:(add_fv fv [t]) pin
      | Plet (_,_) ->
        unsupported ~loc:p.pred_loc
          "only \\let expressions that bind terms are supported, not: %a"
          Printer.pp_predicate p
      | Papp (li, _, args) when is_rec_occurrence li -> (* conclusion *)
        let in_args, _ = Mode.in_out_args ~mode:mode args in
        let fv = add_fv fv args in
        let substitutees = Vars.diff (Vars.of_list @@ List.filter_map var_of_term in_args) lb in
        let unbound = Vars.diff (Vars.diff fv substitutees) lb in
        let all_bound = Vars.is_empty unbound in
        if not all_bound then
          Options.feedback ~dkey ~level:4
            "mode %a could not bind: %a"
            Mode.pretty mode
            Vars.pretty unbound;
        if all_bound
        then Some {Modus.mode; substitutees}
        else None
      | Papp _ ->
        unsupported ~loc:p.pred_loc
          "conclusion not an occurrence of the enclosing predicate: %a"
          Printer.pp_predicate p
      | Pat (p, _label) -> recurse p
      | _ ->
        unsupported ~loc:p.pred_loc
          "unexpected element: %a"
          Printer.pp_predicate p
    in
    try test_mode ~lb:Vars.empty ~fv:Vars.empty (without_foralls p)
    with Unsupported ->
      unsupported ~loc:p.pred_loc
        "unsupported form: %a"
        Printer.pp_predicate p

  let pretty fmt {name; predicate} =
    Format.fprintf fmt "%s: @[%a@]" name Printer.pp_predicate predicate

  let normalize ~li_rec ~mode ({predicate} as ctor) =
    Options.debug ~dkey ~level:3 "normalizing constructor:@ %a" pretty ctor;
    let is_rec_occurrence li = Logic_info.equal li li_rec in
    let eqs = ref Equalities.empty in
    let rec normalize_body ~uv p =
      (* Descend to the conclusion keeping track of usable variables (uv);
         initially these are the variables that are to be substituted by the
         formal parameters of the new predicate/function; \let-bindings and
         recursive hypotheses that bind variables add variables to this set.
         At the conclusion substitutions and equations are generated. Equations
         are added before the conclusion, while substitutions are applied at
         the top-level. *)
      let recurse ?(uv = uv) = normalize_body ~uv in
      match p.pred_content with
      | Plet ({l_var_info = v; l_body = LBterm _} as li, pin) ->
        let pin = recurse ~uv:(Vars.add v uv) pin in
        {p with pred_content = Plet (li, pin)}
      | Pimplies ({pred_content = Pand (p1, p2)} as pl, pr)
        when predicate_has_rec_occurrence ~lv_rec:li_rec.l_var_info pl ->
        let pl' = {pl with pred_content = Pimplies (p2, pr)} in
        let p' = {p with pred_content = Pimplies (p1, pl')} in
        recurse p'
      | Pimplies ({pred_content = Papp (li, _, args)} as pl, pr) when
          is_rec_occurrence li ->
        let uv = match Option.bind var_of_term @@ Mode.out_arg ~mode:mode.Modus.mode args with
          | Some v -> Vars.add v uv
          | None -> uv
        in
        {p with pred_content = Pimplies (pl, recurse ~uv pr)}
      | Pimplies ({pred_content = Papp (li, _, args)} as pl, pr) when
          is_inductive li -> (* foreign predicate *)
        let mode' =
          let all_modes = List.map
              (fun m -> m.Modus.mode)
              (InductiveDefinition.analyze_modes li)
          in
          Mode.select_mode ~usable_vars:uv ~li args all_modes
        in
        let out_arg = Mode.out_arg ~mode:mode' args in
        let uv = match Option.bind var_of_term out_arg with
          | Some v -> Vars.add v uv
          | None -> uv
        in
        {p with pred_content = Pimplies (pl, recurse ~uv pr)}
      | Pimplies (pl, pr) -> (* simple hypothesis *)
        {p with pred_content = Pimplies (pl, recurse pr)}
      | Pat (p', labels) ->
        let p' = recurse p' in
        {p' with pred_content = Pat (p', labels)}
      | Papp (li, labels, args) when is_rec_occurrence li -> (* conclusion *)
        let normalize_arg i arg =
          let formal = List.nth li.l_profile i in
          match mode.mode with
          | Incomplete i' when i = i' - 1 -> arg
          | _ ->
            let loc = arg.term_loc in
            let t = Logic_const.tvar ~loc formal in
            let () =
              (* after successful mode analysis any argument not in result
                 position is either a normal (not future let-bound) quantified
                 variable or a constant. *)
              match var_of_term arg with
              | Some v -> eqs :=
                  Equalities.add_substitution ~loc !eqs (v, formal)
              | None -> eqs := Equalities.add_equation (t, arg) !eqs
            in
            t
        in
        let new_args = List.mapi normalize_arg args in
        Options.debug ~dkey ~level:5
          "equations/substitutions generated from conclusion: %a"
          Equalities.pretty !eqs;
        Equalities.apply_equations ~eqs:!eqs
          {p with pred_content = Papp (li, labels, new_args)}
      | _ ->
        Options.fatal
          "rewrite_conclusion_and_get_original_args_and_collect_equations %a"
          Printer.pp_predicate p
    in
    let quantifiers, body = extract_foralls predicate in
    let body = normalize_body ~uv:mode.substitutees body in
    let body = Equalities.apply_substitutions !eqs.substitutions body in
    let profile, _ = Mode.in_out_args ~mode:mode.mode li_rec.l_profile in
    let quantifiers =
      profile @ Vars.elements (Vars.diff quantifiers mode.substitutees)
    in
    let quantified =
      {predicate with pred_content = Pforall (quantifiers, body)}
    in
    let res = {ctor with predicate = quantified} in
    Options.debug ~dkey ~level:3 "normalized constructor:@ %a" pretty res;
    res
end

and InductiveDefinition : sig
  val ctors_of_inductive : logic_info -> Constructor.t list
  val analyze_modes : logic_info -> Modus.t list (* memoized *)
  val normalize : mode:Modus.t -> logic_info -> logic_info
  val clear : unit -> unit
end = struct (* internal representation of inductives *)
  let inductive_of_ctors ctors =
    let of_ctor {Constructor.name; labels; poly_id; predicate} =
      name, labels, poly_id, predicate
    in
    LBinductive (List.map of_ctor ctors)

  let ctors_of_inductive li =
    let make (name, labels, poly_id, lemma) =
      {Constructor.name; labels; poly_id; predicate = lemma}
    in
    match li.l_body with
    | LBinductive ctors -> List.map make ctors
    | _ -> Options.fatal "not an inductive definition:@ @[%a@]" Printer.pp_logic_info li

  let memo_tbl = Logic_info.Hashtbl.create 9
  let clear () = Logic_info.Hashtbl.clear memo_tbl

  let analyze_constructor ~li mode {Constructor.predicate = p} =
    Constructor.analyze_mode ~lv_rec:li.l_var_info p mode

  let analyze_modes li = Logic_info.Hashtbl.memo memo_tbl li @@ fun li ->
    let ctors = ctors_of_inductive li in
    Options.debug ~dkey ~level:4
      "@[<2>performing mode analysis on inductive:@ @[%a@]@]"
      pp_logic_info li;
    let try_mode mode =
      let exception Analysis_failed in
      let analyze_const ctor =
        match analyze_constructor ~li mode ctor with
        | Some modus -> modus
        | None -> raise Analysis_failed
      in
      try
        let modi = List.map analyze_const ctors in
        Some (Modus.unions modi)
      with Analysis_failed -> None
    in
    let modes = List.filter_map try_mode (Mode.all_modes ~li) in
    Options.debug ~dkey ~level:3 "possible modes for %a: %a"
      Printer.pp_logic_info li
      (Pretty_utils.pp_list ~sep:", " Mode.pretty) (List.map (fun {Modus.mode} -> mode) modes);
    modes

  let normalize ~mode li =
    Options.debug ~dkey ~level:3 "normalizing %a with modus %a"
      Logic_info.pretty li
      Modus.pretty mode;
    let ctors =
      List.map
        (Constructor.normalize ~li_rec:li ~mode)
        (ctors_of_inductive li)
    in
    {li with l_body = inductive_of_ctors ctors}
end

(* In order to be able to share the code for the extraction of logic functions
   and of predicates, we define a module type [Out_language] that contains
   shared smart constructors for generating predicates as well as terms. *)
module type Out_language = sig
  include Build_pred_or_term.S
  val mk_concl : mode:mode -> term list -> t
end

(* Here we store terms that we use as a fallthrough result of logic functions
   we generate. When an inductive or axiomatic definition is incomplete, then
   it will return such a fallthrough value. In the translation to CIL this term
   will become a failing assertion. *)
module Fallthrough_terms : sig
  val mem : term -> bool
  val add : term -> unit
  val clear : unit -> unit
end = struct
  open Misc.Id_term.Hashtbl
  let tbl = create 9
  let mem = mem tbl
  let add t = add tbl t ()
  let clear () = clear tbl
end

let is_fallthrough_term = Fallthrough_terms.mem

module Derived_functions = struct
  open Logic_info.Hashtbl
  let tbl = create 9
  let add = add tbl
  let iter f = iter f tbl
  let clear () = clear tbl
end

(* In this implementation the extraction of logic functions is unsound. If
   multiple cases apply for some given arguments the verdict may be wrong.
   So we record here predicates that depend on logic functions. *)
module Unsound_predicates = struct
  open Logic_info.Hashtbl
  let tbl = create 9
  let add li = add tbl li ()
  let mem = mem tbl
  let clear () = clear tbl
end

module Extractions = struct
  open Datatype.Pair_with_collections (Logic_info) (Datatype.Int)
  let tbl = Hashtbl.create 9
  let clear () = Hashtbl.clear tbl
  let memo ~mode li f =
    let m = Mode.to_int mode in
    Hashtbl.memo tbl
      (li, m)
      (fun (li, _) -> f ~mode li)
  let find ~mode li = Hashtbl.find tbl (li, Mode.to_int mode)
  let get ~mode li = try find ~mode li with Not_found -> li
end

module rec Make_extractor : functor (Out : Out_language) -> sig
  val extract : ?name:string -> mode:mode -> logic_info -> logic_info
end = functor (Out : Out_language) -> struct

  let extract ?name ~mode li = Extractions.memo ~mode li @@ fun ~mode li ->
    let li_rec = li in
    Options.debug ~dkey ~level:2
      "@[<2>extracting data from inductive using mode %a:@ @[%a@]@]"
      Mode.pretty mode pp_logic_info li;
    let modus = List.find
        (fun m -> m.Modus.mode = mode)
        (InductiveDefinition.analyze_modes li)
    in
    let li = InductiveDefinition.normalize ~mode:modus li in
    let new_profile = List.map freshen_up_logic_var li.l_profile in
    let li = Visitor.visitFramacLogicInfo (substitute li.l_profile new_profile) li in
    let li = {li with l_profile = new_profile} in
    Options.debug ~dkey ~level:2
      "@[<2>after normalization:@ @[%a@]@]" pp_logic_info li;
    let l_profile, res = Mode.in_out_args ~mode li.l_profile in
    let formals = Vars.of_list l_profile in
    let l_type = Option.map (fun l -> l.lv_type) res in
    let is_rec_occurrence li' = Logic_var.equal li'.l_var_info li.l_var_info in
    let extract_ctor (ctor : Constructor.t) next_ctor =
      let flush_conds ~conds case_true = match conds with
        | [] -> case_true
        | c::cs ->
          let cond =
            List.fold_right (fun p q -> Logic_const.pand ~loc:q.pred_loc (p,q)) cs c
          in
          Out.mk_if ~loc:cond.pred_loc cond case_true next_ctor
      in
      let rec compile ~lb ~conds p =
        let recurse ?(lb = lb) ?(conds = conds) =
          (* conds : gathered hypotheses *)
          compile ~lb ~conds in
        match p.pred_content with
        | Papp (li, _, args) when is_rec_occurrence li -> (* conclusion *)
          let case_true = Out.mk_concl ~mode args in
          flush_conds ~conds case_true
        | Plet (li, p) ->
          if Vars.mem li.l_var_info lb then
            unsupported "logic variable %a is bound multiple times"
              Printer.pp_logic_var li.l_var_info;
          let c = recurse ~conds:[] ~lb:(Vars.add li.l_var_info lb) p in
          flush_conds ~conds (Out.mk_let ~loc:p.pred_loc li c)
        | Pimplies ({pred_content = Papp (li, labels, args)} as pl, pr)
          when is_rec_occurrence li || is_inductive li ->
          let in_out_args, li =
            if is_rec_occurrence li
            then Mode.in_out_args ~mode args, li
            else (* foreign predicate *)
              let mode' =
                let usable_vars = Vars.union formals lb in
                let available_modes = List.map
                    (fun m -> m.Modus.mode)
                    (InductiveDefinition.analyze_modes li)
                in
                Mode.select_mode ~usable_vars ~li args available_modes
              in
              Mode.in_out_args ~mode:mode' args,
              match mode' with
              | Complete -> Extractions.get ~mode:Complete li
              | _ ->
                Unsound_predicates.add li_rec;
                FunctionExtractor.extract ~mode:mode' li
          in
          begin match in_out_args with
            | _, None -> (* complete mode *)
              let pl = {pl with pred_content = Papp (li, labels, args)} in
              recurse ~conds:(pl :: conds) pr
            | args, Some res ->
              let rec_call =
                Logic_const.term ~loc:p.pred_loc (Tapp (li, labels, args)) res.term_type
              in
              match var_of_term res with
              | Some v when not @@ Vars.mem v lb ->
                let li = {(Cil_const.make_logic_info_local v.lv_name)
                          with l_var_info = v;
                               l_body = LBterm rec_call;
                               l_type = Some res.term_type}
                in
                recurse ~conds (Logic_const.plet ~loc:p.pred_loc li pr)
              | _ ->
                let p = Logic_const.prel (Req, rec_call, res) in
                recurse ~conds:(p :: conds) pr
          end
        | Pimplies (pl, pr) -> recurse ~conds:(pl :: conds) pr
        | Pat (p', labels) -> Out.mk_at labels @@ recurse p'
        | _ -> (* should have been caught in mk_ctor *)
          Options.fatal "unexpected predicate in extraction:@ %a"
            Printer.pp_predicate p
      in
      compile ~lb:Vars.empty ~conds:[] @@ without_foralls ctor.predicate
    in
    let body =
      let falltrough = Out.mk_false l_type in
      List.fold_right
        extract_ctor
        (InductiveDefinition.ctors_of_inductive li)
        falltrough
    in
    let li = {li with l_profile; l_type} in
    li.l_body <- Out.mk_logic_body @@ Out.visit (li_use_updater li.l_var_info li) body;
    li.l_var_info <- freshen_up_logic_var li.l_var_info;
    let () = match res with
      | Some res -> (* incomplete mode: change lv_type into function type *)
        let rev = List.map (fun vi -> vi.lv_type) li.l_profile in
        li.l_var_info.lv_type <- Larrow (rev, res.lv_type)
      | None -> ()
    in
    let old_name = li.l_var_info.lv_name in
    Option.iter (fun n -> li.l_var_info.lv_name <- n) name;
    Options.feedback ~dkey ~level:2
      "@[<2>extracted from inductive definition of %s executable definition:@ @[%a@]@]"
      old_name
      pp_logic_info li;
    li
end

and FunctionExtractor : sig
  val extract : mode:mode -> logic_info -> logic_info
end = struct
  module Extractor = Make_extractor (struct
      include Build_pred_or_term.Term

      let mk_false lty =
        let t = mk_false lty in
        Fallthrough_terms.add t;
        t

      let mk_concl ~mode args =
        match Mode.out_arg ~mode args with
        | Some t -> t
        | None -> assert false (* necessarily in incomplete mode *)
    end)

  let extract_with_mode ~mode:m li =
    Options.debug ~dkey "function extraction with mode incomplete in %d" m;
    let name = li.l_var_info.lv_name ^ "_fun" ^ string_of_int m in
    let f = Extractor.extract ~name ~mode:(Incomplete m) li in
    Derived_functions.add li f;
    f

  let extract ~mode li = match mode with
    | Complete -> Options.fatal "function extraction in complete mode"
    | Incomplete m -> extract_with_mode ~mode:m li
end

module PredicateExtractor : sig
  val extract : logic_info -> logic_info
end
= struct
  module Extractor = Make_extractor (struct
      include Build_pred_or_term.Predicate
      let mk_concl ~mode:_ _ = mk_true None
    end)

  let extract_with_mode ~mode li =
    match mode.Modus.mode with
    | Complete ->
      Extractor.extract ~mode:mode.Modus.mode li
    | Incomplete i ->
      let f = FunctionExtractor.extract ~mode:mode.mode li in
      let args, res = Mode.incomplete_in_out_args ~mode:i li.l_profile in
      let args = List.map Logic_const.tvar args in
      let tapp = Logic_const.term (Tapp (f, f.l_labels, args)) res.lv_type in
      let rel = Logic_const.prel (Req, tapp, Logic_const.tvar res) in
      let wrapper = {li with l_body = LBpred rel} in
      wrapper.l_var_info <- freshen_up_logic_var li.l_var_info;
      Options.feedback ~dkey ~level:2
        "@[<2>extracted from inductive definition %a wrapper for %a:@ @[%a@]@]"
        Printer.pp_logic_info li
        Printer.pp_logic_info f
        pp_logic_info wrapper;
      Unsound_predicates.add wrapper;
      wrapper

  let extract li =
    let modi = InductiveDefinition.analyze_modes li in
    let mode = Modus.preferred ~li modi in
    extract_with_mode ~mode li
end

let extract_predicate = PredicateExtractor.extract

let is_unsound_predicate li =
  let res = Unsound_predicates.mem li in
  if res then
    Options.warning ~once:true
      "Translation of %a might be unsound (if multiple cases apply \
       to some given arguments simultaneously)."
      Printer.pp_logic_info li;
  res

let clear () =
  Fallthrough_terms.clear ();
  Extractions.clear ();
  Derived_functions.clear ();
  InductiveDefinition.clear ();
  Unsound_predicates.clear ()
