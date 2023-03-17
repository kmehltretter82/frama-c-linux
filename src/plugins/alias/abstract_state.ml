(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2023                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)

open Graph

open Cil_types

open Cil_datatype

open Simplified

(* (\** module for vertices *\)
 * module V = struct
 *
 *   type t =
 *     {
 *       id : Int.t; (\* id must be unique in a graph *\)
 *       set : LSet.t
 *     }
 *
 *   let cmpt_v = ref (-1)
 *
 *   let new_id () = incr cmpt_v; !cmpt_v
 *
 *   let compare x y = Int.compare x.id y.id
 *
 *   let hash x = Hashtbl.hash x.id (\* toto utiliser fonction hash frama-c *\)
 *
 *   let equal x y = (compare x y = 0)
 *
 *   let create s = { id = new_id () ; set = s}
 *
 *   let label x = x.set
 *
 * end *)


module G = Persistent.Digraph.Concrete(Datatype.Int)

module V = G.V

module VSet = Datatype.Int.Set
module VMap = Datatype.Int.Map

module LSet = Simplified_lset
module LMap = Lval.Map

module LLSet = Lval.Set

let convert_llset (s:LLSet.t) : LSet.t=
  LLSet.fold
    (fun lv acc -> LSet.add (BLval lv) acc)
    s
    LSet.empty

