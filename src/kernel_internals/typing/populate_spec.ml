(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

type mode = ACSL | Safe | Frama_C | Skip | Other of string

type config = {
  exits: mode;
  assigns: mode;
  requires: mode;
  allocates: mode;
  terminates: mode;
}

type 'a result = Kept | Generated of 'a

type exits = (termination_kind * identified_predicate) list
type requires = identified_predicate list
type terminates = identified_predicate option

type 'a gen = (kernel_function -> spec -> 'a)
type status = Property_status.emitted_status

type 'a elem = {
  gen: 'a gen option;
  status : status option;
}

type custom_mode = {
  custom_exits: exits elem;
  custom_assigns: assigns elem;
  custom_requires: requires elem;
  custom_allocates: allocation elem;
  custom_terminates: terminates elem;
}

let custom_modes = Hashtbl.create 17

let default = Cil.default_behavior_name

let emitter =
  Emitter.create "PopulateSpec"
    [ Funspec; Property_status ] ~correctness:[] ~tuning:[]

let emit_status status ppt =
  Property_status.emit emitter ~hyps:[] ppt status

let completes_generic (type clause) completes table =
  let exception Ok of clause list in
  let collect l b = Hashtbl.find table b :: l in
  let collect bhvs =
    try let r = List.fold_left collect [] bhvs in raise (Ok r)
    with Not_found -> ()
  in
  try List.iter collect completes; None with Ok l -> Some l

let register ?gen_exits ?status_exits ?gen_assigns ?status_assigns
    ?gen_requires ?gen_allocates ?status_allocates ?gen_terminates
    ?status_terminates name =
  let f gen status = {gen; status} in
  let mode = {
    custom_exits = f gen_exits status_exits;
    custom_assigns = f gen_assigns status_assigns;
    custom_requires = f gen_requires None;
    custom_allocates = f gen_allocates status_allocates;
    custom_terminates = f gen_terminates status_terminates;
  } in
  Hashtbl.replace custom_modes name mode

let get_custom_mode mode =
  match Hashtbl.find_opt custom_modes mode with
  | None -> Kernel.abort "Mode %s is not registered" mode
  | Some custom_mode -> custom_mode

let compare_it it1 it2 =
  Cil_datatype.Term.compare it1.it_content it2.it_content

module type Generator =
sig

  type clause
  type behaviors

  val name : string
  val is_empty : clause -> bool
  val has_behavior : string -> behaviors -> bool
  val collect_behaviors : spec -> behaviors
  val completes : string list list -> behaviors -> clause list option

  val acsl_default : unit -> clause
  val safe_default : bool -> clause
  val frama_c_default : kernel_function -> clause
  val combine_default : clause list -> clause
  val custom_default : string -> kernel_function -> spec -> clause

  val emit : mode -> kernel_function -> funbehavior -> clause result -> unit

end

module Make(G : Generator) =
struct

  let combine_or_default mode kf spec table =
    if mode = ACSL then false, G.acsl_default ()
    else
      let completes_opt = G.completes spec.spec_complete_behaviors table in
      match mode, completes_opt with
      | (Safe | Frama_C | Other _), Some completes_clauses ->
        true, G.combine_default completes_clauses
      | Safe, None ->
        false, G.safe_default @@ Kernel_function.has_definition kf
      | Frama_C, None ->
        false, G.frama_c_default kf
      | Other mode, None ->
        false, G.custom_default mode kf spec
      | (Skip | ACSL), _ -> assert false

  let get_default ~warned mode kf spec =
    let table = G.collect_behaviors spec in
    if mode = Skip || G.has_behavior default table then Kept
    else
      let combined, g = combine_or_default mode kf spec table in
      if not @@ Kernel_function.has_definition kf then begin
        if combined then
          Kernel.warning ~once:true ~current:true ~wkey:Kernel.wkey_missing_spec
            "Missing %s in default behavior of prototype %a,@, \
             generating default specification from complete behaviors"
            G.name Kernel_function.pretty kf
        else if not warned && not @@ G.is_empty g then
          Kernel.warning ~once:true ~current:true ~wkey:Kernel.wkey_missing_spec
            "Missing %s in specification of prototype %a,@, \
             generating default specification, see -generated-spec-* options\
             for more info"
            G.name Kernel_function.pretty kf
      end;
      Generated g

  let emit = G.emit

