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

type mode = ACSL | Safe | Frama_C | Other of string
type 'a result = Kept | Generated of 'a

let default = Cil.default_behavior_name

module type Generator =
sig

  type clause
  type behaviors

  val has_behavior : string -> behaviors -> bool
  val collect_behaviors : spec -> behaviors
  val completes : string list list -> behaviors -> clause list option

  val acsl_default : unit -> clause
  val safe_default : bool -> clause
  val frama_c_default : unit -> clause
  val combine_default : clause list -> clause
  val custom_default : string -> kernel_function -> spec -> clause

end

module Make(G : Generator) =
struct
  let get_default mode kf spec =
    let table = G.collect_behaviors spec in
    if G.has_behavior default table then
      Kept
    else if mode = ACSL then
      Generated (G.acsl_default ())
    else
      match G.completes spec.spec_complete_behaviors table with
      | Some l ->
        Generated (G.combine_default l)
      | None when mode = Safe ->
        Generated(G.safe_default @@ Kernel_function.has_definition kf)
      | None when mode = Frama_C ->
        Generated(G.frama_c_default ())
      | None ->
        match mode with
        | ACSL | Safe | Frama_C -> assert false
        | Other mode ->
          Generated(G.custom_default mode kf spec)
end

module Terminates_generator =
struct

  type clause = identified_predicate option
  type behaviors = bool

  let has_behavior name behaviors =
    if name = default then behaviors else false

  let collect_behaviors spec =
    None <> spec.spec_terminates

  let completes _ _ = None

  let acsl_default () =
    Some(Logic_const.(new_predicate ptrue))

  let safe_default has_body =
    if has_body
    then Some(Logic_const.(new_predicate ptrue))
    else Some(Logic_const.(new_predicate pfalse))

  let frama_c_default () =
    acsl_default ()

  let combine_default _ =
    acsl_default ()

  let custom_default _mode _kf _spec =
    acsl_default ()

end

module Exits_generator =
struct

  type clause = (termination_kind * identified_predicate) list
  type behaviors = (string, clause) Hashtbl.t

  let has_behavior name behaviors =
    Hashtbl.mem behaviors name

  let collect_behaviors spec =
    let table = Hashtbl.create 17 in
    let iter b =
      let exits = List.filter (fun (k, _ ) -> Exits = k) b.b_post_cond in
      if exits <> [] then Hashtbl.add table b.b_name exits
    in
    List.iter iter spec.spec_behavior ;
    table

  let completes completes table =
    let exception Ok of clause list in
    let collect l b = Hashtbl.find table b :: l in
    let collect bhvs =
      try let r = List.fold_left collect [] bhvs in raise (Ok r)
      with Not_found -> ()
    in
    try List.iter collect completes ; None with Ok l -> Some l

  let acsl_default () = []

  let safe_default has_body =
    if has_body
    then [ Exits, Logic_const.(new_predicate pfalse) ]
    else []

  let frama_c_default () =
    [ Exits, Logic_const.(new_predicate pfalse) ]

  let combine_default (clauses : clause list) =
    let collect acc clauses = List.rev_append (List.rev clauses) acc in
    let preds =
      List.sort_uniq (Cil_datatype.Predicate.compare) @@
      List.map
        (fun p -> p.ip_content.tp_statement)
        (snd @@ List.split @@ List.fold_left collect [] clauses)
    in
    [ Exits, Logic_const.new_predicate @@ Logic_const.pors preds ]

  let custom_default  _mode _kf _spec =
    acsl_default ()

end

