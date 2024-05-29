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

open Eval

let dkey_card = Self.register_category "cardinal"

module State = struct

  type state = Cvalue.Model.t * Locals_scoping.clobbered_set
  type value = Main_values.CVal.t
  type location = Main_locations.PLoc.location

  let value_dependencies = Main_values.cval
  let location_dependencies = Main_locations.ploc

  type context = unit
  let context_dependencies = Abstract_context.Leaf (module Unit_context)

  let log_category = Self.dkey_cvalue_domain

  include Datatype.Make_with_collections (
    struct
      include Datatype.Serializable_undefined
      type t = state
      let name = Cvalue.Model.name ^ "+clobbered_set"
      let reprs =
        List.map (fun s -> s, Locals_scoping.bottom ()) Cvalue.Model.reprs
      let structural_descr =
        Structural_descr.t_tuple
          [| Cvalue.Model.packed_descr; Locals_scoping.packed_descr |]
      let pretty fmt (s, _) = Cvalue.Model.pretty fmt s
      let equal (a, _) (b, _) = Cvalue.Model.equal a b
      let compare (a, _) (b, _) = Cvalue.Model.compare a b
      let hash (s, _) = Cvalue.Model.hash s
      let rehash = Datatype.identity
      let copy = Datatype.undefined
      let mem_project = Datatype.never_any_project
    end )

  let name = "cvalue"
  let key = Structure.Key_Domain.create_key name

  let top = Cvalue.Model.top, Locals_scoping.bottom ()
  let is_included (a, _) (b, _) = Cvalue.Model.is_included a b
  let join (a, clob) (b, _) = Cvalue.Model.join a b, clob

  let widen kf stmt (a, clob) (b, _) =
    let priority, hint = Widen.getWidenHints kf stmt in
    Cvalue.Model.widen ~priority ~hint a b, clob

  let narrow (a, clob) (b, _) =
    let s = Cvalue.Model.narrow a b in
    if Cvalue.Model.(equal bottom s) then `Bottom else `Value (s, clob)

  type origin = Cvalue_queries.origin

  let extract_expr ~oracle context (state, _) expr =
    Cvalue_queries.extract_expr ~oracle context state expr

  let extract_lval ~oracle context (state, _) lval typ loc =
    Cvalue_queries.extract_lval ~oracle context state lval typ loc

  let backward_location (state, _) lval typ precise_loc value =
    Cvalue_queries.backward_location state lval typ precise_loc value

  let reduce_further (state, _) expr value =
    Cvalue_queries.reduce_further state expr value

  let build_context (state, _) = Cvalue_queries.build_context state

  (* ------------------------------------------------------------------------ *)
  (*                            Transfer Functions                            *)
  (* ------------------------------------------------------------------------ *)

  let update valuation (s, clob) =
    Cvalue_transfer.update valuation s >>-: fun s -> s, clob

  let assign stmt lv expr assigned valuation (s, clob) =
    Cvalue_transfer.assign stmt lv expr assigned valuation s >>-: fun s ->
    (* TODO: use the value in assignment *)
    let _ =
      Eval.value_assigned assigned >>-: fun value ->
      let location = Precise_locs.imprecise_location lv.lloc in
      Locals_scoping.remember_if_locals_in_value clob location value
    in
    s, clob

  let assume stmt expr positive valuation (s, clob) =
    Cvalue_transfer.assume stmt expr positive valuation s >>-: fun s ->
    s, clob

  let is_direct_recursion stmt call =
    try
      let kf = Kernel_function.find_englobing_kf stmt in
      Kernel_function.equal kf call.kf
    with Not_found -> false (* Should not happen *)

  let start_recursive_call stmt call recursion (state, clob) =
    let direct = is_direct_recursion stmt call in
    let state = Cvalue.Model.remove_variables recursion.withdrawal state in
    let substitution = recursion.base_substitution in
    let clob = if direct then clob else Locals_scoping.top () in
    let state = Locals_scoping.substitute substitution clob state in
    Cvalue.Model.replace_base substitution state

  let start_call stmt call recursion valuation (state, clob) =
    (* Uses the [valuation] to update the [state] before the substitution
       for recursive calls. *)
    Cvalue_transfer.update valuation state >>- fun state ->
    let state =
      match recursion with
      | None -> state
      | Some recursion -> start_recursive_call stmt call recursion (state, clob)
    in
    Cvalue_transfer.start_call stmt call recursion valuation state
    >>-: fun state -> state, Locals_scoping.bottom ()

  let finalize_recursive_call stmt call ~pre recursion state =
    let direct = is_direct_recursion stmt call in
    let pre, clob = pre in
    let substitution = recursion.base_substitution in
    let state = Cvalue.Model.replace_base substitution state in
    let clob = if direct then clob else Locals_scoping.top () in
    let state = Locals_scoping.substitute substitution clob state in
    let inter = Cvalue.Model.filter_by_shape recursion.base_withdrawal pre in
    Cvalue.Model.merge ~into:state inter

  let finalize_call stmt call recursion ~pre ~post =
    let (pre, clob) = pre in
    let (post, post_clob) = post in
    Locals_scoping.(remember_bases_with_locals clob post_clob.clob);
    let finalize a =
      finalize_recursive_call stmt call ~pre:(pre, clob) a post
    in
    let post = Option.fold ~some:finalize ~none:post recursion in
    (* Deallocate memory allocated via alloca().
       To minimize computations, only do it for function definitions. *)
    let post =
      if Kernel_function.is_definition call.kf then
        let callstack = Eva_utils.current_call_stack () in
        let callstack = Callstack.push call.kf stmt callstack in
        Builtins_malloc.free_automatic_bases callstack post
      else post
    in
    Cvalue_transfer.finalize_call stmt call recursion ~pre ~post
    >>-: fun state ->
    state, clob

  let show_expr valuation (state, _) = Cvalue_transfer.show_expr valuation state

  (* ------------------------------------------------------------------------ *)
  (*                                 Mem Exec                                 *)
  (* ------------------------------------------------------------------------ *)

  let relate _kf _bases _state = Base.SetLattice.empty

  (* Auxiliary function that keeps only some bases inside a memory state *)
  let filter _kind bases (state, clob) =
    Cvalue.Model.filter_by_shape bases state, clob

  let reuse _ _ ~current_input:(state, _) ~previous_output:(output, clob) =
    Cvalue.Model.merge ~into:state output, clob

  (* ------------------------------------------------------------------------ *)
  (*                                  Logic                                   *)
  (* ------------------------------------------------------------------------ *)

  let lift_env logic_env =
    Abstract_domain.{ states = (fun label -> fst (logic_env.states label));
                      result = logic_env.result; }

  let evaluate_predicate logic_env (state, _clob) pred =
    let eval_env = Eval_terms.make_env (lift_env logic_env) state in
    match Eval_terms.eval_predicate eval_env pred with
    | Eval_terms.True -> Alarmset.True
    | Eval_terms.False -> Alarmset.False
    | Eval_terms.Unknown -> Alarmset.Unknown

  let reduce_by_predicate logic_env (state, clob) pred b =
    let eval_env = Eval_terms.make_env (lift_env logic_env) state in
    let eval_env = Eval_terms.reduce_by_predicate eval_env b pred in
    let state = Eval_terms.env_current_state eval_env in
    if Cvalue.Model.is_reachable state
    then `Value (state, clob)
    else `Bottom

  let interpret_acsl_extension _extension _env state = state

  let evaluate_from_clause state deps =
    (* Evaluates the contents of one element of the from clause, topify them,
       and add them to the current state of the evaluation in acc. *)
    let one_from_contents acc dep =
      if dep.direct
      then
        match dep.location with
        | None -> Cvalue.V.top
        | Some location ->
          let location = Precise_locs.imprecise_location location in
          let v = Cvalue.Model.find ~conflate_bottom:false state location in
          Cvalue.V.topify Origin.Leaf (Cvalue.V.join acc v)
      else acc
    in
    List.fold_left one_from_contents Cvalue.V.top_int deps

  let logic_assign logic_assign location (state, sclob) =
    match logic_assign with
    | None ->
      let location = Precise_locs.imprecise_location location
      and value = Cvalue.V.top in
      Cvalue.Model.add_binding ~exact:false state location value, sclob
    | Some (Assigns (_assign, deps), (pre_state, _)) ->
      let location = Precise_locs.imprecise_location location in
      let value = evaluate_from_clause pre_state deps in
      Locals_scoping.remember_if_locals_in_value sclob location value;
      Cvalue.Model.add_binding ~exact:false state location value, sclob
    | Some ((Frees _ | Allocates _), _) -> state, sclob

  (* ------------------------------------------------------------------------ *)
  (*                             Initialization                               *)
  (* ------------------------------------------------------------------------ *)

  let initialize_variable  _lval loc ~initialized init_value (state, clob) =
    let value = match init_value with
      | Abstract_domain.Top  -> Cvalue.V.top_int
      | Abstract_domain.Zero -> Cvalue.V.singleton_zero
    in
    let cvalue =
      if initialized
      then Cvalue.V_Or_Uninitialized.C_init_noesc value
      else Cvalue.V_Or_Uninitialized.C_uninit_noesc value
    in
    let loc = Precise_locs.imprecise_location loc in
    Cvalue.Model.add_indeterminate_binding ~exact:true state loc cvalue, clob

  let empty () =
    let open Cvalue in
    let state = Model.empty_map in
    let min_valid = Base.min_valid_absolute_address () in
    let max_valid = Base.max_valid_absolute_address () in
    if Integer.le min_valid max_valid
    then begin
      (* Bind everything between [0..max] to bottom. Offsetmaps cannot
         contain holes, which can happen when min > 0 holds. *)
      let bot =
        V_Offsetmap.create_isotropic
          ~size:max_valid (V_Or_Uninitialized.initialized V.bottom)
      in
      let v = if true (* TODO: command line option *)
        then V_Or_Uninitialized.initialized V.top_int
        else V_Or_Uninitialized.uninitialized
      in
      let offsm =
        V_Offsetmap.add
          (min_valid, max_valid) (v, Integer.one, Abstract_interp.Rel.zero) bot
      in
      Cvalue.Model.add_base Base.null offsm state, Locals_scoping.bottom ()
    end
    else state, Locals_scoping.bottom ()

  let initialize_variable_using_type kind varinfo (state, clob) =
    match kind with
    | Abstract_domain.(Global | Formal _ | Local _) ->
      Cvalue_init.initialize_var_using_type varinfo state, clob
    | Abstract_domain.Result kf ->
      let value = Library_functions.returned_value kf in
      let loc = Locations.loc_of_varinfo varinfo in
      Cvalue.Model.add_binding ~exact:true state loc value, clob

  (* ------------------------------------------------------------------------ *)
  (*                                  Misc                                    *)
  (* ------------------------------------------------------------------------ *)

  let bind_local state vi =
    let b = Base.of_varinfo vi in
    let offsm =
      if Parameters.InitializedLocals.get () then
        let v = Cvalue.(V_Or_Uninitialized.initialized V.top_int) in
        match Cvalue.V_Offsetmap.size_from_validity (Base.validity b) with
        | `Bottom -> assert false
        | `Value size -> Cvalue.V_Offsetmap.create_isotropic ~size v
      else
        Bottom.non_bottom (Cvalue.Default_offsetmap.default_offsetmap b)
    in
    Cvalue.Model.add_base b offsm state

  let bind_global state varinfo =
    let base = Base.of_varinfo varinfo in
    let loc = Locations.loc_of_base base in
    let value = Cvalue.V_Or_Uninitialized.uninitialized in
    Cvalue.Model.add_indeterminate_binding ~exact:true state loc value

  let enter_scope kind vars (state, clob) =
    let bind =
      match kind with
      | Abstract_domain.Global -> bind_global
      | Abstract_domain.(Local _ | Formal _ | Result _)  -> bind_local
    in
    List.fold_left bind state vars, clob

  let leave_scope kf vars (state, clob) =
    let state = Cvalue.Model.remove_variables vars state in
    try
      let fdec = Kernel_function.get_definition kf in
      Locals_scoping.make_escaping_fundec fdec clob vars state, clob
    with Kernel_function.No_Definition -> state, clob

  let enter_loop _stmt (s, clob) = s, clob

  let leave_loop _stmt (s, clob) = s, clob

  let incr_loop_counter _stmt (s, clob) = s, clob


  (* ------------------------------------------------------------------------ *)
  (*                                Storage                                   *)
  (* ------------------------------------------------------------------------ *)

  module Store = struct

    let register_global_state b s =
      Cvalue_results.register_global_state b (Bottom.map fst s)
    let register_initial_state callstack kf (state, _clob) =
      Cvalue_results.register_initial_state callstack kf state
    let register_state_before_stmt callstack stmt (state, _clob) =
      Cvalue_results.register_state_before_stmt callstack stmt state
    let register_state_after_stmt callstack stmt (state, _clob) =
      Cvalue_results.register_state_after_stmt callstack stmt state

    let lift_tbl tbl =
      let h = Callstack.Hashtbl.create 7 in
      let process callstack state =
        Callstack.Hashtbl.replace h callstack (state, Locals_scoping.top ())
      in
      Callstack.Hashtbl.iter process tbl;
      h

    let select ?selection tbl =
      match selection with
      | None -> tbl
      | Some list ->
        let new_tbl = Callstack.Hashtbl.create (List.length list) in
        let add cs =
          let s = Callstack.Hashtbl.find_opt tbl cs in
          Option.iter (Callstack.Hashtbl.replace new_tbl cs) s
        in
        List.iter add list;
        new_tbl

    let get_global_state () =
      let+ state = Cvalue_results.get_global_state () in
      state, Locals_scoping.top ()

    let get_initial_state kf =
      let+ state = Cvalue_results.get_initial_state kf in
      state, Locals_scoping.top ()

    let get_initial_state_by_callstack ?selection kf =
      match Cvalue_results.get_initial_state_by_callstack ?selection kf with
      | `Top -> `Top
      | `Bottom -> `Bottom
      | `Value tbl -> `Value (lift_tbl (select ?selection tbl))

    let get_stmt_state ~after stmt =
      let+ state = Cvalue_results.get_stmt_state ~after stmt in
      state, Locals_scoping.top ()

    let get_stmt_state_by_callstack ?selection ~after stmt =
      match Cvalue_results.get_stmt_state_by_callstack ?selection ~after stmt with
      | `Top -> `Top
      | `Bottom -> `Bottom
      | `Value tbl -> `Value (lift_tbl (select ?selection tbl))

    let mark_as_computed = Cvalue_results.mark_as_computed
    let is_computed = Cvalue_results.is_computed
  end

  let get_state_before stmt =
    match Cvalue_results.get_stmt_state ~after:false stmt with
    | `Bottom -> Cvalue.Model.bottom
    | `Value v -> v

  let display ?fmt kf =
    let open Cil_types in
    (* Do not pretty Cil-generated variables or out-of-scope local variables *)
    let filter_generated_and_locals base =
      match base with
      | Base.Var (v, _) ->
        if v.vtemp then v.vname = "__retres"
        else
          ((not (Kernel_function.is_local v kf))
           (* only locals of outermost block *)
           || List.exists (fun x -> x.vid = v.vid)
             (Kernel_function.get_definition kf).sbody.blocals )
      | _ -> true
    in
    try
      let values = get_state_before (Kernel_function.find_return kf) in
      let fst_values = get_state_before (Kernel_function.find_first_stmt kf) in
      if Cvalue.Model.is_reachable fst_values
      && not (Cvalue.Model.is_top fst_values)
      then begin
        let print_cardinal = Self.is_debug_key_enabled dkey_card in
        let estimate =
          if print_cardinal
          then Cvalue.Model.cardinal_estimate values
          else Cvalue.CardinalEstimate.one
        in
        let outs = Eva_dynamic.Inout.kf_outputs kf in
        let outs = Locations.Zone.filter_base filter_generated_and_locals outs in
        let header fmt =
          Format.fprintf fmt "Values at end of function %a:%t"
            Kernel_function.pretty kf
            (fun fmt ->
               if print_cardinal then
                 Format.fprintf fmt " (~%a states)"
                   Cvalue.CardinalEstimate.pretty estimate)
        in
        let body fmt =
          Format.fprintf fmt "@[%t@]@[  %t@]"
            (fun fmt ->
               match outs with
               | Locations.Zone.Top (Base.SetLattice.Top, _) ->
                 Format.fprintf fmt "@[Cannot filter: dumping raw memory \
                                     (including unchanged variables)@]@\n"
               | _ -> ())
            (fun fmt -> Cvalue.Model.pretty_filter fmt values outs) in
        match fmt with
        | None -> Self.printf
                    ~dkey:Self.dkey_final_states ~header "%t" body
        | Some fmt -> Format.fprintf fmt "%t@.%t@," header body
      end
    with Kernel_function.No_Statement -> ()

  let display_results () =
    Self.result "====== VALUES COMPUTED ======";
    if Plugin.is_present "inout"
    && Self.is_debug_key_enabled Self.dkey_final_states
    then Eva_dynamic.Callgraph.iter_in_rev_order display;
    Self.result "%t" Eva_perf.display

  let post_analysis _state =
    if Parameters.ForceValues.get ()
    && Self.verbose_atleast 1
    then Parameters.ForceValues.output display_results
end


let registered =
  let name = "cvalue"
  and descr =
    "Main analysis domain, enabled by default. Should not be disabled."
  in
  Abstractions.Domain.register ~name ~descr ~priority:9 (module State)


type prefix = Hptmap.prefix
module Subpart = struct
  type t = Cvalue.Model.subtree
  let hash = Cvalue.Model.hash_subtree
  let equal = Cvalue.Model.equal_subtree
end
let distinct_subpart (a, _) (b, _) =
  if Cvalue.Model.equal a b then None
  else
    try Cvalue.Model.comp_prefixes a b; None
    with Cvalue.Model.Found_prefix (p, s1, s2) -> Some (p, s1, s2)
let find_subpart (s, _) prefix = Cvalue.Model.find_prefix s prefix


module Getters (Dom : Abstract.Domain.External) = struct
  let get_cvalue =
    match Dom.get State.key with
    | None -> None
    | Some get -> Some (fun s -> fst (get s))

  let get_cvalue_or_top =
    match Dom.get State.key with
    | None -> fun _ -> Cvalue.Model.top
    | Some get -> fun s -> fst (get s)

  let get_cvalue_or_bottom = function
    | `Bottom -> Cvalue.Model.bottom
    | `Value state -> get_cvalue_or_top state
end

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