end

module Exits_generator =
struct

  type clause = exits
  type behaviors = (string, clause) Hashtbl.t

  let name = "exits"

  let is_empty c = c = []

  let has_behavior name behaviors =
    Hashtbl.mem behaviors name

  let collect_behaviors spec =
    let table = Hashtbl.create 17 in
    let iter b =
      let exits = List.filter (fun (k, _ ) -> Exits = k) b.b_post_cond in
      if exits <> [] then Hashtbl.add table b.b_name exits
    in
    List.iter iter spec.spec_behavior;
    table

  let completes = completes_generic

  let acsl_default () = []

  let safe_default has_body =
    if has_body
    then [ Exits, Logic_const.(new_predicate pfalse) ]
    else []

  let frama_c_default _ =
    [ Exits, Logic_const.(new_predicate pfalse) ]

  let combine_default (clauses : clause list) =
    let collect acc clauses = List.rev_append (List.rev clauses) acc in
    let preds =
      List.sort_uniq (Cil_datatype.PredicateStructEq.compare) @@
      List.map
        (fun p -> p.ip_content.tp_statement)
        (snd @@ List.split @@ List.fold_left collect [] clauses)
    in
    [ Exits, Logic_const.new_predicate @@ Logic_const.pors preds ]

  let custom_default mode kf spec =
    let custom_mode = get_custom_mode mode in
    match custom_mode.custom_exits.gen with
    | None ->
      Kernel.warning ~once:true
        "Custom generation from mode %s not defined for exits, using \
         frama-c mode instead" mode;
      frama_c_default kf
    | Some f -> f kf spec

  let emit_status kf bhv exits status =
    let ppt_l =
      List.map (fun e -> Property.ip_of_ensures kf Kglobal bhv e) exits
    in
    List.iter (emit_status status) ppt_l

  let emit mode kf bhv = function
    | Kept | Generated [] -> ()
    | Generated _ when Kernel_function.has_definition kf -> ()
    | Generated exits ->
      match mode with
      | Skip | ACSL -> assert false
      | Safe -> ()
      | Frama_C -> emit_status kf bhv exits Property_status.Dont_know
      | Other mode ->
        let custom_mode = get_custom_mode mode in
        match custom_mode.custom_exits.status with
        | None ->
          Kernel.warning ~once:true
            "Custom status from mode %s not defined for exits" mode;
          ()
        | Some pst -> emit_status kf bhv exits pst

end