type t = {
  graph : G.t;
  pending : VSet.t VMap.t ; (* pending(v) is the set of vertices v' that could be aliased to v if v becomes/ is detected as a pointer *)
  lmap : V.t LMap.t ; (* lmap(lv) is the vertex v corresponding to lval lv, in other words lv is in label(v) *)
  vmap : LLSet.t VMap.t ;(* reverse of lmap *)
  cmpt : Int.t ; (* counter to create new vertex *)
}

module type S =
sig

  (** Type denothing an abstract state of the analysis. It is a graph containing
      all aliases and points-to information. *)
  type t

  (** access to the points-to graph *)
  val get_graph: t -> G.t

  (** set of lvals stored in a vertex *)
  val get_lval_set : G.V.t -> t -> LSet.t


  (** pretty printer; debug=true prints the graph, debug = false only
      prints aliased variables *)
  val pretty : ?debug:bool -> Format.formatter -> t -> unit

  (** dot printer; first argument is a file name *)
  val print_dot : string -> t -> unit

  (** finds the vertex corresponding to a lval. May raise @Not_found
  *)
  val find_vertex : lval -> t -> G.V.t

  (** same as previous function, but return a set of lval. Cannot
      raise an exception but may return an empty set *)
  val find_aliases : lval -> t -> LSet.t

  (** find_aliases, then recursively finds other sets of lvals. We
      have the property (if lval [lv] is in abstract state [x]) :
      List.hd (find_transitive_closure lv x) = find_aliases lv x *)
  val find_transitive_closure : lval -> t -> LSet.t list

  (** inclusion test; [is_included a1 a2] tests if, for any lvl
      present in a1 (associated to a vertex v1), that it is also
      present in a2 (associated to a vertex v2) and that
      get_lval_set(succ(v1) is included in get_lval_set(succ(v2)) *)
  val is_included : t -> t -> bool

end

(* find functions *)
let find_lset (v:V.t) (x:t) =
  try VMap.find v x.vmap
  with Not_found -> LLSet.empty

let find_aliases_internal (lv:lval) (x:t) =
  try find_lset (LMap.find lv x.lmap) x
  with Not_found -> LLSet.empty

let get_graph (x:t) = x.graph

(* renamed for the interface *)
let get_lval_set v x =
  convert_llset (find_lset v x)

let find_aliases lv x =
  convert_llset(find_aliases_internal lv x)


(* printing functions *)

let print_debug fmt (x:t) =
  Format.fprintf fmt "@[<hov 2>List of vertices: @.";
  G.iter_vertex (fun v -> Format.fprintf fmt "(id=%d LSet= %a)@." v LLSet.pretty (find_lset v x)) x.graph;
  Format.fprintf fmt "@]@.@[<hov 2>List of edges: @.";
  G.iter_edges (fun v1 v2 -> Format.fprintf fmt "(%d -> %d)@." v1 v2) x.graph;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "@[<hov 2>Pending: @.";
  VMap.iter (fun v vs -> Format.fprintf fmt "(id=%d pending= %a)@." v VSet.pretty vs) x.pending;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "@[<hov 2>LMap: @.";
  LMap.iter (fun lv v -> Format.fprintf fmt "(lval=%a -> id= %d)@." Lval.pretty lv v) x.lmap;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "@[<hov 2>VMap: @.";
  VMap.iter (fun v ls -> Format.fprintf fmt "(id = %d -> lset= %a)@." v LLSet.pretty ls) x.vmap;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "cmpt: %d@." x.cmpt

let print_aliases fmt (x:t) =
  let iter_vmap v set_lv =
    if G.mem_vertex x.graph v then
      match G.succ x.graph v with
        [] -> ()
      | [_] ->
        begin
          let set_pred = ref LLSet.empty in
          G.iter_pred
            (fun v -> set_pred := LLSet.union !set_pred (VMap.find v x.vmap))
            x.graph
            v;
          if LLSet.cardinal set_lv + LLSet.cardinal !set_pred >= 2
          then
            Format.fprintf fmt "{%a%a} are aliased@."
              (fun fmt s ->
                 LLSet.iter
                   (fun lv -> Format.fprintf fmt "%a; " Lval.pretty lv)
                   s
              )
              set_lv
              (fun fmt s ->
                 LLSet.iter
                   (fun lv -> Format.fprintf fmt "*%a; " Lval.pretty lv)
                   s
              )
              !set_pred
        end
      | _ -> failwith "this should not happen"
  in
  Format.fprintf fmt "@[<hov 2><list of may-alias>@.";
  VMap.iter iter_vmap x.vmap;
  Format.fprintf fmt "<end of list>@]@."

let pretty ?(debug=false) =
  if debug then
    print_debug
  else
    print_aliases


(** invariants of type t must be true before and after each functon call *)
let assert_invariants (x:t) : unit =
  (* check that all vertex of the graph have entries in pending and
     vmap, and are integer between 0 and cmpt, and have at most 1
     successor *)
  let assert_vertex (v:V.t) =
    assert (v >= 0);
    assert (v < x.cmpt);
    assert (VMap.mem v x.pending);
    assert (VMap.mem v x.vmap);
    assert (List.length (G.succ x.graph v) <= 1)
  in
  G.iter_vertex assert_vertex x.graph;
  let assert_edge v1 v2 =
    assert (G.mem_vertex x.graph v1);
    assert (G.mem_vertex x.graph v2)
  in
  G.iter_edges assert_edge x.graph;
  let assert_lmap (lv:lval) (v:V.t) =
    assert (G.mem_vertex x.graph v);
    assert (LLSet.mem lv (VMap.find v x.vmap))
  in
  LMap.iter assert_lmap x.lmap;
  let assert_vmap (_:V.t) (ls:LLSet.t) =
    (* if LLSet.is_empty ls then
     *   begin (\* it is a constant vertex, so it must have no succ and at least 1 pred *\)
     *     assert (List.length (G.succ x.graph v) = 0);
     *     assert (List.length (G.pred x.graph v) > 0);
     *   end; *)
    assert (LLSet.fold (fun lv acc -> acc && LMap.mem lv x.lmap) ls true)
  in
  VMap.iter assert_vmap x.vmap

(* for debuging *)
let assert_invariants x =
  try assert_invariants x
  with
    Assert_failure f ->  (Format.printf "DEBUG FAILED INVARIANTS@.%a@." (pretty ~debug:true) x; raise (Assert_failure f))


(* find functions, part 2 *)
let rec closure_find_lset (v:V.t) (x:t) =
  match G.succ x.graph v with
    [] -> [find_lset v x]
  | [v_next] -> (find_lset v x)::(closure_find_lset v_next x)
  | _ -> failwith ("this shall not happen (invariant broken)")

let find_transitive_closure  (lv:lval) (x:t) =
  assert_invariants x;
  try
    let v = (LMap.find lv x.lmap) in
    List.map convert_llset (closure_find_lset v x)
  with
    Not_found -> []


(* find the vertex of an lval *)
let find_vertex (lv:lval) (x:t) =
  LMap.find lv x.lmap
(** @raise Not_found if there is not such an lval in the graph *)

(* NOTE on "constant vertex": a constant vertex represents an unamed
   scalar value (type bottom in steensgaard's paper), or the address
   of a variable. It means that in [vmap], its associated LSet is
   empty.  By definition, constant vertex cannot be associated to a
   lval in [lmap] *)
let create_cst_vertex (x:t) : V.t * t =
  let new_v = x.cmpt in
  let new_g = G.add_vertex x.graph new_v in
  let new_pending = VMap.add new_v VSet.empty x.pending in
  let new_lmap = x.lmap in
  let new_vmap = VMap.add new_v LLSet.empty x.vmap in
  new_v ,
  {graph = new_g ;
   pending = new_pending ;
   lmap = new_lmap ;
   vmap = new_vmap ;
   cmpt = x.cmpt+1}


let create_vertex (lv:lval) (x:t) : V.t * t =
  let new_v = x.cmpt in
  let new_g = G.add_vertex x.graph new_v in
  let new_pending = VMap.add new_v VSet.empty x.pending in
  let new_lmap = LMap.add lv new_v x.lmap in
  let new_vmap = VMap.add new_v (LLSet.singleton lv) x.vmap in
  (* if [lv] is a pointer variable, also create a vertex labelled by
     *[lv] *)
  let new_x =
    {graph = new_g ;
     pending = new_pending ;
     lmap = new_lmap ;
     vmap = new_vmap ;
     cmpt = x.cmpt+1}
  in
  assert_invariants new_x;
  match lv with
  | (Var v, NoOffset) ->
    begin
      match v.vtype with
        TPtr _ ->
        (* then add a blank vertex *)
        let another_v, new_x = create_cst_vertex new_x in
        let new_g = G.add_edge new_x.graph new_v another_v in
        new_v, {new_x with graph= new_g}
      | _ ->   new_v ,new_x
    end
  | _ ->
    new_v , new_x


let find_or_create_vertex (lv:lval) (x:t) : V.t * t =
  try find_vertex lv x , x with
    Not_found -> create_vertex lv x

let points_to (lv:lval) (x:t): V.t list * t =
  let (v,x) = find_or_create_vertex lv x in
  G.succ x.graph v, x

let addr_of (lv:lval) (x:t) : V.t list * t =
  let (v,x) = find_or_create_vertex lv x in
  G.pred x.graph v, x

let remove_cst_vertex (v:V.t) (x:t) : t =
  assert (LLSet.is_empty (VMap.find v x.vmap));
  {
    graph = G.remove_vertex x.graph v;
    pending = VMap.remove v x.pending;
    lmap = x.lmap;
    vmap = VMap.remove v x.vmap;
    cmpt = x.cmpt
  }

(* remove a lval from a graph*)
let remove_lval (x:t)  (lv:lval) :t =
  assert_invariants x;
  let new_x =
    try
      let v = LMap.find lv x.lmap in
      let setv= VMap.find v x.vmap in
      let new_lmap = LMap.remove lv x.lmap in
      let new_vmap = VMap.add v (LLSet.remove lv setv) x.vmap in
      {x with lmap = new_lmap; vmap = new_vmap}
    with
      Not_found -> x
  in
  assert_invariants new_x; new_x



let find_vertex_name_ref = Extlib.mk_fun "find_vertex_name"


let lset_to_string (s: LSet.t) : string =
  let fmt = Format.str_formatter in
  Format.fprintf fmt "\"%a\"" LSet.pretty s;
  Format.flush_str_formatter ()

module Dot = Graphviz.Dot(struct
    include G
    let edge_attributes _ = []
    let default_edge_attributes _ = []
    let get_subgraph _ = None
    let vertex_attributes _ = [`Shape `Box]
    let vertex_name (v:V.t) =
      let lset = !find_vertex_name_ref v in
      let v_name = lset_to_string lset in
      Format.printf "Vertex %d set %s@." v v_name;
      v_name
    let default_vertex_attributes _ = []
    let graph_attributes _ = []
  end)

let print_dot _filename (_a:t) =
  Options.fatal "not implemented"
(* let file = open_out filename in
 * find_vertex_name_ref :=
 *   (fun v -> find_lset v a
 *   );
 * Dot.output_graph file a.graph;
 * close_out file *)

(* merge of two vertices; the first vertex carries both sets, the second is removed from the graph and from lmap and vmap; however, pending is NOT updated  *)
let merge x v1 v2 =
  if (V.equal v1 v2) || not (G.mem_vertex x.graph v1) || not (G.mem_vertex x.graph v2)
  then x
  else
    let set1 = find_lset v1 x in
    let set2 = find_lset v2 x in
    let new_set = LLSet.union set1 set2 in
    (* update lmap : every lval in v2 must now be associated with v1*)
    let new_lmap = LLSet.fold (fun lv2 m -> LMap.add lv2 v1 m) set2 x.lmap in
    (* update vmap *)
    let new_vmap = VMap.add v1 new_set (VMap.remove v2 x.vmap) in
    (* update the graph *)
    let f_fold_succ v_succ (g:G.t) : G.t =
      G.add_edge g v1 v_succ
    and f_fold_pred v_pred (g:G.t) : G.t =
      G.add_edge g v_pred v1
    in
    let g = x.graph in
    (* adds all new edges *)
    let g = G.fold_succ f_fold_succ g v2 g in
    let g = G.fold_pred f_fold_pred g v2 g in
    (* remove v2 *)
    let g =  G.remove_vertex g v2 in
    {graph = g; pending = x.pending; lmap = new_lmap ; vmap = new_vmap ; cmpt = x.cmpt}


(** functions for steensgard's algorithm *)


(* functions join and unify-pointer of steensgaard's paper *)
let rec join (x:t) (v1:V.t) (v2:V.t) : t =
  if (V.equal v1 v2) || not (G.mem_vertex x.graph v1 && G.mem_vertex x.graph v2)
  then
    x
  else
    let pt1 = G.succ x.graph v1 in (* TODO ask frama-c type instead of looking in the graph *)
    let pt2 = G.succ x.graph v2 in
    let x = merge x v1 v2 in
    assert (not (G.mem_vertex x.graph v2));
    match (pt1, pt2) with
      [],[] ->
      (* update pending *)
      let p = VMap.add v1 (VSet.union (VMap.find v1 x.pending) (VMap.find v2 x.pending)) x.pending in
      let new_pending = VMap.remove v2 p in
      {x with pending = new_pending }
    | [], _ ->
      (* join pending v1 *)
      let x =
        VSet.fold
          (fun v x -> join x v v1)
          (try VMap.find v1 x.pending with Not_found -> VSet.empty )
          x
          (* update pending *)
      in let new_pending = VMap.add v1 VSet.empty (VMap.remove v2 x.pending) in
      {x with pending = new_pending }
    | _, [] ->
      (* join pending v2 *)
      let x =
        VSet.fold
          (fun v x -> join x v v1)
          (try VMap.find v2 x.pending with Not_found -> VSet.empty )
          x
      in let new_pending = VMap.add v1 VSet.empty (VMap.remove v2 x.pending) in
      {x with pending = new_pending }
    | _, _ ->
      (* assert pending(v1) = empty and assert pending (v2) =empty *)
      let new_pending = (VMap.remove v2 x.pending) in
      (* join the succesors *)
      unify {x with pending=new_pending} pt1 pt2

(* [unify x l1 l2] folds [join x v1 v2] for all [v1] in [l1] and all [v2] in [l2] *)
and unify (x:t) (l1:V.t list) (l2:V.t list) =
  match l1 with
    [] -> x
  | v1::qq ->
    let x = unify2 x v1 l2 in
    unify x qq l2

(* [unify2 x v1 l2] folds [join x v1 v2] for all [v2] in [l2] *)
and unify2 (x:t) (v1:V.t) (l2:V.t list) =
  match l2 with
    [] -> x
  | v2::qq ->
    let x = join x v1 v2 in
    unify2 x v1 qq

(* since the recursive version of join, unify, unify2 and merge may break the invariants *)
let join (x:t) (v1:V.t) (v2:V.t) : t =
  (* Options.feedback ~level:2 "GRAPH BEFORE JOIN(v_%d,v_%d) @.%a@." v1 v2 (pretty ~debug:true) x; *)
  assert_invariants x;
  let res = join x v1 v2 in
  assert_invariants res; res

let cjoin  (x:t) (v1:V.t) (v2:V.t) : t =
  assert_invariants x;
  let pt2 =  G.succ x.graph v2 in
  if pt2 = []
  then
    let old_set = try VMap.find v1 x.pending with Not_found -> VSet.empty in
    let new_pending = VMap.add v1 (VSet.add v2 old_set) x.pending in
    {x with pending=new_pending}
  else
    join x v1 v2

(* in Steensgard's paper, this is written settype(v1,ref(v2,bot)) *)
let set_type (x:t) (v1:V.t) (v2:V.t) : t =
  assert_invariants x;
  (* if v1 points to another node, suppress current outgoing edge (and the node if it is a constant node) *)
  let g =
    match G.succ x.graph v1 with
      [] -> x.graph
    | [v2] ->
      (* if v2 is a constant node supress it directly *)
      if LLSet.is_empty (VMap.find v2 x.vmap)
      then G.remove_vertex x.graph v2
      else G.remove_edge x.graph v1 v2
    | _ -> failwith "two many outgoing edges in set_type"
  in
  let new_g = G.add_edge g v1 v2 in
  VSet.fold (fun vx x -> join x v1 vx) (try VMap.find v1 x.pending with Not_found -> VSet.empty) {x with graph = new_g}


(* assignment x = y *)
let assignment_x_y (a:t) (x:lval) (y:lval) : t =
  assert_invariants a;
  let (v1,a) = find_or_create_vertex x a in
  let (v2,a) = find_or_create_vertex y a in
  let new_a = cjoin a v1 v2 in
  assert_invariants new_a ; new_a


(* assignment x = &y *)
let assignment_x_addr_y (a:t) (x:lval) (y:lval) : t =
  assert_invariants a;
  let v1, a = find_or_create_vertex x a in
  let list_v2, a = addr_of y a in
  let new_a =
    if list_v2 = []
    then
      let v2, a = find_or_create_vertex y a in
      set_type a v1 v2
    else
      List.fold_left
        (fun a_acc v2 -> join a_acc v1 v2)
        a
        list_v2
  in
  assert_invariants new_a ; new_a


(* assignment x = *y *)
let assignment_x_ptr_y (a:t) (x:lval) (y:lval) : t =
  assert_invariants a;
  let v1, a = find_or_create_vertex x a in
  let list_v2, a = points_to y a in
  let new_a =
    match list_v2 with
      [] -> let v2 = find_vertex y a in set_type a v2 v1
    | [v2] -> cjoin a v1 v2
    | _ ->  failwith "assignment_x_ptr_y not implemented"
  in
  assert_invariants new_a ; new_a

(* assignment x = allocate(y) *)
let assignment_x_allocate_y (a:t) (x:lval) : t =
  assert_invariants a;
  let (v1,a) = find_or_create_vertex x a in
  let (v2,a) = create_cst_vertex a in
  let new_a = set_type a v1 v2 in
  assert_invariants new_a ; new_a

(* assignment *x = y *)
let assignment_ptr_x_y (a:t) (x:lval) (y:lval) : t =
  assert_invariants a;
  let v2, a = find_or_create_vertex y a in
  let list_v1, a = points_to x a in
  let new_a =
    match list_v1 with
      [] ->  let v1 = find_vertex x a in set_type a v1 v2
    |  [v1] -> cjoin a v1 v2
    | _ ->  failwith "assignment_ptr_x_y not implemented"
  in
  assert_invariants new_a ; new_a


(* assignment *x = cst *)
let assignment_ptr_x_cst (a:t) (x:lval) : t =
  assert_invariants a;
  (* Format.printf "DEBUG (assignment_ptr_x_cst) on lval %a and state:@. %a @." Lval.pretty x print_debug a; *)
  let v2, a = create_cst_vertex a in
  let (list_v1, a) : V.t list * t = points_to x a in
  let new_a =
    match list_v1 with
      [] ->  let v1 = find_vertex x a in set_type a v1 v2
    | _ -> let f_fold (acc:t) (v1:V.t) : t = cjoin acc v1 v2
      in List.fold_left f_fold a list_v1
  in
  assert_invariants new_a ; new_a


(* we don't need to iterate on loops *)
let _equal (_:t) (_:t) = true


exception Not_included

let is_included (a1:t) (a2:t) =
  (* tests if a1 is included in a2, at least as the nodes with lval *)
  assert_invariants a1;
  assert_invariants a2;
  (* Format.printf "DEBUG testing equal @.%a@. AND à.%a@. END DEBUG@." (pretty ~debug:true) a1 (pretty ~debug:true) a2; *)
  try
    let iter_lmap (lv:Lval.t) (v1:V.t): unit =
      let v2 : V.t = try LMap.find lv a2.lmap with Not_found -> raise Not_included in
      match G.succ a1.graph v1, G.succ a2.graph v2 with
        [], _ -> ()
      | [_], [] -> raise Not_included
      | [v1p], [v2p] ->
        if LLSet.subset (VMap.find v1p a1.vmap) (VMap.find v2p a2.vmap)
        then
          ()
        else
          raise Not_included
      | _ -> Options.fatal "this should not hapen (invariant broken)"
    in
    LMap.iter iter_lmap a1.lmap; true
  with
    Not_included -> false

(* let equal (a1:t) (a2:t) =
 *   assert_invariants a1;
 *   assert_invariants a2;
 *   Format.printf "DEBUG testing equal @.%a@. AND à.%a@. END DEBUG@." (pretty ~debug:true) a1 (pretty ~debug:true) a2;
 *   try
 *     let card = LMap.cardinal a1.lmap in
 *     if (card = LMap.cardinal a2.lmap)
 *     && G.nb_vertex a1.graph = G.nb_vertex a2.graph
 *     && G.nb_edges a1.graph = G.nb_edges a2.graph
 *     (\* the invariants assure that if the nb of vertex is equal, then
 *        the size of pending and vmap are also equal. nb counters may be
 *        different, it doesn't matter *\)
 *     then
 *       begin
 *         (\* builds the isomorphism between vertex numbers as an
 *              Hastable Int.t -> Int.t *\)
 *           let iso : (V.t, V.t) Hashtbl.t = Hashtbl.create card in
 *           LMap.iter
 *             (fun lv v1 ->
 *                let v2 : V.t = try LMap.find lv a2.lmap with Not_found -> raise Not_equal in
 *                try if not (V.equal (Hashtbl.find iso v1) v2) then raise Not_equal
 *                with Not_found ->
 *                  Hashtbl.add iso v1 v2
 *             )
 *             a1.lmap;
 *           (\* now, iso is the isomorphism between vertex numbers. NB constant vertices are NOT in the map *\)
 *           (\* we check, for every vertex of a1.graph, that its successors and predecessors are isomorphic *\)
 *           let check_vertex (v1:V.t) : unit =
 *             if not (LLSet.is_empty (VMap.find v1 a1.vmap))
 *             then (\* v1 is not a constant node, so it is an entry in iso *\)
 *               let v2 =
 *                 try
 *                   Hashtbl.find iso v1
 *                 with
 *                   Not_found -> failwith "this should not happen (broken invariant or hashtable iso)"
 *               in
 *               begin
 *                 (\* we only need to check the successors; the predecessor will be checked because we iterate on all vertex *\)
 *                 match G.succ a1.graph v1 with
 *                   [] -> (\* if v1 has no successor, then so must have v2 *\)
 *                   if List.length (G.succ a2.graph v2) > 0 then raise Not_equal
 *
 *                 | [succ_v1] ->
 *                   begin
 *                     if LLSet.is_empty (VMap.find succ_v1 a1.vmap)
 *                     then
 *                       (\* veryfy that v2 has a successor that is also a constant vertex*\)
 *                       match G.succ a2.graph v2 with
 *                         [succ_v2] when LLSet.is_empty (VMap.find succ_v2 a2.vmap) -> ()
 *                       | _ -> raise Not_equal
 *                     else
 *                       let succ_v2 : V.t =
 *                         try
 *                           Hashtbl.find iso succ_v1
 *                         with
 *                           Not_found -> failwith "this should not happen (broken invariant or hashtable iso)"
 *                       in
 *                       (\* simply check for an edge between v2 and succ v_2 *\)
 *                       if not (G.mem_edge a2.graph v2 succ_v2) then raise Not_equal
 *                   end
 *                 | _ -> failwith "this should not happen (broken invariant)"
 *               end
 *             else (\* if it is a constant node, nothing to do *\)
 *               ()
 *           in
 *           G.iter_vertex check_vertex a1.graph; true
 *         end
 *     else
 *       (\* if the cardinal is different, there cannot be an isomorphism *\)
 *       false
 *   with
 *     Not_equal -> false *)


module VPairs =
struct
  type t = V.t * V.t
  let compare (x0,y0) (x1,y1) =
    match V.compare x0 x1 with
      0 -> V.compare y0 y1
    | c -> c
end

module V2Set = Set.Make(VPairs)



(* rename all vertex re-enumerate all vertex of [x] from 0 to nb_vertex -1 *)
let rename_all_vertex (x:t) : t =
  assert_invariants x;
  let new_cmpt = ref 0 in
  let tbl_rename = Hashtbl.create (G.nb_vertex x.graph) in
  (* fill the table *)
  G.iter_vertex  (fun v -> Hashtbl.add tbl_rename v !new_cmpt ; incr new_cmpt) x.graph;
  let r v =
    try
      Hashtbl.find tbl_rename v
    with
      Not_found -> Format.printf "DEBUG FAILED RENAME (%d not found) @.%a@." v (pretty ~debug:true) x; raise Not_found
  in
  let renamed_graph =
    (* rename the graph and write the table *)
    G.map_vertex
      r
      x.graph
  in

  let renamed_pending =
    VMap.fold
      (fun v vs acc ->
         if G.mem_vertex x.graph v
         then VMap.add (r v) vs acc
         (* if it is not a vertex, then it is an aritfact of the map *)
         else acc
      )
      x.pending
      VMap.empty
  in
  let renamed_lmap =
    LMap.map
      r
      x.lmap
  in
  let renamed_vmap =
    VMap.fold
      (fun v ls acc ->
         if G.mem_vertex x.graph v
         then
           VMap.add (r v) ls acc
         else
           acc
      )
      x.vmap
      VMap.empty
  in
  let new_x =
    {graph = renamed_graph; pending = renamed_pending ; lmap = renamed_lmap ; vmap = renamed_vmap ; cmpt = !new_cmpt }
  in
  assert_invariants new_x; new_x

let union  (a1:t) (a2:t) :t =
  (* naive algorithm :
     1 rename any vertex in a2 (by adding a1.cmpt) to avoid any confusion between vertex of the tw graphs
     2 merge the graph and the vmap and pending (by doing union of sets)
     3 for any lval [lv] that are has an entry in both a1.lmap and a2.lmap, merge the two vertex a1.lmap[lv]
       and a2.lmap[lv]

     I am not confident about this function, there are too many potential bugs and inefficiencies
  *)
  assert_invariants a1;
  assert_invariants a2;
  let f_v2 x = x + a1.cmpt in
  (* we build the new graph, starting from a1.graph *)
  let g = a1.graph in
  (* add all vertex of a2 in g *)
  let g =
    G.fold_vertex
      (fun v2 g -> G.add_vertex g (f_v2 v2))
      a2.graph
      g
  in
  (* add all edges of a2 in g *)
  let new_graph =
    G.fold_edges
      (fun v2a v2b g -> G.add_edge g (f_v2 v2a) (f_v2 v2b))
      a2.graph
      g
  in
  let new_pending =
    VMap.fold
      (fun v2 p2 m -> VMap.add (f_v2 v2) p2 m)
      a2.pending
      a1.pending
  in
  let new_vmap =
    VMap.fold
      (fun v2 lset2 m -> VMap.add (f_v2 v2) lset2 m)
      a2.vmap
      a1.vmap
  in
  (* s_acc = set of couples that should be merged in step 3 *)
  let set_to_be_merged, new_lmap =
    LMap.fold
      (fun lv v2 (s_acc, m_acc) ->
         (* if lv has an entry in a1.lmap, then add the two vertex to be merged *)
         try let v1 = LMap.find lv a1.lmap  in (V2Set.add (v1,(f_v2 v2)) s_acc, m_acc)
         (* WARNING : potential bug here: the invariant of lmap is broken
            since lv shall be mapped to both v1 and (f_v2 v2); the merge
            that are done in step 3 shall restore the invariant*)
         with
         (* if not, simply add the lval -> f_v2 v2 in m_acc *)
           Not_found -> (s_acc, LMap.add lv (f_v2 v2) m_acc)
      )
      a2.lmap
      (V2Set.empty, a1.lmap)
  in
  let new_a = { graph = new_graph ; pending = new_pending ; lmap = new_lmap ; vmap = new_vmap ; cmpt = a1.cmpt + a2.cmpt } in

  (* step 3 *)
  let new_a =
    V2Set.fold
      (fun (v1,v2) a ->
         let new_a = merge a v1 v2 in
         let new_vset  =
           try VSet.union (VMap.find v1 new_a.pending) (VMap.find v2 new_a.pending)
           with Not_found -> failwith "bug here"
         in
         (* warning: exploits the fact that v1 is preserved in the merge operation *)
         let new_pending = VMap.add v1 new_vset (VMap.remove v2 new_a.pending) in
         { new_a with pending = new_pending }
      )
      set_to_be_merged
      new_a
  in
  (* there may be some inconsistancies with constant nodes, so we clean up *)
  let clean_up_constant_successors (v:V.t) (res_a:t) : t =
    let l_succ = G.succ new_a.graph v in
    if l_succ = []
    then res_a (* nothing to do *)
    else
      (* find the only successor that is not a constant node *)
      let true_succ =
        List.fold_left
          (fun res v ->
             if LLSet.is_empty (VMap.find v res_a.vmap)
             then res
             else v)
          (List.hd l_succ)
          l_succ
      in
      (* eliminate all nodes that is not the true successor *)
      List.fold_left
        (fun res_a v -> if V.equal v true_succ then res_a else remove_cst_vertex v res_a)
        res_a
        l_succ
  in
  let new_a =
    G.fold_vertex
      clean_up_constant_successors
      new_a.graph
      new_a
  in
  let new_a =
    (* if new_a.cmpt > 2 * (G.nb_vertex new_a.graph)
     * then *)
    rename_all_vertex new_a
    (* else
     *   new_a *)
  in
  assert_invariants new_a;
  new_a

let empty :t =
  {graph = G.empty; pending = VMap.empty ; lmap = LMap.empty; vmap = VMap.empty; cmpt = 0}


(* let make_top (x:t) : t =
 *   if x.graph = G.empty
 *   then x
 *   else
 *     let g = G.add_edge (G.add_vertex G.empty 0) 0 0 in
 *     (\* collect all lval of the initial set *\)
 *     let set_lv = ref LLSet.empty in
 *     let lmap =
 *       LMap.mapi
 *         (fun lv _ -> set_lv := LLSet.add lv !set_lv ; 0)
 *         x.lmap
 *     in
 *     let vmap =
 *       VMap.add 0 !set_lv VMap.empty
 *     in
 *     let p = VMap.add 0 VSet.empty VMap.empty in
 *     {graph = g ; pending = p ; lmap = lmap ; vmap = vmap ; cmpt = 1} *)

(** a type for summaries of functions *)
type summary =
  {
    state : t option;
    formals: lval list;
    locals: lval list;
    return : exp option
  }

let make_summary (s: t option) (kf: kernel_function) =
  let exp_return : exp option =
    if Kernel_function.has_definition kf then
      let return_stmt = Kernel_function.find_return kf in
      match return_stmt.skind with
        Return (e, _) -> e
      | _ -> failwith "this should not happen"
    else
      None
  in
  {
    state = s;
    formals = List.map (fun v -> (Var v,NoOffset)) (Kernel_function.get_formals kf);
    locals = List.map (fun v -> (Var v,NoOffset))  (Kernel_function.get_locals kf);
    return = exp_return
  }


let pretty_summary ?(debug=false) ?(function_name="") fmt s =
  let print_list_lval fmt (l: lval list) =
    List.iter (fun x -> Format.fprintf fmt "%a " Lval.pretty x) l
  in
  let print_option pp fmt x =
    match x with
    | Some x -> pp fmt x
    | None -> Format.fprintf fmt "<None>"
  in
  Format.fprintf fmt "@[<hov 2>Summary of function %s: @." function_name;
  Format.fprintf fmt "formals: %a locals : %a return expression: %a @.State: @[<hov 2>%a@] " print_list_lval s.formals print_list_lval s.locals (print_option Exp.pretty) s.return (print_option (pretty ~debug)) s.state;
  Format.fprintf fmt "@]@."


let call (state:t) (res:lval option) (args:exp list) (summary:summary) :t =
  assert_invariants state;
  let formals = summary.formals in
  let sum_state =
    match summary.state with
      None -> failwith "BUG this should not happen"
    | Some s -> s
  in
  assert (List.length args = List.length formals);
  (* check that formal variables do no appear in state *)
  List.iter
    (fun lv -> assert (not (LMap.mem lv state.lmap)))
    formals;
  (* union of the two graphs *)
  let new_state = union state sum_state in
  (* union of formal parameters *)
  let new_state =
    List.fold_left2
      (fun acc param formal ->
         begin
           match  formal, Simplified_lval.from_exp param with
             ((Var v1, NoOffset), BLval (Var v2,NoOffset)) ->
             (* case x = y *)
             assignment_x_y acc (Var v1, NoOffset) (Var v2, NoOffset)
           | ((Var _, NoOffset), BNone) -> acc
           (* constant assignments : do nothing, but maybe check the type of the assigned variable ? *)
           | ((Var v1, NoOffset), BAddrOf lv2) ->
             (* case x = &y *)
             assignment_x_addr_y acc (Var v1, NoOffset) lv2
           | ((Var v1, NoOffset), BLval (Mem e2, NoOffset)) ->
             (* case x  = *y *)
             begin
               match e2.enode with
                 Lval lv2 -> assignment_x_ptr_y acc (Var v1, NoOffset) lv2
               |  _ -> (Options.feedback "In a function call, parameter (@[%a@] <- @[%a@]) is ignored)" Lval.pretty formal Exp.pretty param; acc)
             end
           | _ -> (Options.feedback "DEBUG: call function - formal variable not as we expected@."; acc)
         end
      )
      new_state
      args
      formals
  in
  (* set the result *)
  let new_state =
    match (res, summary.return) with
      None, _  -> new_state
    | (Some res, Some exp_res) ->
      begin
        let v_res,new_state  = find_or_create_vertex res new_state in
        match Simplified_lval.from_exp exp_res with
          BLval lval_exp_res ->
          begin
            try
              let v_exp_res =  LMap.find lval_exp_res new_state.lmap in
              join new_state v_res v_exp_res
            with
              Not_found -> (Options.feedback ~level:2 "result expression %a does not appear in the summary of the called function (ressult not assigned)" Lval.pretty lval_exp_res; new_state)
          end
        | _ -> new_state
      end
    | (Some _, None) -> (Options.warning "a function with no return is employed in an assignment" ; new_state)
  in
  (* erase all formals and all locals from the tables/graphs *)
  let new_state =
    List.fold_left
      remove_lval
      new_state
      (summary.formals@summary.locals)
  in
  assert_invariants new_state;
  new_state
