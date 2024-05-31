(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

let stat_hits_summaries = Statistics.register_function_stat "memexec-hits-summaries"
let stat_misses_summaries = Statistics.register_function_stat "memexec-misses-summaries"
let stat_misses_allocated_bases = Statistics.register_function_stat "memexec-misses-allocated-bases"
let stat_misses_entry_state = Statistics.register_function_stat "memexec-misses-entry-state"
let stat_misses_input_relation = Statistics.register_function_stat "memexec-misses-input-relation"
let stat_misses_import_kf = Statistics.register_function_stat "memexec-miss-import-kf"
let stat_project_load_time = Statistics.register_global_stat 
    "time-project-load"
let stat_memexec_load_time = Statistics.register_global_stat 
    "time-memexec-import-cache"
let stat_memexec_clear_time = Statistics.register_global_stat 
    "time-memexec-clear-cache"
let stat_ast_diff_load_time = Statistics.register_global_stat
    "time-ast-diff-compute"
let stat_special_variables_load_time = Statistics.register_global_stat
    "time-special-variables-import"
let stat_inout_load_time = Statistics.register_global_stat
    "time-inout-import"
let stat_check_saved_project = Statistics.register_global_stat
    "time-check-saved-project"
let stat_builtin_malloc_load_time = Statistics.register_global_stat
    "time-builtin-malloc-import"
let stat_function_summaries_load_time = Statistics.register_global_stat
    "time-function-summaries-import"
let stat_gather_load_time = Statistics.register_global_stat
    "time-gather-import"


let proxy = State_builder.Proxy.(create "Mem_exec.proxy" Forward [])
let add_cache_dependency state = State_builder.Proxy.extend [state] proxy
let cache_dependencies = [ Ast.self; State_builder.Proxy.get proxy ]

let load_time_wrapper stat_key f =
  let start_time = Unix.time () in
  let res = f () in
  let total_time = (Unix.time ()) -. start_time in
  let total_time_ms = int_of_float (total_time *. 1000.) in
  begin
    Statistics.set stat_key () total_time_ms;
    res
  end

let dkey = Self.dkey_memexec
let dkey_malloc = Self.register_category "memexec-malloc"

module SaveCounter =
  State_builder.SharedCounter(struct let name = "Mem_exec.save_counter" end)

let new_counter, current_counter =
  let cur = ref (-1) in
  (fun () -> cur := SaveCounter.next (); !cur),
  (fun () -> !cur)

let cleanup_ref = ref (fun () -> ())

(* TODO: it would be great to clear also the tables within the plugins. Export
   self and add dependencies *)
let cleanup_results () = !cleanup_ref ()

exception TooImprecise

(* Extract all the bases from a zone *)
let bases = function
  | Locations.Zone.Top (Base.SetLattice.Top, _) -> raise TooImprecise
  | Locations.Zone.Top (Base.SetLattice.Set s, _) -> s
  | Locations.Zone.Map m -> Base.Hptset.from_map (Locations.Zone.shape m)


let counter = ref 0

module Make
    (Value : Abstract_value.S)
    (Domain : Abstract.Domain.External)
= struct

  incr counter;

  include Cvalue_domain.Getters (Domain)

  module CallOutput = Datatype.List (Datatype.Pair (Partition.Key) (Domain))

  module StoredResult =
    Datatype.Triple
      (Base.Hptset)  (* Set of bases possibly read or written by the call. *)
      (CallOutput)   (* The resulting states of the call. *)
      (Datatype.Int) (* Call number, for plugins *)

  module AllocatedBasesToResults =
    Base.Hptset.Hashtbl.Make (StoredResult)

  type call_result = {
    return_flow: (Partition.key * Domain.t) list;
    cacheable: Eval.cacheable;
    allocated_bases: Base.Hptset.t;
  }

  (* Map from input states to outputs (summary and state). *)
  module CallEffect = Domain.Hashtbl.Make (AllocatedBasesToResults)

  (* Map from useful input bases to call effects. *)
  module InputBasesToCallEffect = Base.Hptset.Hashtbl.Make (CallEffect)

  (* List of the arguments of a call. *)
  module ActualArgs =
    Datatype.List_with_collections (Datatype.Option (Value)) (* None is bottom *)
      (struct let module_name = "Mem_exec.ActualArgs("
                                ^ string_of_int !counter ^ ")"
      end)

  (* Map from the arguments of a call to stored results. *)
  module ArgsToStoredCalls = ActualArgs.Map.Make (InputBasesToCallEffect)

  let name = "Mem_exec.PreviousCalls(" ^ Value.name ^ ", " ^ Domain.name ^")"
  let unique_name = State.unique_name_from_name name

  module PreviousCalls =
    Kernel_function.Make_Table
      (ArgsToStoredCalls)
      (struct
        let size = 17
        let dependencies = cache_dependencies
        let name = unique_name
      end)

  let cleanup = !cleanup_ref
  let () = cleanup_ref := fun () -> cleanup (); PreviousCalls.clear ()

  (** [diff_base_full_zone bases zones] remove from the set of bases [bases]
      those of which all bits are present in [zones] *)
  let diff_base_full_zone =
    let cache = Hptmap_sig.PersistentCache "Mem_exec.diff_base_full_zone" in
    let empty_left _ = Base.Hptset.empty (* nothing left to clear *) in
    let empty_right v = v (* return all bases unchanged *) in
    (* Check whether [range] covers the validity of [b]. If so, remove [b]
       (hence, return an empty set). Otherwise, keep [b]. Variable strong bases are
       also removed, because they won't ever be changed to weak.
       This is specific to the way this function is used later in this file. *)
    let is_in_range b min max range =
      match Int_Intervals.project_singleton range with
      | Some (min', max') ->
        if Integer.equal min min' && Integer.equal max max' then
          Base.Hptset.empty
        else
          Base.Hptset.singleton b
      | None -> Base.Hptset.singleton b
    in 
    let both b range = begin
      match Base.validity b with
      | Base.Invalid -> assert false
      | Base.Empty -> Base.Hptset.empty
      | Base.Variable {weak = true} -> Base.Hptset.singleton b
      | Base.Variable {weak = false; max_alloc = max} ->
        let min = Integer.zero in
        is_in_range b min max range
      | Base.Known (min, max) | Base.Unknown (min, _, max) ->
        is_in_range b min max range
    end in
    let join = Base.Hptset.union in
    let empty = Base.Hptset.empty in
    let f = Base.Hptset.fold2_join_heterogeneous
        ~cache ~empty_left ~empty_right ~both ~join ~empty
    in
    fun bases z ->
      match z with
      | Locations.Zone.Map m -> f bases (Locations.Zone.shape m)
      | Locations.Zone.Top _ -> bases (* Never happens anyway *)

  (* Extends the input [bases] of a function [kf] by adding all bases related to
     these inputs in state [state]. We perform a fixpoint over [Domain.relate]
     to compute the transitive closure of the relations in [state] on [bases].
     Indeed, if a domain D1 relates x and y, and a domain D2 relates y and z,
     then x and z are also related.
     All bases related to the input [bases] should be taken into account when
     applying the memexec cache, as their values may impact the analysis of [kf]
     starting from state [state].
     As a full fixpoint computation could be costly, we stop after [count] calls
     to [Domain.relate] and we disable memexec if a fixpoint is not reached. *)
  let rec expand_inputs_with_relations count kf bases state =
    let related_bases = Domain.relate kf bases state in
    match related_bases with
    | Base.SetLattice.Top -> related_bases
    | Base.SetLattice.Set new_bases ->
      let expanded_bases = Base.Hptset.union new_bases bases in
      if Base.Hptset.equal expanded_bases bases
      then Base.SetLattice.inject expanded_bases
      else if count <= 0 then Base.SetLattice.top
      else expand_inputs_with_relations (count - 1) kf expanded_bases state

  let process_outputs kf all_output_bases call_result = 
    (* Adds the fake varinfo used for the result of [kf] to the
       output_bases. *)
    let return_varinfo = Special_variables.get_retres kf in
    let return_base = Option.map Base.of_varinfo return_varinfo in
    let add b = Base.Hptset.add b all_output_bases in
    let all_output_bases =
      Option.fold ~some:add ~none:all_output_bases return_base
    in
    let clear (key,state) =
      key, Domain.filter (`Post kf) all_output_bases state
    in
    let outputs = List.map clear call_result.return_flow in
    let call_number = current_counter () in
    (outputs, call_number)

  let extract_bases kf inout input_state = 
    let output_bases = bases inout.Inout_type.over_outputs_if_termination in
    let input_bases =
      let input_bases = bases inout.Inout_type.over_inputs in
      let logic_input_bases = bases inout.Inout_type.over_logic_inputs in
      Base.Hptset.union input_bases logic_input_bases
    in
    (* FIXME: Always remove outputs whose base is completely overwritten *)
    let input_bases =
      let uncertain_output_bases =
        diff_base_full_zone
          output_bases inout.Inout_type.under_outputs_if_termination
      in
      Base.Hptset.union input_bases uncertain_output_bases
    in
    let input_bases =
      expand_inputs_with_relations 2 kf input_bases input_state
    in
    let input_bases = match input_bases with
      | Base.SetLattice.Top -> raise TooImprecise
      | Base.SetLattice.Set bases -> bases
    in
    let reduced_input_state = Domain.filter (`Pre kf) input_bases input_state in
    (* Outputs bases, that is bases that are copy-pasted, also include
       input bases. Indeed, those may get reduced during the call. *)
    let all_output_bases =
      Base.Hptset.union input_bases output_bases
    in 
    (input_bases, reduced_input_state, all_output_bases)


  let store_results_kf inout kf input_state args (call_result: call_result) = 
    let allocated_bases = call_result.allocated_bases in 
    let input_bases, reduced_input_state, all_output_bases = extract_bases kf inout input_state in
    let all_output_bases = 
      Base.Hptset.union all_output_bases allocated_bases
    in
    let outputs, call_number = process_outputs kf all_output_bases call_result in
    let map_args_to_input_bases =
      try PreviousCalls.find kf
      with Not_found -> ActualArgs.Map.empty
    in
    let htbl_input_bases_to_input_state =
      try ActualArgs.Map.find args map_args_to_input_bases
      with Not_found ->
        let h = Base.Hptset.Hashtbl.create 11 in
        let map_a = ActualArgs.Map.add args h map_args_to_input_bases in
        PreviousCalls.replace kf map_a;
        h
    in
    let htbl_input_state_to_allocated_bases =
      try Base.Hptset.Hashtbl.find htbl_input_bases_to_input_state input_bases
      with Not_found ->
        let h = Domain.Hashtbl.create 11 in
        Base.Hptset.Hashtbl.add htbl_input_bases_to_input_state input_bases h;
        h
    in
    (* We only keep the last set of allocated bases (More efficient, More precise) *)
    let htbl_allocated_bases_to_results =
      (* try Domain.Hashtbl.find htbl_input_state_to_allocated_bases reduced_input_state
         with Not_found -> *)
      let h = Base.Hptset.Hashtbl.create 11 in
      Domain.Hashtbl.add htbl_input_state_to_allocated_bases reduced_input_state h;
      h
    in
    Base.Hptset.Hashtbl.add htbl_allocated_bases_to_results allocated_bases (all_output_bases, outputs, call_number)


  let store_computed_call kf input_state args (call_result: call_result) =
    match Transfer_stmt.current_kf_inout () with
    | None -> ()
    | Some inout ->
      try
        let args =
          List.map (function `Bottom -> None | `Value v -> Some v) args
        in store_results_kf inout kf input_state args call_result
      with
      | TooImprecise
      | Kernel_function.No_Statement
      | Not_found -> ()


  exception Result_found of call_result * int

  (* We try to reuse only previously allocated bases when the current callstack is similar to the callstack 
     where the bases where allocated in order to preserve maximal precision
     Similarity is defined as having the same prefix of callstacks, 
     i.e the current callstack is prefix of the callstack where the bases were allocated
  *)
  let is_similar_callstack bases (callstack: Callstack.t) = 
    let call_list_from_memexec = Callstack.to_call_list callstack in
    let aux_similar base =
      let cs = Builtins_malloc.get_base_allocation_site base in
      let call_list_from_builtins = Callstack.to_call_list cs in
      let rec left_compare s s' =
        match s ,s' with
        | [], _ -> true
        | _ , [] -> false 
        | hd::tl, hd'::tl' -> 
          let (kf, _) = hd in
          let (kf', _) = hd' in
          if Kernel_function.equal kf kf' 
          then left_compare tl tl'
          else false
      in left_compare call_list_from_memexec call_list_from_builtins
    in Base.Hptset.for_all aux_similar bases


  (* We can reuse a set of allocated bases for the current call iff:
     - the set of bases is not in the current cvalue_model
     - the current callstack is similar to the callstack where the bases were allocated 
  *)
  let _can_reuse bases cvalue_model callstack = 
    not (Base.Hptset.exists (fun base -> 
        try
          ignore (Cvalue.Model.find_base base cvalue_model);
          true
        with Not_found -> false) bases)
    && 
    is_similar_callstack bases callstack


  let fail_if_not_reusable _bases _cvalue_model _callstack =
    if not (Base.Hptset.is_empty _bases) && not (_can_reuse _bases _cvalue_model _callstack) then
      raise Not_found

  (** Find a previous execution in [map_inputs] that matches [st].
      raise [Result_found] when this execution exists, or do nothing. *)
  let find_match_in_previous kf state args = 
    let cvalue_model = get_cvalue_or_top state in
    let stored_args = PreviousCalls.find kf in
    let map_inputs = ActualArgs.Map.find args stored_args in
    let aux_previous_call binputs hstates =
      let brelated = Domain.relate kf binputs state in
      if not Base.SetLattice.(is_included brelated (inject binputs))
      then 
        ignore(Statistics.incr stat_misses_input_relation kf)
      else
        try
          let st_filtered = Domain.filter (`Pre kf) binputs state in
          let htbl_allocated_bases_to_results = 
            try 
              Domain.Hashtbl.find hstates st_filtered 
            with Not_found -> 
              Statistics.incr stat_misses_entry_state kf;
              raise Not_found
          in
          let aux_previous_results allocated (bases, outputs, i) =
            try
              let cacheable = match Base.Hptset.is_empty allocated with
                | true -> Eval.Cacheable
                | false -> Eval.MallocedCall
              in
              let callstack = Eva_utils.current_call_stack () in
              let _ = try 
                  fail_if_not_reusable allocated cvalue_model callstack
                with Not_found -> 
                  Statistics.incr stat_misses_allocated_bases kf; 
                  raise Not_found
              in
              let _ = 
                if not (Base.Hptset.is_empty allocated) then
                  Self.debug ~dkey: dkey_malloc
                    "--- Reused allocated bases %a for KF %a at callstack %a @." Base.Hptset.pretty allocated Kernel_function.pretty kf Callstack.pretty (Eva_utils.current_call_stack ()) in
              let process bases_to_substitute (key,output) =
                key,
                Domain.reuse kf bases_to_substitute ~current_input:state ~previous_output:output
              in
              let bases_to_substitute = Base.Hptset.union bases allocated in
              let outputs = List.map (process bases_to_substitute) outputs in
              raise (
                Result_found({ 
                    return_flow=outputs;
                    cacheable=cacheable;
                    allocated_bases=allocated;
                  }, i))
            with Not_found -> ()
          in
          Base.Hptset.Hashtbl.iter aux_previous_results htbl_allocated_bases_to_results 
        with Not_found -> ()
    in
    Base.Hptset.Hashtbl.iter aux_previous_call map_inputs

  let reuse_previous_call kf state args =
    try
      let args =
        List.map (function `Bottom -> None | `Value v -> Some v) args in
      find_match_in_previous kf state args;
      Self.debug ~dkey "No previous saved state found for %a@." Kernel_function.pretty kf;
      Statistics.incr stat_misses_summaries kf;
      None
    with
    | Not_found ->
      Statistics.incr stat_misses_summaries kf;
      Self.debug ~dkey "No previous call found for %a@." Kernel_function.pretty kf;
      None
    | Result_found (outputs, i) ->
      Statistics.incr stat_hits_summaries kf;
      let call_result = outputs in
      Some (call_result, i)

  (* ------------------------------------------------------------------------ *)
  (*              Reload caches from another Frama-C project                  *)
  (* ------------------------------------------------------------------------ *)

  let import_stored_results (tbl: AllocatedBasesToResults.t) =
    let new_tbl = Base.Hptset.Hashtbl.(create (length tbl)) in
    let add allocated (bases, outputs, i) =
      let all_bases = Eva_diff.import_bases bases in
      let allocated = Eva_diff.import_bases allocated in
      let outputs =
        List.map (fun (key, state) -> key, Domain.import state) outputs
      in
      Base.Hptset.Hashtbl.add new_tbl allocated (all_bases, outputs, i)
    in 
    Base.Hptset.Hashtbl.iter add tbl;
    new_tbl

  let import_call_effect (tbl: CallEffect.t) =
    let new_tbl = Domain.Hashtbl.(create (length tbl)) in
    let add entry_state allocated_tbl =
      try
        let entry_state = Domain.import entry_state in
        let allocated_tbl = import_stored_results allocated_tbl in
        Domain.Hashtbl.add new_tbl entry_state allocated_tbl
      with Not_found ->
        ()
    in
    Domain.Hashtbl.iter add tbl;
    new_tbl

  let import_bases_to_call_effect (tbl: InputBasesToCallEffect.t) =
    let new_tbl = Base.Hptset.Hashtbl.(create (length tbl)) in
    let add bases call_effect =
      try
        let bases = Eva_diff.import_bases bases in
        let call_effect = import_call_effect call_effect in
        Base.Hptset.Hashtbl.add new_tbl bases call_effect;
      with Not_found ->
        ()
    in
    Base.Hptset.Hashtbl.iter add tbl;
    new_tbl

  let import_calls (map: ArgsToStoredCalls.t) =
    let add key data acc =
      try
        let key = List.map (Option.map Value.import) key in
        let data = import_bases_to_call_effect data in
        ActualArgs.Map.add key data acc
      with Not_found -> 
        acc
    in
    ActualArgs.Map.fold add map ActualArgs.Map.empty

  let import_cache_summaries not_imported_kf (old_kf, old_data) =
    match Ast_diff.Kernel_function.find old_kf with
    | `Same kf ->
      begin
        if Kernel_function.Hashtbl.mem not_imported_kf old_kf then
          begin
            Self.debug ~dkey "Function %a has no syntax diff but cannot imported due to dynalloc data import failure @." Kernel_function.pretty old_kf;
            Statistics.incr stat_misses_import_kf kf
          end
        else
          try
            let _ = Self.debug ~dkey "Importing summaries for function %a@." Kernel_function.pretty old_kf in
            let data = import_calls old_data in
            PreviousCalls.replace kf data
          with Not_found ->
            Self.debug ~dkey "Cannot import summaries for function %a@."
              Kernel_function.pretty kf
      end
    | `Partial _ as diff ->
      Self.debug ~dkey "Function %a has been modified: %a"
        Kernel_function.pretty old_kf
        Ast_diff.Kernel_function.pretty_data diff;
      Statistics.incr stat_misses_import_kf old_kf
    | `Not_present
    | exception Not_found -> ()

  let print_cache_size prefix_msg =
    let kf_nb = PreviousCalls.length () in
    let call_nb =
      PreviousCalls.fold (fun _ map acc ->
          ActualArgs.Map.fold (fun _ tbl acc ->
              Base.Hptset.Hashtbl.fold (fun _ call_effect acc ->
                  Domain.Hashtbl.length call_effect + acc)
                tbl acc)
            map acc)
        0
    in
    Self.feedback "%s, %i saved calls for %i functions" prefix_msg call_nb kf_nb

  let import_cached_calls_from name project =
    let aux_gather () =
      print_cache_size ("In save file " ^ name);
      PreviousCalls.fold (fun kf data acc -> (kf, data) :: acc) [],
      SaveCounter.get ()
    in
    let gather () =
      Project.on project aux_gather () in
    (* Gather time wrapped *)
    let list, counter =
      load_time_wrapper stat_gather_load_time gather in
    (* Builtin malloc wrapped *)
    let import_builtin_malloc () =
      if (Parameters.CacheAllocation.get ()) 
      then
        Builtins_malloc.import project
      else Kernel_function.Hashtbl.create 1 in
    let not_imported_kf = load_time_wrapper stat_builtin_malloc_load_time import_builtin_malloc in
    (* Summaries wrapped *)
    let import_function_summaries () =
      List.iter (import_cache_summaries not_imported_kf) list in
    load_time_wrapper stat_function_summaries_load_time import_function_summaries;
    SaveCounter.set counter


  let check_saved_project filename project =
    if not (Project.on project Self.is_computed ()) then
      Self.abort "No Eva analysis performed in saved file %s" filename;
    let check_parameter soundness param =
      let current = Typed_parameter.get_value param in
      let saved = Project.on project Typed_parameter.get_value param in
      if not (String.equal current saved
              || Typed_parameter.equal param Parameters.Load.parameter)
      then
        let msg =
          Format.asprintf
            "Current value of option %s is different from the saved file %s.@ \
             As this parameter affects the %s of the analysis, the results \
             of the previous analysis should not be reused."
            param.name filename (if soundness then "soundness" else "precision")
        in
        if soundness
        then Self.abort "%s" msg
        else Self.warning "%s" msg
    in
    List.iter (check_parameter true) Parameters.parameters_correctness;
    List.iter (check_parameter false) Parameters.parameters_tuning

  let load_cache filepath =
    try
      Self.feedback "Loading previous session from save file %a"
        Filepath.Normalized.pretty filepath;
      let name = Filename.basename (filepath :> string) in
      let project () = Project.load ~name filepath in
      let saved = load_time_wrapper stat_project_load_time project in
      let check () = 
        check_saved_project name saved in
      load_time_wrapper stat_check_saved_project check;
      Self.feedback
        "Computing AST differences between saved file and current session";
      let ast_diff () = 
        Ast_diff.compare_from_prj saved in
      load_time_wrapper stat_ast_diff_load_time ast_diff;
      let special_variables () =
        Special_variables.import saved in
      load_time_wrapper stat_special_variables_load_time special_variables;
      Base.import Eva_diff.import_base saved;
      Self.feedback "Copying Eva analysis cache from save file %s" name;
      import_cached_calls_from name saved;
      (* Inout wrapped *)
      let import_inout () =
        Eva_dynamic.Inout.import_memexec Eva_diff.import_inout saved in
      load_time_wrapper stat_inout_load_time import_inout;
      print_cache_size "In current session";
      Project.remove ~project:saved ();
    with
    | Project.IOError s ->
      Self.abort "Problem while loading file %a: %s"
        Filepath.Normalized.pretty filepath s

  let prepare () =
    let clear () = 
      begin 
        PreviousCalls.clear ();
      end in
    let prepare () =
      begin
        if not (Parameters.Load.is_empty ()) then
          load_cache (Parameters.Load.get ())
      end in
    load_time_wrapper stat_memexec_clear_time clear;
    load_time_wrapper stat_memexec_load_time prepare;
end


(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
