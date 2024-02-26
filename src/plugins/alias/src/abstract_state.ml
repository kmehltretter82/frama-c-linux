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

open Cil_types
open Cil_datatype

open Simplified

module EdgeLabel = struct
  type t =
    | Pointer (* represents dereferentiation of pointers as well as arrays *)
    | Field of fieldinfo
  let compare l r = match l, r with
    | Pointer, Pointer -> 0
    | Pointer, Field _ -> -1
    | Field lv, Field rv -> Fieldinfo.compare lv rv
    | Field _, Pointer -> 1
  let default = Pointer
  let is_pointer = function Pointer -> true | _ -> false
  let is_field = function Field _ -> true | _ -> false
  let pretty fmt = function
    | Pointer -> ()
    | Field f -> Format.fprintf fmt "-%s" f.fname
end

module G = struct
  include Graph.Persistent.Digraph.ConcreteBidirectionalLabeled (Datatype.Int) (EdgeLabel)

  let psucc g v =
    let only_pointer_succ e =
      if EdgeLabel.is_pointer (E.label e) then Some (E.dst e) else None
    in
    List.filter_map only_pointer_succ (succ_e g v)

  let ppred g v =
    let p e = match E.label e with Pointer -> Some (E.src e) | _ -> None in
    List.filter_map p (pred_e g v)

  let fsucc_opt g v f =
    assert (List.for_all (fun e -> EdgeLabel.is_field @@ E.label e) @@ succ_e g v);
    let is_field_f e = match E.label e with
      | Field f' -> Fieldinfo.equal f f'
      | _ -> false
    in
    let edges = succ_e g v in
    assert (List.length (List.filter is_field_f edges) <= 1);
    Option.map E.dst @@ List.find_opt is_field_f edges

  let psucc_opt g v = match psucc g v with
    | [] -> None
    | [v] -> Some v
    | _ -> Options.fatal "Invariant violated: more than one successor"
end

module V = G.V
module E = struct
  include G.E
  include EdgeLabel
  module Map = Stdlib.Map.Make (struct
      type t = EdgeLabel.t
      let compare = EdgeLabel.compare
    end)
end

module VMap = Datatype.Int.Map
module VSet = Datatype.Int.Set
module LSet = Cil_datatype.LvalStructEq.Set
module VarSet = Cil_datatype.Varinfo.Set

module VarMap = struct
  include Cil_datatype.Varinfo.Map

  let intersect = merge @@ fun _ l r -> match l,r with
    | Some l, Some r -> Some (l,r)
    | _ -> None

  let pretty fmt =
    let is_first = ref true in
    iter (fun var v ->
        if !is_first then is_first := false else Format.fprintf fmt "@;<3>";
        Format.fprintf fmt "@ @[%a:%d@]" Varinfo.pretty var v)
end

type t =
  {graph : G.t;
   vmap : VarSet.t VMap.t; (* associate with each node a set of variables *)
   varmap : V.t VarMap.t (* reverse of varmap *)}

let node_counter = ref 0
let fresh_node_id () =
  let id = !node_counter in
  node_counter := !node_counter + 1;
  id

(* find functions *)
let find_varset (v:V.t) (x:t) : VarSet.t =
  try VMap.find v x.vmap with Not_found -> VarSet.empty

(* raises Not_found *)
let rec find_lval_vertex ((lhost, offset) : lval) (x : t) : V.t =
  let find_psucc v = match G.psucc_opt x.graph v with Some v -> v | _ -> raise Not_found in
  let find_fsucc v fname = match G.fsucc_opt x.graph v fname with Some v -> v | _ -> raise Not_found in
  let find_lhost = function
    | Var var -> VarMap.find var x.varmap
    | Mem e ->
      match LvalOrRef.from_exp e with
      | None -> Options.fatal "unexpected result: Lval.from (%a) = None" Exp.pretty e
      | Some (LvalOrRef.Ref lv1) -> find_lval_vertex lv1 x
      | Some (LvalOrRef.Lval lv1) ->
        let v1 = find_lval_vertex lv1 x in
        find_psucc v1
  in
  let rec find_offset v = function
    | NoOffset -> v
    | Index (_, o) ->
      let v' = find_psucc v in
      find_offset v' o
    | Field (f, o) ->
      let v' = find_fsucc v f in
      find_offset v' o
  in
  let hv = find_lhost lhost in
  find_offset hv offset


