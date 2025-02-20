(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
open Cil_datatype
open Locations

(* Functions flagged as commonly related to user-provided input, therefore
   targeted in the option for automatic tainting. *)
let auto_taint_arg_functions = (* auto taint the arguments *) [
  "fgets";
  "gets";
  "fread";
  "fread_unlocked";
  "fgets_unlocked";
  "getline";
  "read"
]

let auto_taint_variadic_functions = [
  "fscanf";
  "scanf"
]

let auto_taint_res_functions = (* auto taint the result *) [
  "getchar";
  "getc"
]

let auto_taint () = Parameters.AutoTaint.get ()
let ignore_singletons () = not (Parameters.TaintSingletons.get ())

(* Default namespace for taints, when no custum one is provided by the user. *)
let default_taint_namespace = "default"

type taint_state = {
  (* Over-approximation of the memory locations that are tainted due to a data
     dependency. *)
  locs_data: Zone.t;
  (* Over-approximation of the memory locations that are tainted due to a
     control dependency. *)
  locs_control: Zone.t;
  (* Set of assume statements over a tainted expression. This set is needed to
     implement control-dependency: all left-values appearing in statements whose
     evaluation depends on at least one of the assume expressions is to be
     tainted. This set is restricted to statements of the current function. *)
  assume_stmts: Stmt.Set.t;
  (* Whether the current call depends on a tainted assume statement: if true,
     all assignments in the current call should be control tainted. *)
  dependent_call: bool;
}

(* Debug key to also include [assume_stmts] in the output of the
   Frama_C_domain_show_each directive. *)
let dkey_debug = Self.register_category "d-taint-debug"
    ~help:"debug print of the taint domain"

let wkey = Self.register_warn_category "taint"

module LatticeSingleTaint = struct

  let pp_locs_only fmt t =
    Format.fprintf fmt
      "@[<v 2>Locations (data):@ @[<hov>%a@]@]@\n\
       @[<v 2>Locations (control):@ @[<hov>%a@]@]"
      Zone.pretty t.locs_data
      Zone.pretty t.locs_control

  let pp_state fmt t =
    Format.fprintf fmt
      "@[<v 2>Locations (data):@ @[<hov>%a@]@]@\n\
       @[<v 2>Locations (control):@ @[<hov>%a@]@]@\n\
       @[<v 2>Assume statements:@ @[<hov>%a@]@\n\
       @[<v 2>Dependent call:@ %b@]"
      Zone.pretty t.locs_data
      Zone.pretty t.locs_control
      Stmt.Set.pretty t.assume_stmts
      t.dependent_call

  (* Frama-C "datatype" for type [taint]. *)
  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type t = taint_state

      let name = "single-taint"

      let reprs =
        [ { locs_data = List.hd Zone.reprs;
            locs_control = List.hd Zone.reprs;
            assume_stmts = Stmt.Set.empty;
            dependent_call = false; } ]

      let compare t1 t2 =
        let (<?>) c (cmp,x,y) = if c = 0 then cmp x y else c in
        Zone.compare t1.locs_data t2.locs_data
        <?> (Zone.compare, t1.locs_control, t2.locs_control)
        <?> (Stmt.Set.compare, t1.assume_stmts, t2.assume_stmts)
        <?> (Datatype.Bool.compare, t1.dependent_call, t2.dependent_call)

      let equal = Datatype.from_compare

      let pretty fmt t =
        if Self.is_debug_key_enabled dkey_debug
        then pp_state fmt t
        else pp_locs_only fmt t

      let hash t =
        Hashtbl.hash
          (Zone.hash t.locs_data,
           Zone.hash t.locs_control,
           Stmt.Set.hash t.assume_stmts,
           t.dependent_call)

      let copy c = c

    end)

  (* Initial state at the start of the computation: nothing is tainted yet. *)
  let empty = {
    locs_data = Zone.bottom;
    locs_control = Zone.bottom;
    assume_stmts = Stmt.Set.empty;
    dependent_call = false;
  }

  (* Top state: everything is tainted. *)
  let top = {
    locs_data = Zone.top;
    locs_control = Zone.top;
    assume_stmts = Stmt.Set.empty;
    dependent_call = false;
  }

  (* Join: keep pointwise over-approximation. *)
  let join t1 t2 =
    { locs_data = Zone.join t1.locs_data t2.locs_data;
      locs_control = Zone.join t1.locs_control t2.locs_control;
      assume_stmts = Stmt.Set.union t1.assume_stmts t2.assume_stmts;
      dependent_call = t1.dependent_call || t2.dependent_call; }

  (* The memory locations are finite, so the ascending chain property is
     already verified. We simply use a join. *)
  let widen _ _ t1 t2 = join t1 t2

  let narrow t1 t2 =
    `Value {
      locs_data = Zone.narrow t1.locs_data t2.locs_data;
      locs_control = Zone.narrow t1.locs_control t2.locs_control;
      assume_stmts = Stmt.Set.inter t1.assume_stmts t2.assume_stmts;
      dependent_call = t1.dependent_call && t2.dependent_call;
    }

  (* Inclusion testing: pointwise, on locs only. *)
  let is_included t1 t2 =
    Zone.is_included t1.locs_data t2.locs_data &&
    Zone.is_included t1.locs_control t2.locs_control

  (* Intersection testing: pointwise, on locs only. *)
  let intersects t e =
    Zone.intersects t.locs_data e ||
    Zone.intersects t.locs_control e

end

(* Maps a taint namespace to corresponding taint state. *)
module TaintNamespace = struct
  include Datatype.String.Map

  let find_or_empty key map =
    try find key map
    with Not_found -> LatticeSingleTaint.empty
end

type multi_taint_state = taint_state TaintNamespace.t

module LatticeMultiTaint = struct
  let pp_locs_only fmt t =
    Pretty_utils.pp_iter2 ~sep:"@ " ~between:": " TaintNamespace.iter
      Format.pp_print_string LatticeSingleTaint.pp_locs_only fmt t

  let pp_state fmt t =
    let pp_per_taint namespace taint =
      begin
        Format.pp_print_string fmt namespace;
        Format.pp_print_newline fmt ();
        LatticeSingleTaint.pp_state fmt taint
      end
    in
    TaintNamespace.iter pp_per_taint t

  (* Frama-C "datatype" for type [taint]. *)
  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type t = multi_taint_state

      let name = "taint"

      let reprs = [ TaintNamespace.empty ]

      let compare t1 t2 =
        TaintNamespace.compare LatticeSingleTaint.compare t1 t2

      let equal = Datatype.from_compare

      let pretty fmt t =
        if Self.is_debug_key_enabled dkey_debug
        then pp_state fmt t
        else pp_locs_only fmt t

      let hash t =
        TaintNamespace.fold (fun _ state acc ->
            LatticeSingleTaint.hash state + acc)
          t 0

      let copy c = c

    end)

  let empty = TaintNamespace.empty

  (* TODO: this is an unsound top value, as custom taint names are not bound
     to top. It cannot be represented as a map and should be replaced by a
     special TOP value. *)
  let top =
    TaintNamespace.singleton default_taint_namespace LatticeSingleTaint.top

  let join t1 t2 =
    let merge_per_key _key maybe_state1 maybe_state2 =
      match maybe_state1, maybe_state2 with
      | state, None | None, state -> state
      | Some state1, Some state2 -> Some (LatticeSingleTaint.join state1 state2)
    in
    TaintNamespace.merge merge_per_key t1 t2

  let widen kf stmt t1 t2 =
    let widen_per_key _key maybe_state1 maybe_state2 =
      match maybe_state1, maybe_state2 with
      | state, None | None, state -> state
      | Some state1, Some state2 ->
        Some (LatticeSingleTaint.widen kf stmt state1 state2)
    in
    TaintNamespace.merge widen_per_key t1 t2

  let narrow t1 t2 =
    let merge_per_key _key maybe_state1 maybe_state2 =
      match maybe_state1, maybe_state2 with
      | _, None | None, _ -> None
      | Some state1, Some state2 ->
        let `Value v = LatticeSingleTaint.narrow state1 state2 in
        Some v
    in
    `Value (TaintNamespace.merge merge_per_key t1 t2)

  let is_included t1 t2 =
    let fold2 f t1 t2 base =
      let f key state1 acc =
        let state2 = TaintNamespace.find_or_empty key t2 in
        f state1 state2 acc
      in
      TaintNamespace.fold f t1 base
    in
    fold2 (fun state1 state2 acc ->
        LatticeSingleTaint.is_included state1 state2 && acc) t1 t2 true
end

module TransferSingleTaint = struct

  let loc_of_lval valuation lv = valuation.Abstract_domain.find_loc_def lv

  (* Keeps only active tainted assumes for [stmt]. A tainted assume in [state]
     is considered active on a statement [stmt] whenever there exists a path
     from the tainted assume that not go through [stmt], ie [stmt] is not a
     postdominator for the tainted assume. *)
  let filter_active_tainted_assumes stmt state =
    let assume_stmts =
      Stmt.Set.filter
        (fun assume_stmt -> not (Dominators.postdominates stmt assume_stmt))
        state.assume_stmts
    in
    { state with assume_stmts }

  (* No update about taint wrt information provided by the other domains. *)
  let _update _valuation state = `Value state

  (* Given a lvalue, returns:
     - its memory location (as a zone);
     - its indirect dependencies, i.e. the memory zone its location depends on;
     - whether its location is a singleton. *)
  let compute_zones lval to_loc =
    match (lval : Eva_ast.lval).node with
    | Var vi, NoOffset ->
      (* Special case for direct access to variable: do not use [to_loc] here,
         as it will fail for the formal parameters of calls. *)
      let zone = Locations.zone_of_varinfo vi in
      zone, Zone.bottom, true
    | _ ->
      let ploc = to_loc lval in
      let singleton = Precise_locs.cardinal_zero_or_one ploc in
      let lv_zone =
        let loc = Precise_locs.imprecise_location ploc in
        Locations.enumerate_valid_bits Write loc
      in
      let lv_indirect_zone =
        Eva_ast.PreciseDepsOf.indirect_zone_of_lval to_loc lval
      in
      lv_zone, lv_indirect_zone, singleton

  let bottom_loc =
    Precise_locs.make_precise_loc Precise_locs.bottom_location_bits
      ~size:Int_Base.zero

  let dont_taint_singleton valuation to_loc =
    let to_loc_improved lval =
      let curr_exp = Eva_ast.Build.lval lval in
      match valuation.Abstract_domain.find curr_exp with
      | `Top -> to_loc lval
      | `Value r ->
        match r.value.v with
        | `Bottom -> bottom_loc
        | `Value v ->
          if Cvalue.V.cardinal_zero_or_one v then bottom_loc else to_loc lval
    in
    to_loc_improved

  (* Propagates data- and control-taints for an assignement [lval = exp]. *)
  let assign_aux lval exp v to_loc state =
    let lv_zone, lv_indirect_zone, singleton = compute_zones lval to_loc in
    let to_loc_choosen =
      if ignore_singletons () then
        (* Do not data-taint [lval] in case it contains a singleton value. *)
        dont_taint_singleton v to_loc
      else
        (* [lval] becomes data-tainted if a memory location on which the value of
           [exp] depends on is data-tainted. *)
        to_loc
    in
    let exp_zone = Eva_ast.zone_of_exp to_loc_choosen exp in
    let data_tainted = Zone.intersects state.locs_data exp_zone in
    (* [lval] becomes control-tainted if:
       - the current call depends on a tainted assume statements of a caller;
       - the execution of the assignment depends on a tainted assume statement;
       - the value of [exp] is control-tainted;
       - the assigned location depends on tainted values. *)
    let ctrl_tainted =
      state.dependent_call
      || not (Stmt.Set.is_empty state.assume_stmts)
      || Zone.intersects state.locs_control exp_zone
      || LatticeSingleTaint.intersects state lv_indirect_zone
    in
    let update tainted locs =
      if tainted
      then Zone.join locs lv_zone
      else if singleton
      then Zone.diff locs lv_zone
      else locs
    in
    { state with locs_data = update data_tainted state.locs_data;
                 locs_control = update ctrl_tainted state.locs_control; }

  let assign ki lv exp _v valuation state =
    let state =
      match ki with
      | Kglobal ->
        state
      | Kstmt stmt ->
        let state = filter_active_tainted_assumes stmt state in
        let to_loc = loc_of_lval valuation in
        assign_aux lv.Eval.lval exp valuation to_loc state
    in
    `Value state

  let assume stmt exp _b valuation state =
    let state = filter_active_tainted_assumes stmt state in
    (* Add [stmt] as assume statement in [state] as soon as [exp] is tainted. *)
    let to_loc = loc_of_lval valuation in
    let exp_zone = Eva_ast.PreciseDepsOf.zone_of_exp to_loc exp in
    let state =
      if not state.dependent_call && LatticeSingleTaint.intersects state exp_zone
      then { state with assume_stmts = Stmt.Set.add stmt state.assume_stmts; }
      else state
    in
    `Value state

  let start_call stmt call _recursion valuation state =
    let state = filter_active_tainted_assumes stmt state in
    let dependent_call =
      state.dependent_call || not (Stmt.Set.is_empty state.assume_stmts)
    in
    let state = { state with assume_stmts = Stmt.Set.empty; dependent_call } in
    let state =
      (* Add tainted actual parameters in [state]. *)
      let to_loc = loc_of_lval valuation in
      List.fold_left
        (fun s { Eval.concrete; formal; _ } ->
           assign_aux (Eva_ast.Build.var formal) concrete valuation to_loc s)
        state
        call.Eval.arguments
    in
    `Value state

  let get_formats_number s =
    let splitted = String.split_on_char '%' s in
    List.length splitted - 1

  let is_auto_taint_variadic kf =
    let vi = Kernel_function.get_vi kf in
    Ast_attributes.contains "fc_stdlib_generated" vi.vattr
    && List.mem vi.vorig_name auto_taint_variadic_functions

  let is_auto_taint_arg kf =
    let vi = Kernel_function.get_vi kf in
    List.mem vi.vorig_name auto_taint_arg_functions

  let arg_to_zone arg =
    match Eval.(value_assigned arg.avalue) with
    | `Bottom -> Locations.Zone.bottom (* should not happen *)
    | `Value value ->
      let loc_bits = Locations.loc_bytes_to_loc_bits value in
      let size = Bit_utils.sizeof_pointed arg.formal.vtype in
      let loc = Locations.make_loc loc_bits size in
      Locations.enumerate_valid_bits Write loc

  let rec get_n_first l n =
    match l with
    | curr :: rest when n > 0 -> curr :: get_n_first rest (n - 1)
    | _ -> []

  let rec find_tainted_argument args =
    match args with
    | [] -> raise Not_found
    | arg :: rest ->
      match arg.Eval.formal.vtype.tnode with
      | TPtr _ | TArray _ -> arg
      | _ -> find_tainted_argument rest

  let is_auto_taint_res kf =
    let vi = Kernel_function.get_vi kf in
    List.mem vi.vorig_name auto_taint_res_functions

  let zone_of_return ret =
    match ret with
    | Some vi ->
      let loc = Locations.loc_of_varinfo vi in
      Locations.enumerate_valid_bits Write loc
    | _ -> Zone.bottom

  let finalize_call _stmt _call _recursion ~pre ~post =
    (* Recover assume statements from the [pre] abstract state: we assume the
       control-dependency does not extended beyond the function scope. *)
    { post with assume_stmts = pre.assume_stmts;
                dependent_call = pre.dependent_call; }

  (* Adds automatic taint from [call] to [state] for some libc functions.
     Should be called after [finalize_call] only if -eva-auto-taint is set. *)
  let add_call_auto_taint call state =
    if is_auto_taint_variadic call.Eval.kf then
      begin
        match call.arguments with
        | { concrete = { node = Const (CString (String (_, CSString s))) } } :: rest
        | _ :: { concrete = { node = Const (CString (String (_, CSString s))) } } :: rest ->
          begin
            let zones = List.map arg_to_zone rest in
            let n = get_formats_number s in
            let vars_to_taint = get_n_first zones n in
            let locs_data = List.fold_left Zone.join state.locs_data vars_to_taint in
            { state with locs_data }
          end
        | _ -> state
      end
    else if is_auto_taint_arg call.kf then
      begin
        try
          let to_taint = find_tainted_argument call.arguments in
          let zone = arg_to_zone to_taint in
          { state with locs_data = Zone.join state.locs_data zone }
        with
        | Not_found -> state
      end
    else if is_auto_taint_res call.kf then
      begin
        let zone = zone_of_return call.return in
        { state with locs_data = Zone.join state.locs_data zone }
      end
    else
      state

  let show_expr valuation state fmt exp =
    let to_loc = loc_of_lval valuation in
    let exp_zone = Eva_ast.zone_of_exp to_loc exp in
    Format.fprintf fmt "%B" (LatticeSingleTaint.intersects state exp_zone)
end

module TransferMultiTaint = struct
  let get_value v =
    match v with
    | `Value res -> res

  let update _valuation state_map = `Value state_map

  let assign ki lv exp v valuation state_map =
    let assign_per_taint state =
      get_value @@ TransferSingleTaint.assign ki lv exp v valuation state
    in
    `Value (TaintNamespace.map assign_per_taint state_map)

  let assume stmt exp b valuation state_map =
    let assume_per_taint state =
      get_value @@ TransferSingleTaint.assume stmt exp b valuation state
    in
    `Value (TaintNamespace.map assume_per_taint state_map)

  let start_call stmt call recursion valuation state_map =
    let start_call_per_taint state =
      get_value @@ TransferSingleTaint.start_call stmt call
        recursion valuation state
    in
    `Value (TaintNamespace.map start_call_per_taint state_map)


  let finalize_call stmt call recursion ~pre ~post =
    let get_or_empty = function
      | None -> LatticeSingleTaint.empty
      | Some state -> state
    in
    (* Finalizes taint state for each taint label. *)
    let merge_per_key _key pre_opt post_opt =
      let pre = get_or_empty pre_opt
      and post = get_or_empty post_opt in
      let state =
        TransferSingleTaint.finalize_call stmt call recursion ~pre ~post
      in
      if LatticeSingleTaint.(equal empty state) then None else Some state
    in
    let map_state = TaintNamespace.merge merge_per_key pre post in
    (* Adds auto taints if -eva-auto-taint is set. *)
    let map_state =
      if auto_taint () then
        let auto_state = TaintNamespace.find_or_empty "auto" map_state in
        let auto_state =
          TransferSingleTaint.add_call_auto_taint call auto_state
        in
        TaintNamespace.add "auto" auto_state map_state
      else map_state
    in
    `Value map_state

  let show_expr valuation state_map fmt exp =
    let show_expr_per_taint namespace state =
      begin
        Format.fprintf fmt "%s\n" namespace;
        TransferSingleTaint.show_expr valuation state fmt exp
      end
    in
    TaintNamespace.iter show_expr_per_taint state_map
end


module QueriesTaint = struct

  let top_query = `Value (Cvalue.V.top, None), Alarmset.all

  let extract_expr ~oracle:_ _context _state _expr = top_query
  let extract_lval ~oracle:_ _context _state _lv _locs = top_query