module Assigns_generator =
struct
  type clause = assigns
  type behaviors = (string, assigns) Hashtbl.t

  let has_behavior name behaviors =
    Hashtbl.mem behaviors name

  let collect_behaviors spec =
    let table = Hashtbl.create 17 in
    let iter { b_name ; b_assigns } =
      if b_assigns <> WritesAny then Hashtbl.add table b_name b_assigns
    in
    List.iter iter spec.spec_behavior ;
    table

  let completes (completes : string list list) (table : behaviors) =
    let assigns = function
      | WritesAny -> raise Not_found
      | Writes l -> Writes l
    in
    let exception Ok of assigns list in
    let collect l b = (assigns @@ Hashtbl.find table b) :: l in
    let collect bhvs =
      try let r = List.fold_left collect [] bhvs in raise (Ok r)
      with Not_found -> ()
    in
    try List.iter collect completes ; None with Ok l -> Some l

  let acsl_default () =
    WritesAny

  let safe_default has_body =
    if has_body
    then Writes []
    else WritesAny

  let frama_c_default () =
    acsl_default () (* todo : port infer annotations *)

  let compare_deps d1 d2 =
    match d1, d2 with
    | FromAny, FromAny -> 0
    | FromAny, _ -> 1
    | _, FromAny -> -1
    | From l1, From l2 ->
      Extlib.list_compare Cil_datatype.Identified_term.compare l1 l2

  let compare_from (f1, d1) (f2, d2) =
    let r = Cil_datatype.Identified_term.compare f1 f2 in
    if r <> 0 then compare_deps d1 d2 else r

  let combine_default clauses =
    (* Note: combination is made on a set of complete behaviors in the sens of
       [completes], thus here all clauses are [Writes ...] *)
    let collect acc = function
      | Writes l -> List.rev_append (List.rev l) acc
      | _ -> assert false
    in
    let deps = function
      | FromAny -> FromAny
      | From l -> From (List.sort_uniq Cil_datatype.Identified_term.compare l)
    in
    let froms =
      List.map (fun (e, ds) -> e, deps ds) @@ List.fold_left collect [] clauses
    in
    Writes (List.sort_uniq compare_from froms)

  let custom_default _mode _kf _spec =
    acsl_default ()

end

module Allocation_generator =
struct
  type clause = allocation
  type behaviors = (string, allocation) Hashtbl.t

  let has_behavior name behaviors =
    Hashtbl.mem behaviors name

  let collect_behaviors spec =
    let table = Hashtbl.create 17 in
    let iter { b_name ; b_allocation } =
      if b_allocation <> FreeAllocAny then Hashtbl.add table b_name b_allocation
    in
    List.iter iter spec.spec_behavior ;
    table

  let completes (completes : string list list) (table : behaviors) =
    let allocation = function
      | FreeAllocAny -> raise Not_found
      | alloc -> alloc
    in
    let exception Ok of allocation list in
    let collect l b = (allocation @@ Hashtbl.find table b) :: l in
    let collect bhvs =
      try let r = List.fold_left collect [] bhvs in raise (Ok r)
      with Not_found -> ()
    in
    try List.iter collect completes ; None with Ok l -> Some l

  let acsl_default () =
    FreeAlloc([],[])

  let safe_default has_body =
    if has_body
    then FreeAlloc([],[])
    else FreeAllocAny

  let frama_c_default () =
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
    let f = List.sort_uniq Cil_datatype.Identified_term.compare f in
    let a = List.sort_uniq Cil_datatype.Identified_term.compare a in
    FreeAlloc(f, a)

  let custom_default _mode _kf _spec =
    acsl_default ()

end

module Terminates = Make(Terminates_generator)
module Exits = Make(Exits_generator)
module Assigns = Make(Assigns_generator)
module Allocation = Make(Allocation_generator)

let emitter = Emitter.create "gen" [ Funspec ] ~correctness:[] ~tuning:[]

let do_populate kf original_spec =
  let mode = Frama_C in

  let exits = Exits.get_default mode kf original_spec in
  let assigns = Assigns.get_default mode kf original_spec in
  let allocation = Allocation.get_default mode kf original_spec in
  let terminates = Terminates.get_default mode kf original_spec in

  let generated original = function
    | Kept -> original
    | Generated g -> g
  in

  let bhv = Cil.mk_behavior () in
  let bhv = { bhv with b_post_cond = generated bhv.b_post_cond exits } in
  let bhv = { bhv with b_assigns = generated bhv.b_assigns assigns } in
  let bhv = { bhv with b_allocation = generated bhv.b_allocation allocation } in

  let spec = Cil.empty_funspec () in
  let spec = { spec with spec_behavior = [ bhv ] } in
  let spec =
    { spec with spec_terminates = generated spec.spec_terminates terminates } in
  Annotations.add_spec emitter kf spec

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

let populate_funspec kf spec =
  if Is_populated.mem kf then false
  else begin
    do_populate kf spec ;
    Is_populated.add kf () ;
    true
  end

let () = Annotations.populate_spec_ref := populate_funspec