module Readout = struct

  let get_lval_set v x =
    let mk_lval var = Var var, NoOffset in
    LSet.of_seq @@ Seq.map mk_lval @@ VarSet.to_seq @@ find_varset v x

  (* Reconstruct all lvals that are represented by the given node.
     Nodes only carry varinfos. In order to obtain lvals we recursively walk
     backwards in the graph inductively constructing lvals from scratch.
     - The lvals of the current node are the stored varinfos themselves.
     - After gathering the lvals for the predecessor, the lvals are
       modified according to the edge type used:
       * Pointer: add a star (x → *x)
       * Field f: add an offset (x -> x.f) *)
  let rec reconstruct_lvals (x : t) (v : V.t) : LSet.t =
    assert (G.mem_vertex x.graph v);
    let modified_predecessors = List.map
        (fun e ->
           let pred_lvals = reconstruct_lvals x (E.src e) in
           let modify_lval lv = match E.label e with
             | Field f -> let lhost, o = lv in lhost, Field (f, o)
             | Pointer ->
               let ty = Cil.typeOfLval lv in
               if Cil.isArrayType ty then
                 let lhost, o = lv in lhost, Index (Simplified.nul_exp, o)
               else
                 let () = if not @@ Cil.isPointerType ty then
                     Options.debug "unexpected type: %a" Printer.pp_typ ty
                 in
                 Mem (Cil.dummy_exp @@ Lval lv), NoOffset
           in
           LSet.map modify_lval pred_lvals
        )
        (G.pred_e x.graph v)
    in
    let lvals_of_v = get_lval_set v x in
    List.fold_left LSet.union lvals_of_v modified_predecessors

  let lvals_pointing_to_vertex (v:V.t) (x:t) : LSet.t =
    assert (G.mem_vertex x.graph v);
    let list_pred = List.map (reconstruct_lvals x) @@ G.ppred x.graph v in
    List.fold_left LSet.union LSet.empty list_pred

  let find_aliases (lv:lval) (x:t) =
    let lv = Lval.simplify lv in
    try let v = find_lval_vertex lv x in get_lval_set v x
    with Not_found -> LSet.empty

  let find_all_aliases (lv:lval) (x:t) : LSet.t =
    let v_opt = try Some (find_lval_vertex lv x) with Not_found -> None in
    match Option.bind v_opt @@ G.psucc_opt x.graph with
    | None -> LSet.empty
    | Some succ -> lvals_pointing_to_vertex succ x

  let points_to_set (lv:lval) (x:t) : LSet.t =
    let succ = try G.psucc_opt x.graph @@ find_lval_vertex lv x with Not_found -> None in
    match succ with
    | None -> LSet.empty
    | Some succ_v -> get_lval_set succ_v x

end


module Pretty = struct

  let pp_debug fmt (x:t) =
    Format.fprintf fmt "@[<v>";
    Format.fprintf fmt "@[Edges:";
    G.iter_edges_e
      (fun e ->
         Format.fprintf fmt "@;<3 2>@[%d@ @[%a→@]@ %d@]"
           (E.src e) E.pretty (E.label e) (E.dst e))
      x.graph;
    Format.fprintf fmt "@]@;<6>";
    Format.fprintf fmt "@[VarMap:@;<3 2>";
    VarMap.pretty fmt x.varmap;
    Format.fprintf fmt "@]@;<6>";
    Format.fprintf fmt "@[VMap:@;<2>";
    VMap.iter (fun v ls -> Format.fprintf fmt "@;<2 2>@[%d:%a@]" v VarSet.pretty ls) x.vmap;
    Format.fprintf fmt "@]";
    Format.fprintf fmt "@]"

  let pp_graph fmt (x:t) =
    let is_first = ref true in
    let pp_node v fmt lset = Format.fprintf fmt "%d:%a" v VarSet.pretty lset in
    let pp_edge e =
      let v1 = E.src e and v2 = E.dst e in
      if !is_first then is_first := false else Format.fprintf fmt "@;<3>";
      Format.fprintf fmt "@[%a@] %a→ @[%a@]"
        (pp_node v1) (VMap.find v1 x.vmap)
        E.pretty (E.label e)
        (pp_node v2) (VMap.find v2 x.vmap)
    in
    let pp_unconnected_vertex v =
      if G.in_degree x.graph v = 0 && G.out_degree x.graph v = 0 then begin
        if !is_first then is_first := false else Format.fprintf fmt "@;<3>";
        pp_node v fmt (VMap.find v x.vmap)
      end
    in
    if G.nb_vertex x.graph = 0
    then Format.fprintf fmt "<empty>"
    else (G.iter_edges_e pp_edge x.graph;
          G.iter_vertex pp_unconnected_vertex x.graph)

  let pp_aliases fmt (x:t) =
    let is_first = ref true in
    let pp_alias_set _ set_lv =
      if !is_first then is_first := false else Format.fprintf fmt "@;<2>";
      LSet.pretty fmt set_lv
    in
    let alias_set_of_vertex i _ =
      let aliases = Readout.lvals_pointing_to_vertex i x in
      if LSet.cardinal aliases >= 2 then Some aliases else None
    in
    let alias_sets = VMap.filter_map alias_set_of_vertex x.vmap in
    if VMap.is_empty alias_sets
    then Format.fprintf fmt "<none>"
    else VMap.iter pp_alias_set alias_sets