end


module Domain = struct
  type state = multi_taint_state
  type value = Cvalue.V.t
  type location = Precise_locs.precise_location
  type origin

  let value_dependencies = Main_values.cval
  let location_dependencies = Main_locations.ploc

  include (LatticeMultiTaint: sig
             include Datatype.S_with_collections with type t = state
             include Abstract_domain.Lattice with type state := state
           end)

  include Domain_builder.Complete (LatticeMultiTaint)

  include QueriesTaint

  include (TransferMultiTaint: Abstract_domain.Transfer
           with type state := state
            and type value := value
            and type location := location
            and type origin := origin)


  (* Logic. *)

  let logic_assign_per_taint assign location state =
    let exists_tainted_from state deps =
      let single_from_contents dep =
        match dep.Eval.location with
        | Address _ -> false
        | Location location ->
          let loc_zone = Precise_locs.enumerate_valid_bits Read location in
          LatticeSingleTaint.intersects state loc_zone
      in
      List.exists single_from_contents deps
    in
    match assign with
    | (_, taint) when taint = LatticeSingleTaint.empty ->
      state
    | ((Eval.Frees _ | Allocates _), _) ->
      state
    | (Assigns (_, deps), pre_state) ->
      if exists_tainted_from pre_state deps
      then
        let loc_zone = Precise_locs.enumerate_valid_bits Write location in
        { state with locs_data = Zone.join state.locs_data loc_zone }
      else
        state

  let logic_assign assign location state_map =
    match assign with
    | None -> state_map
    | Some (loc_assign, taint_map) ->
      TaintNamespace.mapi (fun key state ->
          let current_taint = TaintNamespace.find_or_empty key taint_map in
          logic_assign_per_taint (loc_assign, current_taint) location state)
        state_map

  (* Scoping and Initialization. *)

  let enter_scope _kind _vars state = state

  let remove_bases_per_taint bases state =
    let remove = Zone.filter_base (fun b -> not (Base.Hptset.mem b bases)) in
    { state with locs_data = remove state.locs_data;
                 locs_control = remove state.locs_control; }

  let remove_bases bases state_map =
    TaintNamespace.map (remove_bases_per_taint bases) state_map

  let leave_scope _kf vars state =
    let bases = Base.Hptset.of_list (List.map Base.of_varinfo vars) in
    remove_bases bases state


  (* Initial state: initializers are singletons, so we store nothing. *)
  let empty () = LatticeMultiTaint.empty
  let initialize_variable _ _ ~initialized:_ _ state = state
  let initialize_variable_using_type _ _ state  = state


  (* MemExec cache. *)
  let relate _bases _state = Base.SetLattice.empty

  let filter bases state_map =
    let filter_state bases state =
      let filter_base = Zone.filter_base (fun b -> Base.Hptset.mem b bases) in
      { state with locs_data = filter_base state.locs_data;
                   locs_control = filter_base state.locs_control;
                   assume_stmts = Stmt.Set.empty; }
    in
    TaintNamespace.map (filter_state bases) state_map

  let project = filter

  let overwrite bases ~on:state ~by =
    let state = remove_bases bases state in
    LatticeMultiTaint.join state by

  let reuse bases ~current_input ~previous_output =
    overwrite bases ~on:current_input ~by:previous_output
