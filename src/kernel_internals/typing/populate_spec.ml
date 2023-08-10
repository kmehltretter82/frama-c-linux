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

type mode =
  | ACSL | Safe | Frama_C (* Modes available for specification generation. *)
  | Skip (* Internally used to skip generation. *)
  | Other of string (* Allow user to use a custom mode, see {!register}. *)
(* Allow customization, each clause can be handled with a different [mode]. *)
type config = {
  exits: mode;
  assigns: mode;
  requires: mode;
  allocates: mode;
  terminates: mode;
}

(* Either keep old specification or generate a new one. Existing specification
   from complete behaviors can be combined and used for default behavior. *)
type 'a result = Kept | Generated of 'a

type exits = (termination_kind * identified_predicate) list
type assigns = Cil_types.assigns
type requires = identified_predicate list
type allocation = Cil_types.allocation
type terminates = identified_predicate option

(* Generation function type and status. *)
type 'a gen = (kernel_function -> spec -> 'a)
type status = Property_status.emitted_status

(* For each clause, we need a generation function and a status to be emitted. *)
type 'a elem = {
  gen: 'a gen option;
  status : status option;
}

(* Allow user to create a mode by choosing how each clause should be generated
   and which status to emit. *)
type custom_mode = {
  custom_exits: exits elem;
  custom_assigns: assigns elem;
  custom_requires: requires elem;
  custom_allocates: allocation elem;
  custom_terminates: terminates elem;
}

(* Used to store custom modes. *)
let custom_modes = Hashtbl.create 17

let default = Cil.default_behavior_name

let emitter =
  Emitter.create "PopulateSpec"
    [ Funspec; Property_status ] ~correctness:[] ~tuning:[]

(* Emit [status] on the property [ppt]. *)
let emit_status status ppt =
  Property_status.emit emitter ~hyps:[] ppt status

(* Generic completes function for {!Generator.completes}. *)
let completes_generic (type clause) completes table =
  let exception Ok of clause list in
  let collect l b = Hashtbl.find table b :: l in
  let collect bhvs =
    try let r = List.fold_left collect [] bhvs in raise (Ok r)
    with Not_found -> ()
  in
  try List.iter collect completes; None with Ok l -> Some l

(* Register a new mode (or replace an existing one). *)
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

(* Return a mode from the registered ones if it exists. *)
let get_custom_mode mode =
  match Hashtbl.find_opt custom_modes mode with
  | None -> Kernel.abort "Mode %s is not registered" mode
  | Some custom_mode -> custom_mode

(* Use this instead of Identified_term.compare. *)
let compare_it it1 it2 =
  Cil_datatype.Term.compare it1.it_content it2.it_content

(* Return true if [kf] is a builtin of Frama-C. *)
let is_frama_c_builtin kf =
  Kernel_function.get_vi kf |> Cil_builtins.is_builtin
  ||Kernel_function.get_name kf |> Cil_builtins.is_special_builtin

(* Return true if [kf] is a from the stdblib of Frama-C. *)
let is_frama_c_stdlib kf =
  (Kernel_function.get_vi kf).vattr |> Cil.is_in_libc