end

(* invariants of type t must be true before and after each functon call *)
let assert_invariants (x:t) : unit =
  (* check that all vertex of the graph have entries in vmap,
     and are integer between 0 and node_counter, and have at most 1 successor *)
  assert (!node_counter >= 0);
  let assert_vertex (v:V.t) =
    Options.debug ~level:11 "checking coherence of vertex %d" v;
    assert (v >= 0);
    assert (v < !node_counter);
    assert (VMap.mem v x.vmap);
    let succ_e = G.succ_e x.graph v in
    let is_pointer_vertex =
      List.exists (fun e -> E.is_pointer @@ E.label e) succ_e
    and is_struct_vertex =
      List.exists (fun e -> E.is_field @@ E.label e) succ_e
    in
    assert (not (is_pointer_vertex && is_struct_vertex));
    assert (not is_pointer_vertex || List.length (G.succ x.graph v) <= 1);
  in
  G.iter_vertex assert_vertex x.graph;
  let assert_edge v1 v2 =
    Options.debug ~level:11 "checking coherence of edge %d → %d" v1 v2;
    assert (v1 <> v2);
    assert (G.mem_vertex x.graph v1);
    assert (G.mem_vertex x.graph v2)
  in
  G.iter_edges assert_edge x.graph;
  let assert_varmap (var : varinfo) (v:V.t) =
    assert (G.mem_vertex x.graph v);
    assert (VarSet.mem var (VMap.find v x.vmap))
  in
  VarMap.iter assert_varmap x.varmap;
  let assert_vmap (v:V.t) (ls:VarSet.t) =
    assert (G.mem_vertex x.graph v);
    (* TODO: we removed the invariant because of OSCS*)
    (* if not (VarSet.is_empty ls)
     * then
     *   begin
     *     let lv = VarSet.choose ls in
     *     let is_ptr_lv = Lval.is_pointer lv in
     *     assert (VarSet.for_all (fun x -> Lval.is_pointer x = is_ptr_lv) ls)
     *   end; *)
    assert (VarSet.fold (fun lv acc -> acc && V.equal (VarMap.find lv x.varmap) v) ls true)
  in
  VMap.iter assert_vmap x.vmap

(* Ensure that assert_invariants is not executed if the -noassert flag is supplied. *)
let assert_invariants x =
  try assert (assert_invariants x; true)
  with Assert_failure _ as exn ->
    let bt = Printexc.get_raw_backtrace () in
    Options.debug "incoherent graph:@ @[%a@]" Pretty.pp_debug x;
    Options.debug "incoherent graph:@ @[%a@]" Pretty.pp_graph x;
    Printexc.raise_with_backtrace exn bt

let asserting_invariants x = assert_invariants x; x

let pretty ?(debug = false) fmt (x:t) =
  assert_invariants x;
  if debug then Pretty.pp_graph fmt x
  else Pretty.pp_aliases fmt x