end

include Domain

(* Registers the domain. *)
let registered =
  let name = "taint"
  and descr = "Taint analysis" in
  Abstractions.Domain.register ~name ~descr ~experimental:true (module Domain)


exception Parse_error of string option

let error ?msg loc typing_context =
  typing_context.Logic_typing.error loc
    "invalid taint annotation %a"
    (Pretty_utils.pp_opt ~pre:": " Format.pp_print_string) msg

let _parse_error ?msg () = raise (Parse_error msg)

(* Registers ACSL builtin predicate \tainted. *)
let () =
  let a_name = "tainted" in
  let a_type = Lvar a_name in
  let builtin_logic_info =
    { bl_name = "\\tainted";
      bl_labels = [];
      bl_params = [ a_name ];
      bl_type = None;
      bl_profile = ["p", a_type];
    }
  in
  Logic_builtin.register builtin_logic_info

let rec parse_lval names kind typing_context loc arg =
  match arg.Logic_ptree.lexpr_node with
  | PLnamed (name, node) ->
    (* name:x to taint variable x in 'name' namespace *)
    let names = name :: names in
    parse_lval names kind typing_context loc node
  | PLconstant (StringConstant str) ->
    Logic_const.tstring ~loc str
  | _ ->
    let open Logic_typing in
    let get_state context =
      match kind with
      | `Pre -> context.pre_state
      | `Post -> context.post_state [Normal]
    in
    let term =
      typing_context.type_term typing_context (get_state typing_context) arg
    in
    { term with term_name = names }

