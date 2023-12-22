(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

(* -------------------------------------------------------------------------- *)
(* --- Interactive Proof Engine                                           --- *)
(* -------------------------------------------------------------------------- *)

type node = {
  tree : Wpo.t ; (* root, to check consistency *)
  goal : Wpo.t ; (* only GoalAnnot of a sequent *)
  child : string option ; (* child name from parent node *)
  parent : node option ;
  mutable script : script ;
  mutable stats : Stats.stats ;
  mutable strategy : string option ; (* hint *)
  mutable search_index : int ;
  mutable search_space : Strategy.t array ; (* sorted by priority *)
}

and script =
  | Opened
  | Script of ProofScript.jscript (* to replay *)
  | Tactic of ProofScript.jtactic * (string * node) list (* played *)

module Node =
struct
  type t = node
  let hash t = Wpo.S.hash t.goal
  let equal a b = Wpo.S.equal a.goal b.goal
  let compare a b = Wpo.S.compare a.goal b.goal
  let pretty fmt a = Wpo.S.pretty fmt a.goal
end

type tree = {
  main : Wpo.t ; (* Main goal to be proved. *)
  mutable pool : Lang.F.pool option ; (* Global pool variable *)
  mutable saved : bool ; (* Saved on Disk. *)
  mutable gid : int ; (* WPO goal numbering *)
  mutable head : node option ; (* the current node *)
  mutable root : node option ; (* the root node *)
}

module PROOFS = WpContext.StaticGenerator(Wpo.S)
    (struct
      type key = Wpo.S.t
      type data = tree
      let name = "Wp.ProofEngine.Proofs"
      let compile main =
        ignore (Wpo.resolve main) ;
        {
          main ; gid = 0 ;
          pool = None ;
          head = None ;
          root = None ;
          saved = false ;
        }
    end)

let () = Wpo.add_removed_hook PROOFS.remove
let () = Wpo.add_cleared_hook PROOFS.clear

let get wpo =
  try
    let proof = PROOFS.get wpo in
    match proof.root with
    | None | Some { script = Opened | Script _ } -> raise Not_found
    | Some { script = Tactic _ } -> if proof.saved then `Saved else `Proof
  with Not_found ->
    if ProofSession.exists wpo then `Script else `None

let iter_children f ns = List.iter (fun m -> f (snd m)) ns
let map_children f ns = List.map (fun m -> fst m,f m) ns

let pool tree =
  match tree.pool with
  | Some pool -> pool
  | None ->
    let _,sequent = Wpo.compute tree.main in
    let pool = Lang.new_pool ~vars:(Conditions.vars_seq sequent) () in
    tree.pool <- Some pool ; pool

(* -------------------------------------------------------------------------- *)
(* --- Constructors                                                       --- *)
(* -------------------------------------------------------------------------- *)

let proof ~main =
  assert (not (Wpo.is_tactic main)) ;
  PROOFS.get main

let saved t = t.saved
let set_saved t s = t.saved <- s

(* -------------------------------------------------------------------------- *)
(* --- Removal                                                            --- *)
(* -------------------------------------------------------------------------- *)

let rec revert_tactic t n =
  n.strategy <- None ;
  match n.script with
  | Opened | Script _ -> ()
  | Tactic(_,children) ->
    n.script <- Opened ; iter_children (remove_node t) children

and remove_node t n =
  if Wpo.is_tactic n.goal then
    Wpo.remove n.goal
  else
    Wpo.clear_results n.goal ;
  begin
    match t.head with
    | Some n0 when n0 == n -> t.head <- None
    | _ -> ()
  end ;
  revert_tactic t n

let clear_node t n =
  Wpo.clear_results n.goal ;
  revert_tactic t n ;
  if t.head = None then t.head <- Some n

let clear_tree t =
  begin
    Wpo.clear_results t.main ;
    Option.iter (remove_node t) t.root ;
    t.gid <- 0 ;
    t.head <- None ;
    t.root <- None ;
    t.saved <- false ;
  end

let clear_parent_tactic t n =
  match n.parent with
  | None -> clear_tree t
  | Some p as h -> t.head <- h ; revert_tactic t p

let clear_goal w =
  if PROOFS.mem w then clear_tree (PROOFS.get w)

(* -------------------------------------------------------------------------- *)
(* --- Walking                                                            --- *)
(* -------------------------------------------------------------------------- *)

let rec walk f node =
  if not (Wpo.is_valid node.goal) then
    match node.script with
    | Tactic (_,children) -> iter_children (walk f) children
    | Opened | Script _ -> f node

let iteri f tree =
  match tree.root with
  | None -> ()
  | Some r ->
    let k = ref 0 in
    walk (fun node -> f !k node ; incr k) r

let rec depth node =
  match node.parent with
  | None -> 1
  | Some p -> succ @@ depth p

(* -------------------------------------------------------------------------- *)
(* --- Consolidating                                                      --- *)
(* -------------------------------------------------------------------------- *)

let proved n = Wpo.is_valid n.goal

let pending n =
  let k = ref 0 in
  walk (fun _ -> incr k) n ; !k

let is_prover_result (p,_) = p <> VCS.Tactical

let prover_stats ~smoke goal =
  Stats.results ~smoke @@
  List.filter is_prover_result @@
  Wpo.get_results goal

let rec consolidate ~smoke n =
  let s =
    if Wpo.is_valid n.goal then
      prover_stats ~smoke n.goal
    else
      match n.script with
      | Opened | Script _ -> prover_stats ~smoke n.goal
      | Tactic(_,children) ->
        let qed = Wpo.qed_time n.goal in
        let results = List.map (fun (_,n) -> consolidate ~smoke n) children in
        Stats.tactical ~qed results
  in n.stats <- s ; s

let validate tree =
  match tree.root with
  | None -> ()
  | Some root ->
    let main = tree.main in
    if not (Wpo.is_valid main) then
      let stats = consolidate ~smoke:(Wpo.is_smoke_test main) root in
      Wpo.set_result tree.main Tactical (Stats.script stats)

let consolidated wpo =
  let smoke = Wpo.is_smoke_test wpo in
  try
    if smoke || not (PROOFS.mem wpo) then raise Not_found ;
    match PROOFS.get wpo with
    | { root = Some { stats ; script = Tactic _ } } -> stats
    | _ -> raise Not_found
  with Not_found -> prover_stats ~smoke wpo

(* -------------------------------------------------------------------------- *)
(* --- Accessors                                                          --- *)
(* -------------------------------------------------------------------------- *)

let main t = t.main
let head t = t.head
let head_goal t = match t.head with
  | None -> t.main
  | Some n -> n.goal
let tree n = proof ~main:n.tree
let goal n = n.goal

let stats n = n.stats
let tree_context t = Wpo.get_context t.main
let node_context n = Wpo.get_context n.goal
let parent n = n.parent
let title n = n.goal.Wpo.po_name

let tactical n =
  match n.script with
  | Tactic(tactic,_) -> Some tactic
  | Opened | Script _ -> None

let get_strategies n = n.search_index , n.search_space
let set_strategies n ?(index=0) hs =
  n.search_index <- index ; n.search_space <- hs

let children n =
  match n.script with
  | Tactic(_,children) -> children
  | Opened | Script _ -> []

let subgoals n = List.map snd @@ children n

let rec path n = match n.parent with
  | None -> []
  | Some p -> p::path p

let child_label n = n.child

let tactic_label n =
  match n.script with Tactic({ header }, _)  -> Some header | _ -> None

let tactic n =
  match n.script with
  | Tactic({ tactic }, _)  ->
    begin try Some (Tactical.lookup ~id:tactic) with Not_found -> None end
  | _ -> None

(* -------------------------------------------------------------------------- *)
(* --- State & Status                                                     --- *)
(* -------------------------------------------------------------------------- *)

type status = [
  | `Unproved (* proof obligation not proved *)
  | `Proved   (* proof obligation is proved *)
  | `Pending of int (* proof is pending *)
  | `Passed   (* smoke test is passed (PO is not proved) *)
  | `Invalid  (* smoke test has failed (PO is proved) *)
  | `StillResist of int (* proof is pending *)
]

let status t : status =
  match t.root with
  | None ->
    if Wpo.is_valid t.main
    then if Wpo.is_smoke_test t.main then `Invalid else `Proved
    else if Wpo.is_smoke_test t.main then `Passed else `Unproved
  | Some root ->
    match root.script with
    | Opened | Script _ ->
      if Wpo.is_smoke_test t.main then `Passed else `Unproved
    | Tactic _ ->
      let n = pending root in
      if Wpo.is_smoke_test t.main then `StillResist n else `Pending n

(* -------------------------------------------------------------------------- *)
(* --- Navigation                                                         --- *)
(* -------------------------------------------------------------------------- *)

type current = [ `Main | `Internal of node | `Leaf of int * node ]

let current t : current =
  match t.head with
  | Some h ->
    let p = ref (`Internal h) in
    iteri (fun i n -> if n == h then p := `Leaf(i,n)) t ; !p
  | None -> `Main

type position = [ `Main | `Node of node | `Leaf of int ]
let goto t = function
  | `Main ->
    t.head <- t.root
  | `Node n ->
    if n.tree == t.main then t.head <- Some n
  | `Leaf k ->
    t.head <- t.root ;
    iteri (fun i n -> if i = k then t.head <- Some n) t

let fetch t node =
  try
    t.head <- t.root ;
    walk (fun n -> t.head <- Some n ; raise Exit) node ; false
  with Exit -> true

let rec forward t =
  match t.head with
  | None -> t.head <- t.root
  | Some hd ->
    if not (fetch t hd) then
      begin
        t.head <- hd.parent ;
        forward t ;
      end

let cancel_parent_tactic t =
  match t.head with
  | None -> ()
  | Some n -> clear_parent_tactic t n

let cancel_current_node t =
  match t.head with
  | None -> ()
  | Some node -> clear_node t node

(* -------------------------------------------------------------------------- *)
(* --- Sub-Goal                                                           --- *)
(* -------------------------------------------------------------------------- *)

let mk_formula ~main axioms sequent =
  Wpo.VC_Annot.{ main with goal = Wpo.GOAL.make sequent ; axioms }

let mk_goal t ~title ~part ~axioms sequent =
  let id = t.gid in t.gid <- succ id ;
  let gid = Printf.sprintf "%s-%d" t.main.Wpo.po_gid id in
  let sid = Printf.sprintf "%s-%d" t.main.Wpo.po_sid id in
  Wpo.({
      po_gid = gid ;
      po_sid = sid ;
      po_name = Printf.sprintf "%s (%s)" title part ;
      po_idx = t.main.po_idx ;
      po_pid = WpPropId.tactical ~gid ;
      po_model = t.main.po_model ;
      po_formula = mk_formula ~main:t.main.po_formula axioms sequent ;
    })

let mk_tree_node ~tree ~anchor (child,goal) = {
  tree = tree.main ; goal ;
  parent = Some anchor ;
  child = Some child ;
  script = Opened ;
  stats = Stats.empty ;
  search_index = 0 ;
  search_space = [| |] ;
  strategy = None ;
}

let mk_root_node goal = {
  tree = goal ; goal ;
  child = None ;
  parent = None ;
  script = Opened ;
  stats = Stats.empty ;
  strategy = None ;
  search_index = 0 ;
  search_space = [| |] ;
}

let mk_root ~tree =
  let goal = tree.main in
  let node = mk_root_node goal in
  let root = Some node in
  tree.root <- root ;
  tree.head <- root ;
  node

let root tree =
  match tree.root with
  | Some node -> node
  | None -> mk_root ~tree

(* -------------------------------------------------------------------------- *)
(* --- Forking                                                            --- *)
(* -------------------------------------------------------------------------- *)

module Fork =
struct
  type t = {
    tree : tree ;
    anchor : node ;
    tactic : ProofScript.jtactic ;
    goals : (string * Wpo.t) list ;
  }

  let create tree ~anchor tactic process =
    let axioms , sequent = Wpo.compute anchor.goal in
    let vars = Conditions.vars_seq sequent in
    let dseqs = Lang.local ~vars process sequent in
    let title = tactic.ProofScript.header in
    let goals = List.map
        (fun (part,s) -> part , mk_goal tree ~title ~part ~axioms s) dseqs
    in { tree ; tactic ; anchor ; goals }

  let iter f w = iter_children f w.goals

  let header frk = frk.tactic.ProofScript.header
end

let pretty fmt frk = Format.pp_print_string fmt (Fork.header frk)

type fork = Fork.t

let fork = Fork.create
let iter = Fork.iter

let anchor tree ?node () =
  match node with
  | Some n -> n
  | None ->
    match tree.head with
    | Some n -> n
    | None ->
      match tree.root with
      | Some n -> n
      | None -> mk_root ~tree

let commit fork =
  List.iter (fun (_,wp) -> ignore (Wpo.resolve wp)) fork.Fork.goals ;
  let tree = fork.Fork.tree in
  let anchor = fork.Fork.anchor in
  let children = map_children (mk_tree_node ~tree ~anchor) fork.Fork.goals in
  tree.saved <- false ;
  anchor.script <- Tactic( fork.Fork.tactic , children ) ;
  anchor , children

(* -------------------------------------------------------------------------- *)
(* --- Scripting                                                          --- *)
(* -------------------------------------------------------------------------- *)

let results wpo =
  List.map (fun (p,r) -> ProofScript.a_prover p r) (Wpo.get_results wpo)

let rec script_node (node : node) =
  let provers = results node.goal in
  let scripts =
    match node.script with
    | Script s -> List.filter ProofScript.is_tactic s
    | Tactic( tactic , children ) ->
      [ ProofScript.a_tactic tactic (List.map subscript_node children) ]
    | Opened -> []
  in
  provers @ scripts

and subscript_node (key,node) = key , script_node node

let script tree =
  match tree.root with
  | None -> results tree.main
  | Some node -> script_node node

let bind node script =
  match node.script with
  | Tactic _ ->
    (*TODO: saveback the thrown script *)
    ()
  | Opened | Script _ ->
    (*TODO: saveback the previous script *)
    node.script <- Script script

let bound node =
  match node.script with
  | Tactic _ | Opened -> []
  | Script s -> s

let get_hint node = node.strategy
let set_hint node strategy = node.strategy <- Some strategy

(* -------------------------------------------------------------------------- *)