(* NOTE on "constant vertex": a constant vertex represents an unamed
   scalar value (type bottom in steensgaard's paper), or the address
   of a variable. It means that in [vmap], its associated VarSet is
   empty.  By definition, constant vertex cannot be associated to a
   lval in [varmap] *)
let create_empty_vertex (x:t) : V.t * t =
  let new_v = fresh_node_id () in
  new_v, {graph = G.add_vertex x.graph new_v;
          varmap = x.varmap;
          vmap = VMap.add new_v VarSet.empty x.vmap}

let create_var_vertex var x =
  assert (not @@ VarMap.mem var x.varmap);
  let v = fresh_node_id () in
  let x = {graph = G.add_vertex x.graph v;
           varmap = VarMap.add var v x.varmap;
           vmap = VMap.add v (VarSet.singleton var) x.vmap} in
  match var.vtype with
  | TPtr _ ->
    (* then add a another empty vertex *)
    let v', x = create_empty_vertex x in
    v, {x with graph = G.add_edge x.graph v v'}
  | _ -> v, x

let find_or_create_var_vertex (var : varinfo) (x : t) =
  try VarMap.find var x.varmap, x
  with Not_found -> create_var_vertex var x

let rec find_or_create_lval_vertex ((lhost, offset) : lval) (x : t) : V.t * t =
  let find_or_create_psucc v x =
    match G.psucc_opt x.graph v with
    | None ->
      let v', x = create_empty_vertex x in
      (* finally add a points-to edge between v and v' *)
      let new_graph = G.add_edge x.graph v v' in
      v', {x with graph = new_graph}
    | Some v' -> v', x
  in
  let find_or_create_fsucc v x f =
    match G.fsucc_opt x.graph v f with
    | None ->
      let v', x = create_empty_vertex x in
      (* finally add a points-to edge between v and v' *)
      let new_graph = G.add_edge_e x.graph @@ E.create v (Field f) v' in
      v', {x with graph = new_graph}
    | Some v' -> v', x
  in
  let find_or_create_lhost (x : t) = function
    | Var var -> find_or_create_var_vertex var x
    | Mem e ->
      match LvalOrRef.from_exp e with
      | None -> Options.fatal "unexpected result: Lval.from (%a) = None" Exp.pretty e
      | Some (LvalOrRef.Ref lv1) -> find_or_create_lval_vertex lv1 x
      | Some (LvalOrRef.Lval lv1) ->
        let v1, x = find_or_create_lval_vertex lv1 x in
        find_or_create_psucc v1 x
  in
  let rec find_or_create_offset v x = function
    | NoOffset -> v, x
    | Index (_, o) ->
      let v', x = find_or_create_psucc v x in
      find_or_create_offset v' x o
    | Field (f, o) ->
      let v', x = find_or_create_fsucc v x f in
      find_or_create_offset v' x o
  in
  let hv, x = find_or_create_lhost x lhost in
  let v, x = find_or_create_offset hv x offset in
  Options.debug ~level:7 "graph after find_or_create_lval_vertex @[%a@] (%d):@ %a"
    Printer.pp_lval (lhost, offset) v Pretty.pp_graph x;
  v, x

and find_or_create_ref_vertex (lv : lval) (x:t) : V.t * t =
  let v1, x = find_or_create_lval_vertex lv x in
  let va, x = create_empty_vertex x in
  let x = {x with graph = G.add_edge x.graph va v1} in
  Options.debug ~level:7 "graph after find_or_create_ref_vertex @[%a@] (%d):@ %a"
    LvalOrRef.pretty (LvalOrRef.Ref lv) va Pretty.pp_graph x;
  va, x

and find_or_create_lval_or_ref_vertex (lv : LvalOrRef.t) (x:t) : V.t * t =
  match lv with
  | LvalOrRef.Lval lv -> find_or_create_lval_vertex lv x
  | LvalOrRef.Ref lv -> find_or_create_ref_vertex lv x

(* TODO is there a better way to do it ? *)
let find_vertex lv x =
  let lv = Lval.simplify lv in
  let v,x1 = find_or_create_lval_vertex lv x in
  if x == x1
  then v (* if x has not been modified, then the vertex was found, not created *)
  else raise Not_found

(* merge of two vertices; the first vertex carries both sets, the second is
   removed from the graph and from varmap and vmap *)
let merge x v1 v2 =
  if V.equal v1 v2 || not (G.mem_vertex x.graph v1) || not (G.mem_vertex x.graph v2)
  then x
  else
    (* update varmap : every lval in v2 must now be associated with v1 *)
    let new_varmap = VarSet.fold (fun lv2 -> VarMap.add lv2 v1) (find_varset v2 x) x.varmap in
    let new_vmap =
      let new_set = VarSet.union (find_varset v1 x) (find_varset v2 x) in
      VMap.add v1 new_set @@ VMap.remove v2 x.vmap
    in
    let new_graph = (* update the graph *)
      let f_fold_succ e (g:G.t) : G.t =
        G.add_edge_e g @@ E.create v1 (E.label e) (E.dst e)
      and f_fold_pred e (g:G.t) : G.t =
        G.add_edge_e g @@ E.create (E.src e) (E.label e) v1
      in
      let g = x.graph in
      (* add all new edges *)
      let g = G.fold_succ_e f_fold_succ g v2 g in
      let g = G.fold_pred_e f_fold_pred g v2 g in
      G.remove_vertex g v2 (* remove v2 *)
    in
    {graph = new_graph; varmap = new_varmap; vmap = new_vmap}

(* functions join and unify-pointer of steensgaard's paper *)
(* join_without_check may break the invariants *)
let rec join_without_check (x:t) (v1:V.t) (v2:V.t) : t =
  if V.equal v1 v2 || not (G.mem_vertex x.graph v1 && G.mem_vertex x.graph v2)
  then x
  else
    let mk_edge_map succs =
      let mk_succ e = E.label e, E.dst e in
      E.Map.of_seq @@ Seq.map mk_succ @@ List.to_seq succs
    in
    let succs1 = mk_edge_map @@ G.succ_e x.graph v1 in
    let succs2 = mk_edge_map @@ G.succ_e x.graph v2 in
    let succ_pairs =
      let mk_pair _ succ1 succ2 = match succ1, succ2 with
        | Some s1, Some s2 -> Some (s1, s2)
        | _ -> None
      in
      E.Map.merge mk_pair succs1 succs2
    in
    let x = merge x v1 v2 in
    assert (not (G.mem_vertex x.graph v2));
    let merge_succs _ (succ1, succ2) x =
      assert (succ1 <> v2);
      assert (succ2 <> v1);
      join_without_check x succ1 succ2
    in
    E.Map.fold merge_succs succ_pairs x

let join (x:t) (v1:V.t) (v2:V.t) : t =
  Options.debug ~level:6 "graph before join(%d,%d):@;<2>@[%a@]" v1 v2 Pretty.pp_graph x;
  assert_invariants x;
  let res = join_without_check x v1 v2 in
  Options.debug ~level:6 "graph after join(%d,%d):@;<2>@[%a@]" v1 v2 Pretty.pp_graph res;
  begin try assert_invariants res
    with Assert_failure _ ->
      Options.debug "join(%d,%d) failed" v1 v2;
      Options.debug "graph before join(%d,%d):@;<2>@[%a@]" v1 v2 Pretty.pp_debug x;
      Options.debug "graph after join(%d,%d):@;<2>@[ %a@]" v1 v2 Pretty.pp_debug res;
      assert_invariants res
  end;
  res

let merge_set (x:t) (vs:VSet.t) : V.t * t =
  let v0 = VSet.choose vs in
  if VSet.cardinal vs < 2 then v0, x else begin
    Options.debug ~level:6 "graph before merge_set %a:@;<2>@[%a@]"
      VSet.pretty vs Pretty.pp_debug x;
    assert (G.mem_vertex x.graph v0);
    let result = VSet.fold (fun v acc -> merge acc v0 v) vs x in
    Options.debug ~level:6 "graph after merge_set %a:@;<2>@[%a@]"
      VSet.pretty vs Pretty.pp_debug result;
    v0, result
  end

(* may operate on an unsound state, where nodes may have multiple successors
   of the same edge type *)
let rec join_succs (x:t) v =
  Options.debug ~level:8 "joining successors of %d" v;
  if not @@ G.mem_vertex x.graph v then x else
    let edge_map =
      List.fold_left (fun m e ->
          let add_dst = function
            | None -> Some (VSet.singleton @@ E.dst e)
            | Some vs -> Some (VSet.add (E.dst e) vs)
          in
          E.Map.update (E.label e) add_dst m
        )
        E.Map.empty
        (G.succ_e x.graph v)
    in
    let merge_vset _e vs x =
      if VSet.cardinal vs < 2
      then x
      else let v0, x = merge_set x vs in join_succs x v0
    in
    E.Map.fold merge_vset edge_map x

(* in Steensgard's paper, this is written settype(v1,ref(v2,bot)) *)
let set_type (x:t) (v1:V.t) (v2:V.t) : t =
  assert_invariants x;
  (* if v1 points to another node, suppress current outgoing edge (and the node if it is a constant node) *)
  let g, new_vmap =
    match G.psucc_opt x.graph v1 with
    | None -> x.graph, x.vmap
    | Some v2 ->
      (* if v2 is a constant node supress it directly *)
      if VarSet.is_empty (VMap.find v2 x.vmap)
      then G.remove_vertex x.graph v2, VMap.remove v2 x.vmap
      else G.remove_edge x.graph v1 v2, x.vmap
  in
  let new_g = G.add_edge g v1 v2 in
  asserting_invariants {x with graph = new_g; vmap = new_vmap}

let assignment (a:t) (lv:lval) (e:exp) : t =
  assert_invariants a;
  match Cil.isPointerType (Cil.typeOf e), LvalOrRef.from_exp e with
  | false, _ | _, None -> a
  | true, Some y ->
    let v1, a = find_or_create_lval_vertex (Lval.simplify lv) a in
    let v2, a = find_or_create_lval_or_ref_vertex y a in
    if List.mem v2 (G.psucc a.graph v1) || List.mem v1 (G.psucc a.graph v2)
    then
      let () =
        Options.warning ~source:(fst e.eloc)
          "ignoring assignment of the form: %a = %a"
          Printer.pp_lval lv Printer.pp_exp e;
      in a
    else asserting_invariants @@ join a v1 v2

(* assignment x = allocate(y) *)
let assignment_x_allocate_y (a:t) (lv:lval) : t =
  assert_invariants a;
  let x = Lval.simplify lv in
  let v1, a = find_or_create_lval_vertex x a in
  match G.psucc_opt a.graph v1 with
  | None ->
    let v2, a = create_empty_vertex a in
    set_type a v1 v2
  | Some _ -> a

let is_included (a1:t) (a2:t) =
  (* tests if a1 is included in a2, at least as the nodes with lval *)
  assert_invariants a1;
  assert_invariants a2;
  Options.debug ~level:8 "testing equal %a AND à.%a"
    Pretty.pp_graph a1 (pretty ~debug:true) a2;
  let exception Not_included in
  try
    let iter_varmap (var : varinfo) (v1 : V.t): unit =
      let v2 : V.t = try VarMap.find var a2.varmap with Not_found -> raise Not_included in
      (* TODO: render correct for structs *)
      let succs1 =
        E.Map.of_seq @@ Seq.map (fun e -> E.label e, E.dst e) @@ List.to_seq @@ G.succ_e a1.graph v1
      and succs2 =
        E.Map.of_seq @@ Seq.map (fun e -> E.label e, E.dst e) @@ List.to_seq @@ G.succ_e a2.graph v2
      in
      let check_succs _ succ1 succ2 = match succ1, succ2 with
        | None, _ -> None
        | Some _, None -> raise Not_included
        | Some v1p, Some v2p ->
          if VarSet.subset (VMap.find v1p a1.vmap) (VMap.find v2p a2.vmap)
          then None
          else raise Not_included
      in
      ignore @@ E.Map.merge check_succs succs1 succs2
    in
    VarMap.iter iter_varmap a1.varmap; true
  with
    Not_included -> false

let empty : t = {graph = G.empty; varmap = VarMap.empty; vmap = VMap.empty}

let is_empty s = compare s empty = 0

(* add an int to all vertex values *)
let shift (a : t) : t =
  assert_invariants a;
  if is_empty a then a else begin
    Options.debug ~level:8 "before shift: node_counter=%d@.%a"
      !node_counter Pretty.pp_debug a;
    let max_idx = G.fold_vertex max a.graph 0 in
    let min_idx = G.fold_vertex min a.graph max_idx in
    let offset = !node_counter - min_idx in
    let shift x = x + offset in
    let shift_vmap shift_elem vmap =
      VMap.of_seq @@ Stdlib.Seq.map shift_elem @@ VMap.to_seq vmap
    in
    let {graph; varmap; vmap} = a in
    node_counter := max_idx + offset + 1;
    let result =
      {graph = G.map_vertex shift graph;
       varmap = VarMap.map shift varmap;
       vmap = shift_vmap (fun (key, l) -> shift key, l) vmap}
    in
    Options.debug ~level:8 "after shift: node_counter=%d@.%a"
      !node_counter Pretty.pp_debug result;
    asserting_invariants result
  end

let union_find vmap intersections =
  let module Store : UnionFind.STORE = UnionFind.StoreMap.Make (VMap) in
  let module UF = UnionFind.Make (Store) in
  let uf = UF.new_store () in
  let refs = VMap.mapi (fun i _ -> UF.make uf i) vmap in
  let put_into_uf (v1,v2) =
    let r1 = VMap.find v1 refs in
    let r2 = VMap.find v2 refs in
    ignore @@ UF.union uf r1 r2
  in
  let _vs = Seq.iter put_into_uf intersections in
  let sets_to_be_joined =
    let add_to_map i r sets =
      let repr = UF.find uf r in
      let add_to_set = function
        | None -> Some (VSet.singleton i)
        | Some set -> Some (VSet.add i set)
      in
      VMap.update (UF.get uf repr) add_to_set sets
    in
    VMap.fold add_to_map refs VMap.empty in
  sets_to_be_joined

let union (a1:t) (a2:t) :t =
  assert_invariants a1;
  assert_invariants a2;

  Options.debug ~level:4 "Union: First graph:%a" Pretty.pp_graph a1;
  Options.debug ~level:5 "Union: First graph:%a" Pretty.pp_debug a1;
  Options.debug ~level:4 "Union: Second graph:%a" Pretty.pp_graph a2;
  Options.debug ~level:5 "Union: Second graph:%a" Pretty.pp_debug a2;
  let new_graph =
    G.fold_vertex
      (fun v2 g -> G.add_vertex g v2)
      a2.graph
      a1.graph
  in
  let new_graph =
    G.fold_edges_e (fun e g -> G.add_edge_e g e) a2.graph new_graph
  in
  let new_vmap =
    VMap.union (fun _ lset1 lset2 -> Option.some @@ VarSet.union lset1 lset2)
      a2.vmap
      a1.vmap
  in
  let sets_to_be_joined =
    let intersections = VarMap.to_seq @@ VarMap.intersect a1.varmap a2.varmap in
    union_find new_vmap @@ Seq.map snd intersections
  in
  let new_varmap = VarMap.union (fun _ l _r -> Some l) a1.varmap a2.varmap in
  Options.debug ~level:7 "Union: sets to be joined:@[";
  VMap.iter (fun _ set -> Options.debug ~level:7 "%a" VSet.pretty set) sets_to_be_joined;
  Options.debug ~level:7 "@]";
  let new_a = {graph = new_graph; varmap = new_varmap; vmap = new_vmap} in
  let merged_nodes, new_a =
    VMap.fold
      (fun _ set (merged_nodes, x) -> let v0, x = merge_set x set in (v0 :: merged_nodes), x)
      sets_to_be_joined
      ([], new_a)
  in
  let new_a = List.fold_left join_succs new_a merged_nodes in
  Options.debug ~level:4 "Union: Result graph:%a" Pretty.pp_graph new_a;
  Options.debug ~level:5 "Union: Result graph:%a" Pretty.pp_debug new_a;
  begin try assert_invariants new_a
    with Assert_failure _ ->
      Options.debug "union failed";
      Options.debug "Union: First graph:%a" Pretty.pp_graph a1;
      Options.debug "Union: First graph:%a" Pretty.pp_debug a1;
      Options.debug "Union: Second graph:%a" Pretty.pp_graph a2;
      Options.debug "Union: Second graph:%a" Pretty.pp_debug a2;
      Options.debug "Union: Result graph:%a" Pretty.pp_graph new_a;
      Options.debug "Union: Result graph:%a" Pretty.pp_debug new_a;
      assert_invariants new_a
  end;
  new_a


module Summary = struct
  (* a type for summaries of functions *)
  type s = {state   : t option;
            formals : lval list;
            locals  : lval list;
            return  : exp option}

  let make (s : t) (kf : kernel_function) =
    let exp_return : exp option =
      if Kernel_function.has_definition kf then
        let return_stmt = Kernel_function.find_return kf in
        match return_stmt.skind with
        | Return (e, _) -> e
        | _ -> Options.fatal "this should not happen"
      else None
    in
    let s =
      match exp_return with
      | None -> s
      | Some e ->
        begin match s, LvalOrRef.from_exp e with
          | _, None -> s
          | s, Some lv ->
            let _, new_s = find_or_create_lval_or_ref_vertex lv s in
            new_s
        end
    in
    {state = Some s;
     formals = List.map (fun v -> (Var v,NoOffset)) (Kernel_function.get_formals kf);
     locals = List.map (fun v -> (Var v,NoOffset)) (Kernel_function.get_locals kf);
     return = exp_return}

  let pretty ?(debug=false) fmt s =
    let pp_list_lval ~state fmt (l: lval list) =
      let is_first = ref true in
      let pp_elem x =
        if !is_first then is_first := false else Format.fprintf fmt "@  ";
        Format.fprintf fmt "@[%a" Cil_datatype.Lval.pretty x;
        let pointees = Readout.points_to_set x state in
        if not @@ LSet.is_empty pointees then
          Format.fprintf fmt "→%a" LSet.pretty pointees;
        Format.fprintf fmt "@]";
      in
      List.iter pp_elem l
    in
    let pp_option pp fmt = function
      | Some x -> pp fmt x
      | None -> Format.fprintf fmt "<none>"
    in
    match s.state with
    | None -> if debug then Format.fprintf fmt "not found"
    | Some s when is_empty s -> if debug then Format.fprintf fmt "empty"
    | Some state ->
      Format.fprintf fmt "@[formals: @[%a@]@;<4>locals: @[%a@]@;<4>returns: @[%a@]@;<4>state: @[%a@] "
        (pp_list_lval ~state) s.formals
        (pp_list_lval ~state) s.locals
        (pp_option Exp.pretty) s.return
        (pp_option @@ pretty ~debug) s.state

end

(* the algorithm:
   - unify the two graphs dropping all the variables from the summary
   - pair arguments with formals assigning the formal's successor as the argument's successor
*)
let call (state : t) (res : lval option) (args : exp list) (summary : Summary.s) : t =
  assert_invariants state;
  let formals = summary.Summary.formals in
  assert (List.length args = List.length formals);
  let sum_state = shift @@ Option.get summary.state in

  (* pair up formals and their corresponding arguments,
     as well as the bound result with the returned value *)
  let arg_formal_pairs =
    let res_ret = match res, summary.return with
      | None, None -> []
      | Some res, Some ret ->
        let simplify_ret x = match LvalOrRef.from_exp x with
          | Some (LvalOrRef.Lval lval) -> lval
          | _ -> Options.fatal "unexpected form of return statement"
        in
        [LvalOrRef.Lval (Lval.simplify res), simplify_ret ret]
      | None, Some _ -> []
      | Some _, None -> (* Shouldn't happen: Frama-C adds missing returns *)
        Options.fatal "unexpected case: result without return"
    in
    let simplify_both (arg, formal) =
      try
        match LvalOrRef.from_exp arg with
        | None -> None
        | Some lv -> Some (lv, Lval.simplify formal)
      with Explicit_pointer_address loc ->
        Options.warning ~source:(fst loc) ~wkey:Options.Warn.unsupported_address
          "unsupported feature: explicit pointer address: %a; analysis may be unsound"
          Printer.pp_exp arg;
        None
    in
    res_ret @ List.filter_map simplify_both @@ List.combine args formals
  in

  (* for each pair (lv1,lv2) find (or create) the corresponding vertices *)
  let state, vertex_pairs =
    let state = ref state in
    let find_vertex (lv1, lv2) =
      try
        let v2 = find_lval_vertex lv2 sum_state in
        let v1, new_state = find_or_create_lval_or_ref_vertex lv1 !state in
        state := new_state;
        Some (v1, v2)
      with Not_found -> None
    in
    !state, List.filter_map find_vertex arg_formal_pairs
  in

  (* merge the function graph;
     for every arg/formal vertex pair (v1,v2) and every edge v2→v create edge v1→v. *)
  let g =
    let transfer_succs (g : G.t) (v1,v2) =
      List.fold_left
        (fun g e -> G.add_edge_e g @@ E.create v1 (E.label e) (E.dst e))
        g
        (G.succ_e sum_state.graph v2)
    in
    let g = state.graph in
    let g = G.fold_vertex (fun i g -> G.add_vertex g i) sum_state.graph g in
    let g = G.fold_edges_e (fun e g -> G.add_edge_e g e) sum_state.graph g in
    List.fold_left transfer_succs g vertex_pairs
  in

  (* garbage collect: remove leaf vertices from g that originate from sum_state *)
  let vertices_to_add_to_g, g =
    let g = ref g in
    let remove_if_leaf v _ =
      if G.in_degree !g v = 0
      then let () = g := G.remove_vertex !g v in None
      else Some VarSet.empty
    in
    let remaining_vertices = VMap.filter_map remove_if_leaf sum_state.vmap in
    remaining_vertices, !g
  in

  let state = {
    graph = g;
    varmap = state.varmap;
    vmap =
      let left_bias _ l _ = Some l in
      VMap.union left_bias state.vmap vertices_to_add_to_g}
  in

  asserting_invariants
    (List.fold_left join_succs state @@ List.map fst vertex_pairs)

module Dot = struct
  let find_varset_ref = Extlib.mk_fun "find_varset"

  include Graph.Graphviz.Dot (struct
      include G
      let edge_attributes _ = []
      let default_edge_attributes _ = []
      let get_subgraph _ = None
      let vertex_attributes v =
        let lset = !find_varset_ref v in
        let label =
          VarSet.pretty Format.str_formatter lset;
          Format.flush_str_formatter ()
        in
        [`Label label]

      let vertex_name (v:V.t) = string_of_int v
      let default_vertex_attributes _ = [`Shape `Box]
      let graph_attributes _ = []
    end)
end

module API = struct
  type summary = Summary.s

  let pretty_summary = Summary.pretty

  let make_summary = Summary.make

  let vid (v : V.t) : int = v

  let rec closure_find_lset (v:V.t) (x:t) : (V.t * LSet.t) list =
    match G.psucc_opt x.graph v with
    | None -> [v, Readout.get_lval_set v x]
    | Some v_next -> (v, Readout.get_lval_set v x) :: closure_find_lset v_next x

  let find_transitive_closure  (lv:lval) (x:t) : (V.t * LSet.t) list =
    let lv = Lval.simplify lv in
    assert_invariants x;
    try closure_find_lset (find_lval_vertex lv x) x with Not_found -> []
  (* TODO : what about offsets ? *)

  let get_lval_set = Readout.get_lval_set
  let find_aliases = Readout.find_aliases
  let find_all_aliases = Readout.find_all_aliases
  let points_to_set = Readout.points_to_set

  let get_graph (x:t) = x.graph

  let print_dot filename (a:t) =
    let file = open_out filename in
    Dot.find_varset_ref := (fun v -> find_varset v a);
    Dot.output_graph file a.graph;
    close_out file
end

include API