let terms_of_parsed_taint_namespaces typing_context loc args kind =
  try
    List.map (parse_lval [] kind typing_context loc) args
  with
  | Parse_error msg ->
    error ?msg loc typing_context

(* Registers ACSL extension "taint" (statement annotation)
   and "taints" (behavior extension). *)
let () =
  let typer kind context loc args =
    Ext_terms (terms_of_parsed_taint_namespaces context loc args kind)
  in
  Acsl_extension.register_behavior ~plugin:"eva" "taints" (typer `Post) false;
  Acsl_extension.register_code_annot_next_stmt ~plugin:"eva" "taint"
    (typer `Pre) false

(* The taint namespace of a term is stored as its term name.
   If no term name is present, the term namespace defaults to "default". *)
let term_taint_namespaces term =
  if term.term_name = [] then [ default_taint_namespace ] else term.term_name

(* Interpretation of logic by the taint domain, using the cvalue domain. *)
module TaintLogic = struct

  let eval_tlval_zone cvalue_env term =
    let alarm_mode = Eval_terms.Fail in
    try
      let access = Locations.Read in
      Some (Eval_terms.eval_tlval_as_zone_under_over
              ~alarm_mode access cvalue_env term)
    with Eval_terms.LogicEvalError _ -> None

  let eval_term_deps cvalue_env term =
    let alarm_mode = Eval_terms.Fail in
    try
      let result = Eval_terms.eval_term ~alarm_mode cvalue_env term in
      match Logic_label.Map.bindings result.ldeps with
      | [ BuiltinLabel Here, zone ] -> Some (Zone.bottom, zone)
      | _ -> None
    with Eval_terms.LogicEvalError _ -> None

  let eval_term_zone cvalue_env term =
    match eval_tlval_zone cvalue_env term with
    | Some _ as x -> x
    | None -> eval_term_deps cvalue_env term

  let reduce_by_taint_predicate cvalue_env state term positive =
    match eval_term_zone cvalue_env term with
    | None -> state
    | Some (under, _over) ->
      if positive
      then { state with locs_data = Zone.join state.locs_data under }
      else { state with locs_data = Zone.diff state.locs_data under }

  let rec reduce_by_predicate cvalue_env state_map predicate positive =
    match positive, predicate.pred_content with
    | true, Pand (p1, p2)
    | false, Por (p1, p2) ->
      let state = reduce_by_predicate cvalue_env state_map p1 positive in
      reduce_by_predicate cvalue_env state p2 positive
    | true, Por (p1, p2)
    | false, Pand (p1, p2) ->
      let state1 = reduce_by_predicate cvalue_env state_map p1 positive in
      let state2 = reduce_by_predicate cvalue_env state_map p2 positive in
      join state1 state2
    | _, Pnot p -> reduce_by_predicate cvalue_env state_map p (not positive)
    | _, Papp ({l_var_info = {lv_name = "\\tainted"}}, _labels, [arg]) ->
      let taint_names = term_taint_namespaces arg in
      TaintNamespace.mapi (fun key state ->
          if List.mem key taint_names then
            reduce_by_taint_predicate cvalue_env state arg positive
          else
            state) state_map
    | _ -> state_map

  let evaluate_taint_predicate cvalue_env state term =
    match eval_term_zone cvalue_env term with
    | None -> Alarmset.Unknown
    | Some (_under, over) ->
      if Zone.intersects over state.locs_data
      then Alarmset.Unknown
      else Alarmset.False

  let evaluate_predicate cvalue_env state_map predicate =
    let rec evaluate predicate =
      match predicate.pred_content with
      | Papp ({l_var_info = {lv_name = "\\tainted"}}, _labels, [arg]) ->
        let taint_names = term_taint_namespaces arg in
        let states_list =
          List.map
            (fun key -> TaintNamespace.find_or_empty key state_map)
            taint_names
        in
        let state =
          List.fold_left LatticeSingleTaint.join
            LatticeSingleTaint.empty states_list
        in
        evaluate_taint_predicate cvalue_env state arg
      | Ptrue -> True
      | Pfalse -> False
      | Pand (p1, p2) ->
        begin
          match evaluate p1, evaluate p2 with
          | True, True -> True
          | False, _ | _, False -> False
          | _ -> Unknown
        end
      | Por (p1, p2) ->
        begin
          match evaluate p1, evaluate p2 with
          | True, _ | _, True -> True
          | False, False -> False
          | _ -> Unknown
        end
      | Pnot p ->
        begin
          match evaluate p with
          | True -> False
          | False -> True
          | Unknown -> Unknown
        end
      | _ -> Unknown
    in
    evaluate predicate

  let interpret_taint_extension cvalue_env taint_map terms =
    let taint_term state term =
      match eval_tlval_zone cvalue_env term with
      | None ->
        Self.warning ~wkey ~current:true ~once:true
          "Cannot evaluate term %a in taint annotation; ignoring."
          Printer.pp_term term;
        state
      | Some (under, over) ->
        if not (Zone.equal under over)
        then
          Self.warning ~wkey ~current:true ~once:true
            "Cannot precisely evaluate term %a in taint annotation; \
             over-approximating."
            Printer.pp_term term;
        let taint_names = term_taint_namespaces term in
        let add_taint state name =
          let taint = TaintNamespace.find_or_empty name state in
          let locs_data = Zone.join taint.locs_data over in
          TaintNamespace.add name { taint with locs_data } state
        in
        List.fold_left add_taint state taint_names
    in
    List.fold_left taint_term taint_map terms
