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

let stat_hits = Statistics.register_function_stat "memexec-hits"
let stat_misses = Statistics.register_function_stat "memexec-misses"

let proxy = State_builder.Proxy.(create "Mem_exec.proxy" Forward [])
let add_cache_dependency state = State_builder.Proxy.extend [state] proxy
let cache_dependencies = [ Ast.self; State_builder.Proxy.get proxy ]

let dkey = Self.dkey_memexec

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
    (Domain : Abstract_domain.S)
= struct

  incr counter;

  module CallOutput = Datatype.List (Datatype.Pair (Partition.Key) (Domain))

  module StoredResult =
    Datatype.Triple
      (Base.Hptset)  (* Set of bases possibly read or written by the call. *)
      (CallOutput)   (* The resulting states of the call. *)
      (Datatype.Int) (* Call number, for plugins *)

  (* Map from input states to outputs (summary and state). *)
  module CallEffect = Domain.Hashtbl.Make (StoredResult)

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

  module PreviousCalls =
    Kernel_function.Make_Table
      (ArgsToStoredCalls)
      (struct
        let size = 17
        let dependencies = cache_dependencies
        let name = "Mem_exec.PreviousCalls(" ^ Value.name ^ ", " ^ Domain.name ^")"
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
       (hence, return an empty set). Otherwise, keep [b]. Variable bases are
       always kept, because they may be changed into weak variables later.
       This is specific to the way this function is used later in this file. *)
    let both b range = begin
      match Base.validity b with
      | Base.Invalid -> assert false
      | Base.Empty -> Base.Hptset.empty
      | Base.Variable _ -> Base.Hptset.singleton b
      | Base.Known (min, max) | Base.Unknown (min, _, max) ->
        match Int_Intervals.project_singleton range with
        | Some (min', max') ->
          if Integer.equal min min' && Integer.equal max max' then
            Base.Hptset.empty
          else
            Base.Hptset.singleton b
        | None -> Base.Hptset.singleton b
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

  let store_computed_call kf input_state args
      (call_result: (Partition.key * Domain.t) list) =
    match Transfer_stmt.current_kf_inout () with
    | None -> ()
    | Some inout ->
      try
        let output_bases = bases inout.Inout_type.over_outputs_if_termination in
        let input_bases =
          let input_bases = bases inout.Inout_type.over_inputs in
          let logic_input_bases = bases inout.Inout_type.over_logic_inputs in
          Base.Hptset.union input_bases logic_input_bases
        in
        (* There are two strategies to compute the 'inputs' for a memexec
           function: either we take all inputs_bases+outputs_bases
           (outputs_bases are important because of weak updates), or we
           remove the sure outputs from the outputs, as sure outputs by
           definition strong updated. The latter will enable memexec to fire
           more often, but requires more computations. *)
        let remove_sure_outputs = true in
        let input_bases =
          if remove_sure_outputs then
            let uncertain_output_bases =
              (* Remove outputs whose base is completely overwritten *)
              diff_base_full_zone
                output_bases inout.Inout_type.under_outputs_if_termination
            in
            Base.Hptset.union input_bases uncertain_output_bases
          else
            Base.Hptset.union input_bases output_bases
        in
        let input_bases =
          expand_inputs_with_relations 2 kf input_bases input_state
        in
        let input_bases = match input_bases with
          | Base.SetLattice.Top -> raise TooImprecise
          | Base.SetLattice.Set bases -> bases
        in
        let state_input = Domain.filter (`Pre kf) input_bases input_state in
        (* Outputs bases, that is bases that are copy-pasted, also include
           input bases. Indeed, those may get reduced during the call. *)
        let all_output_bases =
          if remove_sure_outputs
          then Base.Hptset.union input_bases output_bases
          else input_bases
        in
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
        let outputs = List.map clear call_result in
        let call_number = current_counter () in
        let map_a =
          try PreviousCalls.find kf
          with Not_found -> ActualArgs.Map.empty
        in
        let hkf =
          let args =
            List.map (function `Bottom -> None | `Value v -> Some v) args in
          try ActualArgs.Map.find args map_a
          with Not_found ->
            let h = Base.Hptset.Hashtbl.create 11 in
            let map_a = ActualArgs.Map.add args h map_a in
            PreviousCalls.replace kf map_a;
            h
        in
        let hkb =
          try Base.Hptset.Hashtbl.find hkf input_bases
          with Not_found ->
            let h = Domain.Hashtbl.create 11 in
            Base.Hptset.Hashtbl.add hkf input_bases h;
            h
        in
        Domain.Hashtbl.add hkb state_input
          (all_output_bases, outputs, call_number);
      with
      | TooImprecise
      | Kernel_function.No_Statement
      | Not_found -> ()


  exception Result_found of CallOutput.t * int

  (** Find a previous execution in [map_inputs] that matches [st].
      raise [Result_found] when this execution exists, or do nothing. *)
  let find_match_in_previous kf (map_inputs: InputBasesToCallEffect.t) state =
    let aux_previous_call binputs hstates =
      let brelated = Domain.relate kf binputs state in
      if not Base.SetLattice.(is_included brelated (inject binputs))
      then ()
      else
        (* restrict [state] to the inputs of this call *)
        let st_filtered = Domain.filter (`Pre kf) binputs state in
        try
          let bases, outputs, i = Domain.Hashtbl.find hstates st_filtered in
          (* We have found a previous execution, in which the outputs are
             [outputs]. Copy them in [state] and return this result. *)
          let process (key,output) =
            key,
            Domain.reuse kf bases ~current_input:state ~previous_output:output
          in
          let outputs = List.map process outputs in
          raise (Result_found (outputs, i))
        with Not_found -> ()
    in
    Base.Hptset.Hashtbl.iter aux_previous_call map_inputs

  let reuse_previous_call kf state args =
    try
      let previous_kf = PreviousCalls.find kf in
      let args = List.map (function `Bottom -> None | `Value v -> Some v) args in
      let previous = ActualArgs.Map.find args previous_kf in
      find_match_in_previous kf previous state;
      Statistics.incr stat_misses kf;
      None
    with
    | Not_found ->
      Statistics.incr stat_misses kf;
      None
    | Result_found (outputs, i) ->
      Statistics.incr stat_hits kf;
      let call_result = outputs in
      Some (call_result, i)

  (* ------------------------------------------------------------------------ *)
  (*              Reload caches from another Frama-C project                  *)
  (* ------------------------------------------------------------------------ *)

  let import_call_effect (tbl: CallEffect.t) =
    let new_tbl = Domain.Hashtbl.(create (length tbl)) in
    let add entry_state (bases, outputs, i) =
      let entry_state = Domain.import entry_state in
      let bases = Eva_diff.import_bases bases in
      let outputs =
        List.map (fun (key, state) -> key, Domain.import state) outputs
      in
      Domain.Hashtbl.add new_tbl entry_state (bases, outputs, i)
    in
    Domain.Hashtbl.iter add tbl;
    new_tbl

  let import_bases_to_call_effect (tbl: InputBasesToCallEffect.t) =
    let new_tbl = Base.Hptset.Hashtbl.(create (length tbl)) in
    let add bases call_effect =
      let bases = Eva_diff.import_bases bases in
      let call_effect = import_call_effect call_effect in
      Base.Hptset.Hashtbl.add new_tbl bases call_effect;
    in
    Base.Hptset.Hashtbl.iter add tbl;
    new_tbl

  let import_calls (map: ArgsToStoredCalls.t) =
    let add key data acc =
      let key = List.map (Option.map Value.import) key in
      let data = import_bases_to_call_effect data in
      ActualArgs.Map.add key data acc
    in
    ActualArgs.Map.fold add map ActualArgs.Map.empty

  let import_cache (old_kf, old_data) =
    match Ast_diff.Kernel_function.find old_kf with
    | `Same kf ->
      begin
        try
          Self.debug ~dkey "Importing cache for function %a from function %a@."
            Kernel_function.pretty kf Kernel_function.pretty old_kf;
          let data = import_calls old_data in
          PreviousCalls.replace kf data
        with Not_found ->
          Self.debug ~dkey "Cannot import cache for function %a@."
            Kernel_function.pretty kf
      end
    | `Partial _ as diff ->
      Self.debug ~dkey "Function %a has been modified: %a"
        Kernel_function.pretty old_kf
        Ast_diff.Kernel_function.pretty_data diff
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
    let gather () =
      print_cache_size ("In save file " ^ name);
      PreviousCalls.fold (fun kf data acc -> (kf, data) :: acc) [],
      SaveCounter.get ()
    in
    let list, counter = Project.on project gather () in
    List.iter import_cache list;
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
      let saved = Project.load ~name filepath in
      check_saved_project name saved;
      Self.feedback
        "Computing AST differences between saved file and current session";
      Ast_diff.compare_from_prj saved;
      Special_variables.import saved;
      Self.feedback "Copying Eva analysis cache from save file %s" name;
      import_cached_calls_from name saved;
      print_cache_size "In current session";
      Project.remove ~project:saved ();
    with
    | Project.IOError s ->
      Self.abort "Problem while loading file %a: %s"
        Filepath.Normalized.pretty filepath s

  let prepare () =
    PreviousCalls.clear ();
    if not (Parameters.Load.is_empty ()) then
      load_cache (Parameters.Load.get ())
end


(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