module Assigns_generator =
struct
  type clause = assigns
  type behaviors = (string, assigns) Hashtbl.t

  let name = "assigns"

  let is_empty c = c = WritesAny

  let has_behavior name behaviors =
    Hashtbl.mem behaviors name

  let collect_behaviors spec =
    let table = Hashtbl.create 17 in
    let iter { b_name; b_assigns } =
      if b_assigns <> WritesAny then Hashtbl.add table b_name b_assigns
    in
    List.iter iter spec.spec_behavior;
    table

  let completes = completes_generic

  let acsl_default () =
    WritesAny

  let safe_default has_body =
    if has_body
    then Writes []
    else WritesAny

  let frama_c_default kf =
    if Kernel_function.has_definition kf then
      acsl_default () (* TODO: use genassigns *)
    else Writes (Infer_annotations.assigns_from_prototype kf)

  let compare_deps d1 d2 =
    match d1, d2 with
    | FromAny, FromAny -> 0
    | FromAny, _ -> 1
    | _, FromAny -> -1
    | From l1, From l2 ->
      Extlib.list_compare compare_it l1 l2

  let compare_from (f1, d1) (f2, d2) =
    let r = compare_it f1 f2 in
    if r <> 0 then r else compare_deps d1 d2

  let combine_default clauses =
    (* Note: combination is made on a set of complete behaviors in the sens of
       [completes], thus here all clauses are [Writes ...] *)
    let collect acc = function
      | Writes l -> List.rev_append (List.rev l) acc
      | _ -> assert false
    in
    let deps = function
      | FromAny -> FromAny
      | From l -> From (List.sort_uniq compare_it l)
    in
    let froms =
      List.map (fun (e, ds) -> e, deps ds) @@ List.fold_left collect [] clauses
    in
    Writes (List.sort_uniq compare_from froms)

  let custom_default mode kf spec =
    let custom_mode = get_custom_mode mode in
    match custom_mode.custom_assigns.gen with
    | None ->
      Kernel.warning  ~once:true
        "Custom generation from mode %s not defined for assigns, using \
         frama-c mode instead" mode;
      frama_c_default kf
    | Some f -> f kf spec

  let emit_status kf bhv assigns status =
    let ppt_opt =
      Property.ip_of_assigns kf Kglobal
        (Property.Id_contract (Datatype.String.Set.empty,bhv)) assigns
    in
    Option.iter (emit_status status) ppt_opt;
    match assigns with
    | WritesAny -> assert false
    | Writes froms ->
      let emit from =
        let ppt_opt =
          Property.ip_of_from
            kf Kglobal
            (Property.Id_contract (Datatype.String.Set.empty,bhv)) from
        in
        Option.iter (emit_status status) ppt_opt
      in
      List.iter emit froms

  let emit mode kf bhv = function
    | Kept | Generated WritesAny -> ()
    | Generated _ when Kernel_function.has_definition kf -> ()
    | Generated assigns ->
      match mode with
      | Skip | ACSL -> assert false
      | Safe -> ()
      | Frama_C -> emit_status kf bhv assigns Property_status.Dont_know
      | Other mode ->
        let custom_mode = get_custom_mode mode in
        match custom_mode.custom_assigns.status with
        | None ->
          Kernel.warning ~once:true
            "Custom status from mode %s not defined for assigns" mode;
          ()
        | Some pst -> emit_status kf bhv assigns pst

end

module Requires_generator =
struct

  type clause = requires
  type behaviors = (string, clause) Hashtbl.t

  let name = "requires"

  let is_empty c = c = []

  let has_behavior name behaviors =
    Hashtbl.mem behaviors name

  let collect_behaviors spec =
    let table = Hashtbl.create 17 in
    let iter { b_name; b_requires } =
      if b_requires <> [] then Hashtbl.add table b_name b_requires
    in
    List.iter iter spec.spec_behavior;
    table

  let completes = completes_generic

  let acsl_default () = []

  let safe_default has_body =
    if has_body
    then []
    else [ Logic_const.(new_predicate pfalse) ]

  let frama_c_default _ =
    acsl_default ()

  let combine_default (clauses : clause list) =
    let flatten_require clause =
      List.map (fun p -> p.ip_content.tp_statement) clause
      |> List.sort_uniq Cil_datatype.PredicateStructEq.compare
      |> Logic_const.pands
    in
    let preds =
      List.map flatten_require clauses
      |> Logic_const.pors
    in
    [ Logic_const.new_predicate preds ]

  let custom_default mode kf spec =
    let custom_mode = get_custom_mode mode in
    match custom_mode.custom_requires.gen with
    | None ->
      Kernel.warning ~once:true
        "Custom generation from mode %s not defined for requires, using \
         frama-c mode instead" mode;
      frama_c_default kf
    | Some f -> f kf spec

  let emit _ _ _ _ = ()

end