(* Return true if [kf] is either from frama-c's stdlib or builtinds. *)
let is_part_of_frama_c kf =
  is_frama_c_builtin kf || is_frama_c_stdlib kf

(* This module is used to define clauses generators. *)
module type Generator =
sig

  (* Generator's clause : exits, assigns, requires, allocation or terminates. *)
  type clause
  (* Store informations regarding original specification clauses. *)
  type behaviors

  (* Used for messages in logs/warnings, etc. *)
  val name : string
  (* Used to check if we actually generated something. *)
  val is_empty : clause -> bool

  (* Return true if default behavior contains this Generator's clause. *)
  val has_default_behavior : behaviors -> bool
  (* Collect all clauses from function specification. *)
  val collect_behaviors : spec -> behaviors
  (* Collect all clauses from complete behaviors. *)
  val completes : string list list -> behaviors -> clause list option

  (* Generate a default clause in ACSL mode. *)
  val acsl_default : unit -> clause
  (* Generate a default clause in Safe mode. *)
  val safe_default : kernel_function -> clause
  (* Generate a default clause in Frama_C mode. *)
  val frama_c_default : kernel_function -> clause
  (* Generate a default clause in Other mode. *)
  val custom_default : string -> kernel_function -> spec -> clause

  (* Combine clauses from completes behaviors to generate clauses inside
     default behavior. *)
  val combine_default : clause list -> clause

  (* Emit property status depending on the selected mode. *)
  val emit : mode -> kernel_function -> funbehavior -> clause result -> unit

end

(* Build Generators. *)
module Make(G : Generator) =
struct

  (* Either combine existing clauses or generate new ones depending on the
     selected mode and original specification. *)
  let combine_or_default mode kf spec table =
    if mode = ACSL then false, G.acsl_default ()
    else
      let completes_opt = G.completes spec.spec_complete_behaviors table in
      match mode, completes_opt with
      | (Safe | Frama_C | Other _), Some completes_clauses ->
        true, G.combine_default completes_clauses
      | Safe, None ->
        false, G.safe_default kf
      | Frama_C, None ->
        false, G.frama_c_default kf
      | Other mode, None ->
        false, G.custom_default mode kf spec
      | (Skip | ACSL), _ -> assert false

  (* Emit warnings depending on performed actions. *)
  let warn ~combined ~warned kf g =
    let has_body = Kernel_function.has_definition kf in
    (* Only warn for prototypes not in frama-c's stdlib and builtins. *)
    if not has_body && not @@ is_part_of_frama_c kf then
      let is_empty = G.is_empty g in
      let name = G.name in
      if combined then begin
        if is_empty || warned then assert false; (* Should not happen *)
        Kernel.warning ~once:true ~current:true ~wkey:Kernel.wkey_missing_spec
          "Missing %s in default behavior of prototype %a,@, \
           generating default specification from complete behaviors"
          name Kernel_function.pretty kf
      end
      else if not warned && not is_empty then
        Kernel.warning ~once:true ~current:true ~wkey:Kernel.wkey_missing_spec
          "Missing %s in specification of prototype %a,@, \
           generating default specification, see -generated-spec-* options \
           for more info"
          name Kernel_function.pretty kf

  (* Returns a new clause as [Generated g] of [Kept] is no action is needed. *)
  let get_default ~warned mode kf spec =
    let table = G.collect_behaviors spec in
    if mode = Skip || G.has_default_behavior table then Kept
    else
      let combined, g = combine_or_default mode kf spec table in
      warn ~warned ~combined kf g;
      Generated g

  (* Interface to call [G.emit]. *)
  let emit = G.emit

end

(*******************************************************************)
(* *********************** Exits generator *********************** *)
(* |-------------------------------------------------------------| *)
(* |     ACSL      |    Frama-c   |     Safe      |     Other    | *)
(* |-------|-------|-------|------|-------|-------|-------|------| *)
(* | Proto | Body  | Proto | Body | Proto | Body  | Proto | Body | *)
(* |-------|-------|-------|------|-------|-------|-------|------| *)
(* | false | false | ACSL  | ACSL | ----- | false |  ???  |  ??  | *)
(* |-------------------------------------------------------------| *)
(* *****************************************************************)
(* *** Status emitted on prototypes ****)
(* |---------------------------------| *)
(* | ACSL |  Frama-c  | Safe | Other | *)
(* |------|-----------|------|-------| *)
(* | True | Dont_know | ---- |  ???  | *)
(* |---------------------------------| *)
(***************************************)
module Exits_generator =
struct

  type clause = exits
  type behaviors = (string, clause) Hashtbl.t

  let name = "exits"

  let is_empty c = c = []

  let has_default_behavior behaviors =
    Hashtbl.mem behaviors default

  let collect_behaviors spec =
    let table = Hashtbl.create 17 in
    let iter b =
      let exits = List.filter (fun (k, _ ) -> Exits = k) b.b_post_cond in
      if exits <> [] then Hashtbl.add table b.b_name exits
    in
    List.iter iter spec.spec_behavior;
    table

  let completes = completes_generic

  let acsl_default () =
    [ Exits, Logic_const.(new_predicate pfalse) ]

  let safe_default kf =
    if Kernel_function.has_definition kf
    then [ Exits, Logic_const.(new_predicate pfalse) ]
    else []

  let frama_c_default _ =
    acsl_default ()

  let combine_default (clauses : clause list) =
    let collect acc clauses = List.rev_append (List.rev clauses) acc in
    let preds =
      List.map
        (fun p -> p.ip_content.tp_statement)
        (List.fold_left collect [] clauses |> List.split |> snd)
      |> List.sort_uniq (Cil_datatype.PredicateStructEq.compare)
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
      | Skip -> assert false
      | Safe -> ()
      | ACSL | Frama_C -> emit_status kf bhv exits Property_status.Dont_know
      | Other mode ->
        let custom_mode = get_custom_mode mode in
        match custom_mode.custom_exits.status with
        | None ->
          Kernel.warning ~once:true
            "Custom status from mode %s not defined for exits" mode;
          ()
        | Some pst -> emit_status kf bhv exits pst

end


(*********************************************************************)
(* *********************** Assigns generator *********************** *)
(* |---------------------------------------------------------------| *)
(* |     ACSL      |    Frama-c   |      Safe       |     Other    | *)
(* |-------|-------|-------|------|-------|---------|-------|------| *)
(* | Proto | Body  | Proto | Body | Proto |  Body   | Proto | Body | *)
(* |-------|-------|-------|------|-------|---------|-------|------| *)
(* |  Any  |  Any  | Auto  | ACSL |  Any  | Nothing |  ???  |  ??  | *)
(* |---------------------------------------------------------------| *)
(* *******************************************************************)
(* *** Status emitted on prototypes ****)
(* |---------------------------------| *)
(* | ACSL |  Frama-c  | Safe | Other | *)
(* |------|-----------|------|-------| *)
(* | ---- | Dont_know | ---- |  ???  | *)
(* |---------------------------------| *)
(***************************************)
module Assigns_generator =
struct

  type clause = assigns
  type behaviors = (string, assigns) Hashtbl.t

  let name = "assigns"

  let is_empty c = c = WritesAny

  let has_default_behavior behaviors =
    Hashtbl.mem behaviors default

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

  let safe_default kf =
    if Kernel_function.has_definition kf
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
      List.fold_left collect [] clauses
      |> List.map (fun (e, ds) -> e, deps ds)
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


(*****************************************************************)
(* ********************* Requires generator ******************** *)
(* |-----------------------------------------------------------| *)
(* |     ACSL     |    Frama-c   |     Safe     |     Other    | *)
(* |-------|------|-------|------|-------|------|-------|------| *)
(* | Proto | Body | Proto | Body | Proto | Body | Proto | Body | *)
(* |-------|------|-------|------|-------|------|-------|------| *)
(* | ----- | ---- | ----- | ---- | false | ---- |  ???  |  ??  | *)
(* |-----------------------------------------------------------| *)
(* ***************************************************************)
(* ** Status emitted on prototypes ***)
(* |-------------------------------| *)
(* | ACSL | Frama-c | Safe | Other | *)
(* |------|---------|------|-------| *)
(* | ---- | ------- | ---- | ----- | *)
(* |-------------------------------| *)
(*************************************)
module Requires_generator =
struct

  type clause = requires
  type behaviors = (string, clause) Hashtbl.t

  let name = "requires"

  let is_empty c = c = []

  let has_default_behavior behaviors =
    Hashtbl.mem behaviors default

  let collect_behaviors spec =
    let table = Hashtbl.create 17 in
    let iter { b_name; b_requires } =
      if b_requires <> [] then Hashtbl.add table b_name b_requires
    in
    List.iter iter spec.spec_behavior;
    table

  let completes = completes_generic

  let acsl_default () = []

  let safe_default kf =
    if Kernel_function.has_definition kf
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


(*************************************************************************)
(* ************************* Allocates generator *********************** *)
(* |-------------------------------------------------------------------| *)
(* |       ACSL        |    Frama-c   |      Safe       |     Other    | *)
(* |---------|---------|-------|------|-------|---------|-------|------| *)
(* |  Proto  |  Body   | Proto | Body | Proto |  Body   | Proto | Body | *)
(* |---------|---------|-------|------|-------|---------|-------|------| *)
(* | Nothing | Nothing | ACSL  | ACSL |  Any  | Nothing |  ???  |  ??  | *)
(* |-------------------------------------------------------------------| *)
(* ***********************************************************************)
(* **** Status emitted on prototypes ***)
(* |---------------------------------| *)
(* | ACSL |  Frama-c  | Safe | Other | *)
(* |------|-----------|------|-------| *)
(* | True | Dont_know | ---- |  ???  | *)
(* |---------------------------------| *)
(***************************************)
module Allocates_generator =
struct

  type clause = allocation
  type behaviors = (string, allocation) Hashtbl.t

  let name = "allocates"

  let is_empty c = c = FreeAllocAny

  let has_default_behavior behaviors =
    Hashtbl.mem behaviors default

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

  let safe_default kf =
    if Kernel_function.has_definition kf
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

(*****************************************************************)
(* ******************** Terminates generated ******************* *)
(* |-----------------------------------------------------------| *)
(* |     ACSL     |    Frama-c   |     Safe     |     Other    | *)
(* |-------|------|-------|------|-------|------|-------|------| *)
(* | Proto | Body | Proto | Body | Proto | Body | Proto | Body | *)
(* |-------|------|-------|------|-------|------|-------|------| *)
(* | true  | true | ACSL  | ACSL | false | true |  ???  |  ??  | *)
(* |-----------------------------------------------------------| *)
(* ***************************************************************)
(* ****** Status emitted on prototypes ******)
(* |--------------------------------------| *)
(* | ACSL |  Frama-c  |    Safe   | Other | *)
(* |------|-----------|-----------|-------| *)
(* | True | Dont_know | Dont_know |  ???  | *)
(* |--------------------------------------| *)
(********************************************)
module Terminates_generator =
struct

  type clause = terminates
  type behaviors = bool

  let name = "terminates"

  let is_empty c = c = None

  let has_default_behavior behaviors =
    behaviors

  let collect_behaviors spec =
    None <> spec.spec_terminates

  let completes _ _ = None

  let acsl_default () =
    Some(Logic_const.(new_predicate ptrue))

  let safe_default kf =
    if Kernel_function.has_definition kf
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

(* Convert string from parameter [-generated-spec-mode] to [mode]. *)
let get_mode = function
  | "frama-c" -> Frama_C
  | "acsl" -> ACSL
  | "safe" -> Safe
  | "skip" -> Skip
  | s -> Other s

(* Given a [mode], returns the configuration for each clause. *)
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

(* Build configuration from parameter [-generated-spec-mode]. *)
let get_config_mode () =
  Kernel.GeneratedSpecMode.get () |> get_mode |> build_config

(* Build the default configuration, then select modes depending on the
   parameter [-generated-spec-custom]. *)
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

(* Perform generation of all clauses, adds them to the original specification,
   and emit property status for each of them. *)
let do_populate ~warned kf original_spec =
  let config =
    if is_frama_c_builtin kf then build_config Frama_C
    else if is_frama_c_stdlib kf then build_config ACSL
    else get_config ()
  in
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

(* Hashtbl used to memorize which kernel function has been populated. *)
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

(* Performs specification on [kf] if all requirements are met :
   - force is [true]
     OR
     [-generate-default-spec] is [true] (by default).
   - Function has not been populated yet.
   - force is [true]
     OR
     [kf] is not a prototype
     OR
     [kf]'s specification is empty
*)
let populate_funspec ~force kf spec =
  let has_body = Kernel_function.has_definition kf in
  let is_empty_spec = Cil.is_empty_funspec spec in
  if (force || Kernel.GenerateDefaultSpec.get ())
  && not @@ Is_populated.mem kf
  && (force || has_body || not @@ is_empty_spec) then begin
    let warned =
      if not @@ is_part_of_frama_c kf && not @@ has_body && is_empty_spec
      then warn_empty kf
      else false
    in
    do_populate ~warned kf spec;
    Is_populated.add kf ();
    true
  end
  else false

(* Annotations always force specification generation when calling for
   populate_funspec. *)
let () = Annotations.populate_spec_ref := populate_funspec ~force:true