end

let interpret_taint_logic
    (module Abstract: Abstractions.S) : (module Abstractions.S) =
  match Abstract.Dom.get Cvalue_domain.State.key, Abstract.Dom.get key with
  | None, _
  | _, None -> (module Abstract)
  | Some get_cvalue_state, Some get_taint_state ->
    let module Dom = struct
      include Abstract.Dom

      let get_states env state =
        let taint = get_taint_state state in
        let get_cvalue state = fst (get_cvalue_state state) in
        let states label = get_cvalue (env.Abstract_domain.states label) in
        let cvalue_env = Abstract_domain.{ env with states = states } in
        Eval_terms.make_env cvalue_env (get_cvalue state), taint

      let evaluate_predicate env state predicate =
        match evaluate_predicate env state predicate with
        | Unknown ->
          let cvalue_env, taint = get_states env state in
          TaintLogic.evaluate_predicate cvalue_env taint predicate
        | x -> x

      let reduce_by_predicate env state predicate positive =
        match reduce_by_predicate env state predicate positive with
        | `Bottom -> `Bottom
        | `Value state ->
          let cvalue_env, taint = get_states env state in
          let taint =
            TaintLogic.reduce_by_predicate cvalue_env taint predicate positive
          in
          `Value (Abstract.Dom.set key taint state)

      let interpret_acsl_extension extension env state =
        if String.equal extension.ext_name "taint"
        || String.equal extension.ext_name "taints"
        then
          match extension.ext_kind with
          | Ext_terms terms ->
            let cvalue_env, taint = get_states env state in
            let taint =
              TaintLogic.interpret_taint_extension cvalue_env taint terms
            in
            Abstract.Dom.set key taint state
          | _ ->
            Self.warning ~wkey ~current:true ~once:true
              "Invalid taint annotation %a; ignoring."
              Printer.pp_extended extension;
            state
        else state
    end
    in
    (module struct
      module Ctx = Abstract.Ctx
      module Val = Abstract.Val
      module Loc = Abstract.Loc
      module Dom = Dom
    end)

let () = Abstractions.Hooks.register interpret_taint_logic


type taint = Direct | Indirect | Untainted

let is_tainted state_map ?indirect zone =
  let { locs_data ; locs_control } =
    TaintNamespace.fold (fun _ state acc -> LatticeSingleTaint.join state acc)
      state_map LatticeSingleTaint.empty
  in
  let intersects_any z = Zone.(intersects (join locs_data locs_control) z) in
  let is_indirect () = Option.fold indirect ~none:false ~some:intersects_any in
  if Zone.intersects zone locs_data then Direct
  else if Zone.intersects zone locs_control || is_indirect () then Indirect
  else Untainted