module Allocates_generator =
struct
  type clause = allocation
  type behaviors = (string, allocation) Hashtbl.t

  let name = "allocates"

  let is_empty c = c = FreeAllocAny

  let has_behavior name behaviors =
    Hashtbl.mem behaviors name

  let collect_behaviors spec =
    let table = Hashtbl.create 17 in
    let iter { b_name; b_allocation } =
      if b_allocation <> FreeAllocAny then Hashtbl.add table b_name b_allocation
    in
    List.iter iter spec.spec_behavior;
    table

  let completes = completes_generic

  let acsl_default () =
    FreeAlloc([],[])

  let safe_default has_body =
    if has_body
    then FreeAlloc([],[])
    else FreeAllocAny

  let frama_c_default _ =
    acsl_default ()

  let combine_default clauses =
    (* Note: combination is made on a set of complete behaviors in the sens of
       [completes], thus here all clauses are [FreeAlloc ...] *)
    let collect (facc, aacc) = function
      | FreeAlloc(f, a) ->
        List.rev_append (List.rev f) facc, List.rev_append (List.rev a) aacc
      | _ -> assert false
    in
    let f, a = List.fold_left collect ([],[]) clauses in
    let f = List.sort_uniq compare_it f in
    let a = List.sort_uniq compare_it a in
    FreeAlloc(f, a)

  let custom_default mode kf spec =
    let custom_mode = get_custom_mode mode in
    match custom_mode.custom_allocates.gen with
    | None ->
      Kernel.warning ~once:true
        "Custom generation from mode %s not defined for allocates, using \
         frama-c mode instead" mode;
      frama_c_default kf
    | Some f -> f kf spec

  let emit_status kf bhv allocates status =
    let ppt_opt =
      Property.ip_of_allocation kf Kglobal
        (Property.Id_contract (Datatype.String.Set.empty,bhv)) allocates
    in
    Option.iter (emit_status status) ppt_opt

  let emit mode kf bhv = function
    | Kept | Generated FreeAllocAny -> ()
    | Generated _ when Kernel_function.has_definition kf -> ()
    | Generated allocates ->
      match mode with
      | Skip -> assert false
      | Safe -> ()
      | ACSL ->
        emit_status kf bhv allocates Property_status.True
      | Frama_C ->
        emit_status kf bhv allocates Property_status.Dont_know
      | Other mode ->
        let custom_mode = get_custom_mode mode in
        match custom_mode.custom_allocates.status with
        | None ->
          Kernel.warning ~once:true
            "Custom status from mode %s not defined for allocates" mode;
          ()
        | Some pst -> emit_status kf bhv allocates pst

end

module Terminates_generator =
struct

  type clause = terminates
  type behaviors = bool

  let name = "terminates"

  let is_empty c = c = None

  let has_behavior _ behaviors =
    behaviors

  let collect_behaviors spec =
    None <> spec.spec_terminates

  let completes _ _ = None

  let acsl_default () =
    Some(Logic_const.(new_predicate ptrue))

  let safe_default has_body =
    if has_body
    then Some(Logic_const.(new_predicate ptrue))
    else Some(Logic_const.(new_predicate pfalse))

  let frama_c_default _ =
    acsl_default ()

  let combine_default _ =
    assert false

  let custom_default mode kf spec =
    let custom_mode = get_custom_mode mode in
    match custom_mode.custom_terminates.gen with
    | None ->
      Kernel.warning ~once:true
        "Custom generation from mode %s not defined for terminates, using \
         frama-c mode instead" mode;
      frama_c_default kf
    | Some f -> f kf spec

  let emit_status kf _ terminates status =
    match terminates with
    | None -> assert false
    | Some terminates ->
      Property.ip_of_terminates kf Kglobal terminates
      |> emit_status status

  let emit mode kf bhv = function
    | Kept | Generated None -> ()
    | Generated _ when Kernel_function.has_definition kf -> ()
    | Generated terminates ->
      match mode with
      | Skip -> assert false
      | ACSL ->
        emit_status kf bhv terminates Property_status.True
      | Safe | Frama_C ->
        emit_status kf bhv terminates Property_status.Dont_know
      | Other mode ->
        let custom_mode = get_custom_mode mode in
        match custom_mode.custom_terminates.status with
        | None ->
          Kernel.warning ~once:true
            "Custom status from mode %s not defined for terminates" mode;
          ()
        | Some pst -> emit_status kf bhv terminates pst

end

module Exits = Make(Exits_generator)
module Assigns = Make(Assigns_generator)
module Requires = Make(Requires_generator)
module Allocates = Make(Allocates_generator)
module Terminates = Make(Terminates_generator)

let get_mode = function
  | "frama-c" -> Frama_C
  | "acsl" -> ACSL
  | "safe" -> Safe
  | "skip" -> Skip
  | s -> Other s

let build_config mode =
  (* For now Allocates are skipped by default *)
  let skip_mode = match mode with Other _ -> mode | _ -> Skip in
  {
    exits = mode;
    assigns = mode;
    requires = mode;
    allocates = skip_mode;
    terminates = mode;
  }

let get_config_mode () =
  build_config @@ get_mode @@ Kernel.GeneratedSpecMode.get ()

let get_config () =
  let default = get_config_mode () in
  let collect (k,v) conf =
    let mode = get_mode (Option.get v) in
    match k with
    | "exits" -> {conf with exits = mode}
    | "assigns" -> {conf with assigns = mode}
    | "requires" -> {conf with requires = mode}
    | "allocates" -> {conf with allocates = mode}
    | "terminates" -> {conf with terminates = mode}
    | s ->
      Kernel.abort
        "@['%s'@] is not a valid key for -generated-spec-custom.@, Accepted \
         keys are 'exits', 'assigns', 'requires', 'allocates' and \
         'terminates'." s
  in
  Kernel.GeneratedSpecCustom.fold collect default

let do_populate ~warned kf original_spec =
  let config = get_config () in
  let apply get_default mode =
    get_default ~warned mode kf original_spec
  in
  let exits = apply Exits.get_default config.exits in
  let assigns = apply Assigns.get_default config.assigns in
  let requires = apply Requires.get_default config.requires in
  let allocates = apply Allocates.get_default config.allocates in
  let terminates = apply Terminates.get_default config.terminates in

  let generated original = function
    | Kept -> original
    | Generated g -> g
  in

  let bhv = Cil.mk_behavior () in
  let bhv = { bhv with b_post_cond = generated bhv.b_post_cond exits } in
  let bhv = { bhv with b_assigns = generated bhv.b_assigns assigns } in
  let bhv = { bhv with b_requires = generated bhv.b_requires requires } in
  let bhv = { bhv with b_allocation = generated bhv.b_allocation allocates } in

  let spec = Cil.empty_funspec () in
  let spec = { spec with spec_behavior = [ bhv ] } in
  let spec =
    { spec with spec_terminates = generated spec.spec_terminates terminates } in
  Annotations.add_spec emitter kf spec;
  Exits.emit config.exits kf bhv exits;
  Assigns.emit config.assigns kf bhv assigns;
  Requires.emit config.assigns kf bhv requires;
  Allocates.emit config.allocates kf bhv allocates;
  Terminates.emit config.terminates kf bhv terminates

module Is_populated =
  State_builder.Hashtbl
    (Kernel_function.Hashtbl)
    (Datatype.Unit)
    (struct
      let size = 17
      let dependencies = [ Annotations.funspec_state ]
      let name = "Populate_spec.Is_populated"
    end)

let () = Ast.add_linked_state Is_populated.self

let warn_empty kf =
  Kernel.warning ~once:true ~current:true ~wkey:Kernel.wkey_missing_spec
    "Neither code nor specification for function %a,@, \
     generating default specifications from the prototype"
    Kernel_function.pretty kf;
  true

let populate_funspec ~force kf spec =
  let is_proto = not @@ Kernel_function.has_definition kf in
  let skip_generation = not @@ Kernel.GenerateDefaultSpec.get () in
  let is_empty_spec = Cil.is_empty_funspec spec in
  let skip_proto = is_proto && not force && is_empty_spec in
  if (not force && skip_generation) || Is_populated.mem kf || skip_proto
  then false
  else begin
    let warned = if is_proto && is_empty_spec then warn_empty kf else false in
    do_populate ~warned kf spec;
    Is_populated.add kf ();
    true
  end

let () = Annotations.populate_spec_ref := populate_funspec ~force:true
