(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2017                                               *)
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

module OCamlGraph = Graph
module Frama_c_File = File
open Cil_datatype

[@@@ warning "-40-42"]

module Node : sig
  include Datatype.S_with_collections
  val id: t -> int
  val of_int: int -> t
  val dumb: t
  val next: unit -> t
end = struct
  include Datatype.Int
  let id x = x
  let of_int x = x
  let dumb = 0
  module Counter = State_builder.Counter(struct let name = "Traces_domain.Edge.Counter" end)
  let next () = Counter.next ()
end

(** Can't use Graph.t it needs an impossible recursive module *)
module GraphShape = Hptmap.Shape(Node)

type edge =
  | Assign of Node.t * Cil_types.lval * Cil_types.typ * Cil_types.exp
  | Assume of Node.t * Cil_types.exp * bool
  | EnterScope of Node.t * Cil_types.varinfo list
  | LeaveScope of Node.t * Cil_types.varinfo list
  (** For call of functions without definition *)
  | CallDeclared of Node.t * Cil_types.kernel_function * Cil_types.exp list * Cil_types.lval option
  | Loop of Node.t * Stmt.t * Node.t (** start *) * edge list GraphShape.t
  | Msg of Node.t * string


(* Frama-C "datatype" for type [inout] *)
module Edge = struct

  let rec pretty fmt = function
    | Assign(n,loc,_typ,exp) -> Format.fprintf fmt "@[Assign:@ %a = %a -> %a@]"
                                  Lval.pretty loc ExpStructEq.pretty exp Node.pretty n
    | Assume(n,e,b) -> Format.fprintf fmt "@[Assume:@ %a %b -> %a@]" ExpStructEq.pretty e b Node.pretty n
    | EnterScope(n,vs) -> Format.fprintf fmt "@[EnterScope:@ %a -> %a@]"
                            (Pretty_utils.pp_list ~sep:"@ " Varinfo.pretty) vs Node.pretty n
    | LeaveScope(n,vs) -> Format.fprintf fmt "@[LeaveScope:@ %a -> %a@]"
                            (Pretty_utils.pp_list ~sep:"@ " Varinfo.pretty) vs Node.pretty n
    | CallDeclared(n,kf1,exp1,lval1) ->
      Format.fprintf fmt "@[CallDeclared:@ %a%s(%a) -> %a@]"
        (Pretty_utils.pp_opt ~pre:"" ~suf:" =@ " Lval.pretty) lval1
        (Kernel_function.get_name kf1)
        (Pretty_utils.pp_list ~sep:",@ " ExpStructEq.pretty) exp1
        Node.pretty n
    | Msg(n,s) -> Format.fprintf fmt "@[%s -> %a@]" s Node.pretty n
    | Loop(n,stmt,s,g) -> Format.fprintf fmt "@[<hv 2>@[Loop(%a) %a@] %a @[-> %a@]@]"
                         Stmt.pretty_sid stmt
                         Node.pretty s
                         (GraphShape.pretty pretty_list) g Node.pretty n
  and pretty_list fmt l = Pretty_utils.pp_list ~sep:";@ " pretty fmt l

  include Datatype.Make_with_collections(struct
      type nonrec t = edge
      let name = "Value.Traces_domain.Edge.t"

      let reprs = [Msg(Node.of_int 0,"msg")]

      let structural_descr = Structural_descr.t_abstract

      let rec compare (m1:t) (m2:t) =
        match m1, m2 with
        | Assign (n1,loc1,typ1,exp1), Assign (n2,loc2,typ2,exp2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
            let c = Lval.compare loc1 loc2 in
            if c <> 0 then c else
              let c = Typ.compare typ1 typ2 in
              if c <> 0 then c else
                ExpStructEq.compare exp1 exp2
        | Assume(n1,e1,b1), Assume(n2,e2,b2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = ExpStructEq.compare e1 e2 in
          if c <> 0 then c else
            Pervasives.compare b1 b2
        | EnterScope(n1,vs1),EnterScope(n2,vs2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = Extlib.list_compare Varinfo.compare vs1 vs2 in
          c
        | LeaveScope(n1,vs1), LeaveScope(n2,vs2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = Extlib.list_compare Varinfo.compare vs1 vs2 in
          c
        | CallDeclared(n1,kf1,exp1,lval1), CallDeclared(n2,kf2,exp2,lval2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = Kernel_function.compare kf1 kf2 in
          if c <> 0 then c else
            let c = Extlib.list_compare ExpStructEq.compare exp1 exp2 in
            if c <> 0 then c else
              let c = Extlib.opt_compare Lval.compare lval1 lval2 in
              c
        | Msg(n1,s1), Msg(n2,s2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = String.compare s1 s2 in
          c
        | Loop(n1,stmt1,s1,g1), Loop(n2,stmt2,s2,g2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = Stmt.compare stmt1 stmt2 in
          if c <> 0 then c else
          let c = Node.compare s1 s2 in
          if c <> 0 then c else
          let c = GraphShape.compare (Extlib.list_compare compare) g1 g2 in
          if c <> 0 then c else
            0
        | Assign _, _ -> -1
        | _ , Assign _ -> 1
        | Assume _, _ -> -1
        | _ , Assume _ -> 1
        | EnterScope _, _ -> -1
        | _ , EnterScope _ -> 1
        | LeaveScope _, _ -> -1
        | _ , LeaveScope _ -> 1
        | CallDeclared _, _ -> -1
        | _ , CallDeclared _ -> 1
        | Msg _, _ -> -1
        | _, Msg _ -> 1

      let equal = Datatype.from_compare

      let pretty = pretty

      let hash = function
        | Assume(n,e,b) ->
          Hashtbl.seeded_hash (Node.hash n)
            (Hashtbl.seeded_hash (Hashtbl.hash b) (ExpStructEq.hash e))
        | Assign(n,loc,typ,exp) ->
          (Hashtbl.seeded_hash (ExpStructEq.hash exp)
             (Hashtbl.seeded_hash (Typ.hash typ)
                (Hashtbl.seeded_hash
                   (Node.hash n)
                   (Hashtbl.seeded_hash 2 (Lval.hash loc)))))
        | EnterScope(n,vs) ->
          let x = List.fold_left (fun acc e -> Hashtbl.seeded_hash acc (Varinfo.hash e)) 3 vs in
          Hashtbl.seeded_hash (Node.hash n) x
        | LeaveScope(n,vs) ->
          let x = List.fold_left (fun acc e -> Hashtbl.seeded_hash acc (Varinfo.hash e)) 4 vs in
          Hashtbl.seeded_hash (Node.hash n) x
        | CallDeclared(n,kf,exps,lval) ->
          let x = Kernel_function.hash kf in
          let x = Hashtbl.seeded_hash x (Extlib.opt_hash Lval.hash lval) in
          let x = List.fold_left (fun acc e -> Hashtbl.seeded_hash acc (ExpStructEq.hash e)) x exps in
          Hashtbl.seeded_hash (Node.hash n) x
        | Msg(n,s) -> Hashtbl.seeded_hash (Node.hash n) (Hashtbl.seeded_hash 5 s)
        | Loop(n,stmt,s,g) ->
          Hashtbl.seeded_hash (Stmt.hash stmt)
            (Hashtbl.seeded_hash (GraphShape.hash g) (Hashtbl.seeded_hash (Node.hash n) (Node.hash s)))

      let rehash = Datatype.Serializable_undefined.rehash
      let varname = Datatype.Serializable_undefined.varname
      let mem_project = Datatype.Serializable_undefined.mem_project
      let internal_pretty_code = Datatype.Serializable_undefined.internal_pretty_code

      let copy c = c

    end)
end

module EdgeList = struct
  include Datatype.List_with_collections(Edge)(struct let module_name = "Traces_domain.EdgeList" end)
  let pretty = Edge.pretty_list
  let pretty_debug = pretty
end

module Graph =
  Hptmap.Make(Node)(EdgeList)
    (Hptmap.Comp_unused)(struct let v = [[]] end)
    (struct let l = [Ast.self] end)

type loops =
  | Base of Node.t * Graph.t (* current last *)
  | OpenLoop of Cil_types.stmt * Node.t (* start node *) * Graph.t (* last iteration *) * Node.t (** current *) * Graph.t * loops
  | UnrollLoop of Cil_types.stmt * loops

type state = { start : Node.t; current : loops;
               call_declared_function: bool;
               globals : Cil_types.varinfo list;
               main_formals : Cil_types.varinfo list;
               (** kind of memoization of the edges *)
               all_edges_ever_created : Graph.t ref;
               all_loop_start : (Node.t * Graph.t) Stmt.Hashtbl.t;
             }

(* Lattice structure for the abstract state above *)
module Traces = struct

  (** impossible for normal values start must be bigger than current *)
  let new_empty () = { start = Node.of_int 0; current = Base (Node.of_int 0, Graph.empty);
                       call_declared_function = false;
                       globals = []; main_formals = [];
                       all_edges_ever_created = ref Graph.empty;
                       all_loop_start = Stmt.Hashtbl.create 10;
                     }
  let empty = new_empty ()
  let top = { (new_empty ()) with current = Base (Node.of_int (-1), Graph.empty); }

  let rec compare_loops l1 l2 =
    match l1,l2 with
    | Base (c1,g1), Base (c2,g2) ->
      let c = Node.compare c1 c2 in
      if c <> 0 then c else
        Graph.compare g1 g2
    | OpenLoop(stmt1,s1, last1, c1, g1, l1), OpenLoop(stmt2,s2, last2, c2, g2, l2) ->
      let c = Stmt.compare stmt1 stmt2 in
      if c <> 0 then c else
        let c = Node.compare s1 s2 in
        if c <> 0 then c else
          let c = Graph.compare last1 last2 in
          if c <> 0 then c else
            let c = Node.compare c1 c2 in
            if c <> 0 then c else
              let c = Graph.compare g1 g2 in
              if c <> 0 then c else
                compare_loops l1 l2
    | UnrollLoop(stmt1,l1), UnrollLoop(stmt2,l2) ->
      let c = Stmt.compare stmt1 stmt2 in
      if c <> 0 then c else
        compare_loops l1 l2
    | Base _, _ -> -1
    | _, Base _ -> 1
    | OpenLoop _, _ -> -1
    | _, OpenLoop _ -> 1

  let rec pretty_loops fmt = function
    | Base (c,g) ->
      Format.fprintf fmt "@[<hv>%a @[at %a@]@]"
        Graph.pretty g Node.pretty c
    | OpenLoop(stmt,s,last,c,g,l) ->
      Format.fprintf fmt "@[<hv 1>@[loop(%a) %a@]@ @[<hv 1>@[last:@]@ %a@]@  @[<hv 1>@[c:@]@ %a@]@ @[at %a@]@]@ %a"
        Stmt.pretty_sid stmt
        Node.pretty s Graph.pretty last Graph.pretty g Node.pretty c pretty_loops l
    | UnrollLoop(stmt,l) ->
      Format.fprintf fmt "@[<hv>@[unroll(%a)@]@ %a"
        Stmt.pretty_sid stmt
        pretty_loops l

  (* Frama-C "datatype" for type [inout] *)
  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type t = state
      let name = "Value.Traces_domain.Traces.state"

      let reprs = [empty]

      let structural_descr = Structural_descr.t_record
          [| Descr.pack Datatype.Int.descr;
             Descr.pack Datatype.Int.descr;
             Descr.pack Graph.descr;
             Descr.pack Datatype.Bool.descr;
             Structural_descr.pack Structural_descr.t_abstract;
             Structural_descr.pack Structural_descr.t_abstract;
          |]

      let compare m1 m2 =
        let c = Node.compare m1.start m2.start in
        if c <> 0 then c else
          let c = compare_loops m1.current m2.current in
          if c <> 0 then c else
              let c = Datatype.Bool.compare m1.call_declared_function m2.call_declared_function in
              if c <> 0 then c else
                  0

      let equal = Datatype.from_compare

      let pretty fmt m =
        if m == top then Format.fprintf fmt "TOP"
        else
          Format.fprintf fmt "@[<hv>@[@[start: %a;@]@ @[globals = %a;@]@ @[main_formals = %a;@]@]@ %a@]"
            Node.pretty m.start
            (Pretty_utils.pp_list ~sep:",@ " Varinfo.pretty) m.globals
            (Pretty_utils.pp_list ~sep:",@ " Varinfo.pretty) m.main_formals
            pretty_loops m.current

      let rec hash_loops = function
        | Base (c,g) -> Hashtbl.seeded_hash (Hashtbl.seeded_hash 1 (Graph.hash g)) (Node.hash c)
        | OpenLoop(stmt,s,last,c,g,l) ->
          Hashtbl.seeded_hash 2
            (Stmt.hash stmt, Node.hash s, Graph.hash last, Node.hash c, Graph.hash g, hash_loops l)
        | UnrollLoop(stmt,l) ->
          Hashtbl.seeded_hash 2
            (Stmt.hash stmt, hash_loops l)

      let hash m =
        Hashtbl.seeded_hash (Node.hash m.start) (hash_loops m.current)

      let copy c = c

    end)

  let view m =
    if m == top then `Top
    else `Other m

  let join_graph g1 g2 =
    let rec merge_edge k l1 l2 =
      match l1, l2 with
      | [], l2 -> l2
      | l1, [] -> l1
      | h1 :: t1, h2 :: t2 ->
        let c = Edge.compare h1 h2 in
        if c = 0
        then h1 :: merge_edge k t1 t2
        else if c < 0
        then h1 :: merge_edge k t1 l2
        else h2 :: merge_edge k l1 t2
    in
    Graph.join
      ~symmetric:true
      ~idempotent:true
      ~cache:Hptmap_sig.NoCache
      ~decide:merge_edge g1 g2

  let diff_graph g1 g2 =
    let rec diff_list k l1 l2 =
      match l1, l2 with
      | [], _ -> []
      | l1, [] -> l1
      | h1 :: t1, h2 :: t2 ->
        let c = Edge.compare h1 h2 in
        if c = 0
        then diff_list k t1 t2
        else if c < 0
        then h1 :: diff_list k t1 l2
        else diff_list k l1 t2
    in
    Graph.merge ~cache:NoCache
      ~symmetric:false
      ~idempotent:false
      ~decide_both:(fun k l1 l2 -> match diff_list k l1 l2 with [] -> None | l -> Some l)
      ~decide_left:Neutral
      ~decide_right:Absorbing
      g1 g2

  let get_node = function
      | Assign (n,_,_,_)
      | Assume (n,_,_)
      | EnterScope (n,_)
      | LeaveScope (n,_)
      | CallDeclared (n,_,_,_)
      | Msg (n,_)
      | Loop(n,_,_,_) -> n

  let move_to c g state =
    let rec aux = function
      | Base (_,_) -> Base (c,g)
      | OpenLoop(stmt,s,last,_,_,l) ->
        OpenLoop(stmt,s,last,c,g,l)
      | UnrollLoop(stmt,l) ->
        UnrollLoop(stmt,aux l)
    in
    let current = aux state.current in
    {state with current}

  let replace_to c state =
    let rec aux = function
      | Base (_,g) -> Base (c,g)
      | OpenLoop(stmt,s,last,_,g,l) ->
        OpenLoop(stmt,s,last,c,g,l)
      | UnrollLoop(stmt,l) -> UnrollLoop(stmt,aux l) in
    let current = aux state.current in
    {state with current}

  let get_current state =
    let rec aux = function
    | Base (c,g) -> (c,g)
    | OpenLoop(_,_,_,c,g,_) -> (c,g)
    | UnrollLoop(_,l) ->
      aux l in
    aux state.current

  let find_succs current g =
    match Graph.find current g with
    | exception Not_found -> []
    | l -> l

  let change_next n = function
    | Assign (_,loc,typ,exp) -> Assign(n,loc,typ,exp)
    | Assume (_,a,b) -> Assume(n,a,b)
    | EnterScope (_,vs) -> EnterScope(n,vs)
    | LeaveScope (_,vs) -> LeaveScope(n,vs)
    | CallDeclared (_,kf,exps,lval) -> CallDeclared(n,kf,exps,lval)
    | Msg (_,s) -> Msg(n,s)
    | Loop(_,stmt,s,g) -> Loop(n,stmt,s,g)

  let same_edge edge edge' =
    match edge, edge' with
    | Assign (_,loc1,typ1,exp1), Assign (_,loc2,typ2,exp2) ->
      let c = Lval.compare loc1 loc2 in
      if c <> 0 then false else
        let c = Typ.compare typ1 typ2 in
        if c <> 0 then false else
          ExpStructEq.compare exp1 exp2 = 0
    | Assume(_,e1,b1), Assume(_,e2,b2) ->
      let c = ExpStructEq.compare e1 e2 in
      if c <> 0 then false else
        Pervasives.compare b1 b2 = 0
    | EnterScope(_,vs1),EnterScope(_,vs2) ->
      let c = Extlib.list_compare Varinfo.compare vs1 vs2 in
      c = 0
    | LeaveScope(_,vs1), LeaveScope(_,vs2) ->
      let c = Extlib.list_compare Varinfo.compare vs1 vs2 in
      c = 0
    | CallDeclared(_,kf1,exp1,lval1), CallDeclared(_,kf2,exp2,lval2) ->
      let c = Kernel_function.compare kf1 kf2 in
      if c <> 0 then false else
        let c = Extlib.list_compare ExpStructEq.compare exp1 exp2 in
        if c <> 0 then false else
          let c = Extlib.opt_compare Lval.compare lval1 lval2 in
          c = 0
    | Msg(_,s1), Msg(_,s2) ->
      let c = String.compare s1 s2 in
      c = 0
    | Loop(_,stmt1,s1,g1), Loop(_,stmt2,s2,g2) ->
      Stmt.equal stmt1 stmt2 &&
      Node.equal s1 s2 && GraphShape.equal g1 g2
    | _ -> false

  let create_edge all_edges_ever_created current e =
    let m = Graph.singleton current [e] in
    let old = !all_edges_ever_created in
    let new_ = join_graph old m in
    (* if not (Graph.equal old new_) then *)
    (*   Format.printf "@[<hv>@[create_edge: %a ->@]@ %a@]@." *)
    (*     Node.pretty current Edge.pretty e; *)
    all_edges_ever_created := new_;
    m

  let add_edge_aux c edge =
    let (current,graph) = get_current c in
    let reusable =
      let succs = find_succs current !(c.all_edges_ever_created) in
      List.find_opt (same_edge edge) succs
    in
    let (n,e) = match reusable with
      | Some e ->
        (** reuse an edge from last *)
        let n = get_node e in
        (n,e)
    | None ->
      (** create a new edge *)
      let n = Node.next () in
      let e = change_next n edge in
      (n,e)
    in
    let m = create_edge c.all_edges_ever_created current e in
    let graph = join_graph m graph in
    move_to n graph c

  let add_edge c e =
    if c == top then c
    else if c.call_declared_function then c (** forget intermediary state *)
    else
      let c = if c == empty then new_empty () else c in
      add_edge_aux c e

  let copy_edges s old_current_node g state =
    let cache = Node.Hashtbl.create 10 in
    let rec aux old_current_node state =
      let current_node = (fst (get_current state)) in
      let succs = find_succs old_current_node g in
      let fold state e =
        let next_old = get_node e in
        let state = match Node.Hashtbl.find cache next_old with
        | exception Not_found ->
          let state = add_edge state e in
          Node.Hashtbl.add cache next_old (fst (get_current state));
          let state = aux next_old state in
          replace_to current_node state
        | next ->
          let (_,g) = get_current state in
          let e = change_next next e in
          let m = create_edge state.all_edges_ever_created current_node e in
          let g = join_graph m g in
          move_to next g state
        in
        replace_to current_node state
      in
      List.fold_left fold state succs
    in
    let state = aux s state in
    let c = Node.Hashtbl.find cache old_current_node in
    replace_to c state

  let rec epsilon_path current stop g =
    Node.equal current stop ||
    begin
      Node.compare current stop <= 0 &&
      match Graph.find current g with
      | exception Not_found -> false
      | l ->
        let exists = function
          | Msg (n,_) -> epsilon_path n stop g
          | _ -> false
        in
        List.exists exists l
    end


  let is_included_graph g1 g2 =
    (* The graph is c1.graph is included into c2.graph *)
    let rec decide_both k l1 l2 =
      match l1, l2 with
      | [], _ -> true
      | _, [] -> false
      | h1 :: t1, h2 :: t2 ->
        let c = Edge.compare h1 h2 in
        if c = 0
        then decide_both k t1 t2
        else if c < 0
        then false
        else decide_both k l1 t2
    in
    Graph.binary_predicate
      Hptmap_sig.NoCache
      Graph.UniversalPredicate
      ~decide_fast:Graph.decide_fast_inclusion
      ~decide_fst:(fun _ _ -> false)
      ~decide_snd:(fun _ _ -> true)
      ~decide_both
      g1 g2

  let rec is_included_loops l1 l2 =
    match l1, l2 with
    | Base _, (OpenLoop _ | UnrollLoop _) | (OpenLoop _ | UnrollLoop _), Base _ ->
      (* not in the same number of loops *)
      false
    | Base (c1,_), Base (c2,g2) ->
      epsilon_path c1 c2 g2
    | (OpenLoop(stmt1,_,_,_,_,_) | UnrollLoop(stmt1,_)),
      (OpenLoop(stmt2,_,_,_,_,_) | UnrollLoop(stmt2,_)) when not (Stmt.equal stmt1 stmt2) ->
      (* not same loop *)
      false
    | OpenLoop(_,s1,_,_,_,_), OpenLoop(_,s2,_,_,_,_) when not (Node.equal s1 s2) ->
      (* not entered in the loop at the same time, take arbitrarily one of them *)
      false
    | OpenLoop(_,_,last1,c1,g1,l1), OpenLoop(_,_,last2,c2,g2,l2) ->
      let g2' = join_graph last2 g2 in
      is_included_loops l1 l2 &&
      is_included_graph last1 last2 &&
      is_included_graph g1 g2' &&
      epsilon_path c1 c2 g2'
    | UnrollLoop(_,l1), UnrollLoop(_,l2) ->
      is_included_loops l1 l2
    | OpenLoop(_,_,_,_,_,_), UnrollLoop(_,_) ->
      false
    | UnrollLoop(_,l1), OpenLoop(_,_,_,_,_,l2) ->
      is_included_loops l1 l2

  let is_included c1 c2 =
    (* start is the same *)
    let r =
      c1.start = c2.start &&
      is_included_loops c1.current c2.current in
    if not r && compare c1 c2 = 0 then
      Printf.printf "bad is_included@.";
    r

  let not_same_origin c1 c2 =
    c1.start != c2.start ||
    c1.globals != c2.globals ||
    c1.main_formals != c2.main_formals ||
    c1.all_edges_ever_created != c2.all_edges_ever_created

  let join_path ~all_edges_ever_created graph c1 c2 =
    if epsilon_path c1 c2 graph
    then (c2, graph)
    else if epsilon_path c2 c1 graph
    then (c1, graph)
    else
      let m = Msg(Node.dumb,"join") in
      let reusable =
        let succs1 = find_succs c1 !all_edges_ever_created in
        let succs1 = List.filter (same_edge m) succs1 in
        let succs2 = find_succs c2 !all_edges_ever_created in
        let find s1 = List.exists (Edge.equal s1) succs2 in
        List.find_opt find succs1
      in
      let (n,m) = match reusable with
        | None ->
          let n = Node.next () in
          let m = change_next n m in
          (n,m)
        | Some m ->
          (** reuse an edge from last *)
          let n = get_node m in
          (n,m)
      in
      let m1 = create_edge all_edges_ever_created c1 m in
      let m2 = create_edge all_edges_ever_created c2 m in
      let g = join_graph (join_graph m1 graph) m2 in
      ( n, g)

  let rec join_loops ~all_edges_ever_created l1 l2 =
    match l1, l2 with
    | Base _, (OpenLoop _ | UnrollLoop _) | (OpenLoop _ | UnrollLoop _), Base _ ->
      (* not in the same number of loops *)
      `Top
    | Base (c1,g1), Base (c2,g2) ->
      let g = join_graph g1 g2 in
      let (n,g) = join_path ~all_edges_ever_created g c1 c2 in
      `Value( Base (n, g))
    | (OpenLoop(stmt1,_,_,_,_,_) | UnrollLoop(stmt1,_)),
      (OpenLoop(stmt2,_,_,_,_,_) | UnrollLoop(stmt2,_)) when not (Stmt.equal stmt1 stmt2) ->
      (* not same loop *)
      `Top
    | OpenLoop(stmt1,s1,last1,c1,g1,l1), OpenLoop(_,s2,_,_,_,l2) when not (Node.equal s1 s2) ->
      (* not entered in the loop at the same time, take arbitrarily one of them *)
      begin match join_loops ~all_edges_ever_created l1 l2 with
        | `Top -> `Top
        | `Value(l) -> `Value(OpenLoop(stmt1,s1,last1,c1,g1,l))
      end
    | OpenLoop(stmt,s,last1,c1,g1,l1), OpenLoop(_,_,last2,c2,g2,l2) ->
      begin match join_loops ~all_edges_ever_created l1 l2 with
        | `Top -> `Top
        | `Value(l) ->
          let last = join_graph last1 last2 in
          let g = join_graph g1 g2 in
          let (n,g) = join_path ~all_edges_ever_created g c1 c2 in
          `Value(OpenLoop(stmt,s,last,n,g,l))
      end
    | UnrollLoop(stmt,l1), UnrollLoop(_,l2) ->
      begin match join_loops ~all_edges_ever_created l1 l2 with
        | `Top -> `Top
        | `Value l -> `Value (UnrollLoop(stmt,l))
      end
    | (OpenLoop(stmt,s,last,c,g,l1), UnrollLoop(_,l2))
    | (UnrollLoop(_,l2), OpenLoop(stmt,s,last,c,g,l1)) ->
      begin match join_loops ~all_edges_ever_created l1 l2 with
        | `Top -> `Top
        | `Value l -> `Value (OpenLoop(stmt,s,last,c,g,l))
      end

  let join c1 c2 =
    if c1.call_declared_function <> c2.call_declared_function
    then
      Value_parameters.fatal "@[<hv>@[At the same time inside and outside a function call:@]@ %a@ %a@]"
        pretty c1 pretty c2
    else
      match view c1, view c2 with
      | `Top, _ -> c1
      | _, `Top -> c2
      | `Other c1, `Other c2 when is_included c1 c2 -> c2
      | `Other c1, `Other c2 when is_included c2 c1 -> c1
      | `Other c1, `Other c2 ->
        if not_same_origin c1 c2 then assert false
        else
          let all_edges_ever_created = c1.all_edges_ever_created in
          match join_loops ~all_edges_ever_created c1.current c2.current with
          | `Top -> top
          | `Value(current) -> {c1 with current}

  let add_loop stmt state =
    let (n,g) = get_current state in
    let succs = find_succs n g in
    let same_loop = function
        | Loop(_,stmt',s,last) when Stmt.equal stmt' stmt ->
          Some (s,last)
        | _ -> None in
    let s,last = match Extlib.find_opt same_loop succs with
      | (s,last) -> s,(Graph.from_shape (fun _ v -> v) last)
      | exception Not_found ->
        Stmt.Hashtbl.memo state.all_loop_start stmt (fun _ -> Node.next (),Graph.empty)
    in
    let current = OpenLoop(stmt,s,last,s,Graph.empty,state.current) in
    { state with current }


  let rec diff_loops l1 l2 =
    match l1, l2 with
    | Base _, (OpenLoop _ | UnrollLoop _) | (OpenLoop _ | UnrollLoop _), Base _ ->
      (* not in the same number of loops *)
      `Bottom
    | Base (c1,g1), Base (_,g2) ->
      let g = diff_graph g1 g2 in
     `Value (Base (c1, g))
    | (OpenLoop(stmt1,_,_,_,_,_) | UnrollLoop(stmt1,_)),
      (OpenLoop(stmt2,_,_,_,_,_) | UnrollLoop(stmt2,_)) when not (Stmt.equal stmt1 stmt2) ->
      (* not same loop *)
      `Bottom
    | OpenLoop(stmt1,s1,last1,c1,g1,l1), OpenLoop(_,s2,_,_,_,l2) when not (Node.equal s1 s2) ->
      (* not entered in the loop at the same time, take arbitrarily one of them *)
      begin match diff_loops l1 l2 with
        | `Bottom -> `Bottom
        | `Value(l) -> `Value(OpenLoop(stmt1,s1,last1,c1,g1,l))
      end
    | OpenLoop(stmt,s,last1,c1,g1,l1), OpenLoop(_,_,last2,_,g2,l2) ->
      begin match diff_loops l1 l2 with
        | `Bottom -> `Bottom
        | `Value(l) ->
          let last = diff_graph last1 last2 in
          let g = diff_graph g1 g2 in
          `Value(OpenLoop(stmt,s,last,c1,g,l))
      end
    | UnrollLoop(stmt,l1), UnrollLoop(_,l2) ->
      begin match diff_loops l1 l2 with
        | `Bottom -> `Bottom
        | `Value l -> `Value (UnrollLoop(stmt,l))
      end
    | (OpenLoop(stmt,s,last,c,g,l1), UnrollLoop(_,l2)) ->
      begin match diff_loops l1 l2 with
        | `Bottom -> `Bottom
        | `Value l -> `Value (OpenLoop(stmt,s,last,c,g,l))
      end
    | (UnrollLoop(stmt,l2), OpenLoop(_,_,_,_,_,l1)) ->
      begin match diff_loops l1 l2 with
        | `Bottom -> `Bottom
        | `Value l -> `Value (UnrollLoop(stmt,l))
      end


  let widen _ stmt' c1 c2 =
    if false then
      begin
        if compare_loops c1.current c2.current = 0
        then
          Format.printf "@[<hv 2>@[widen %a: same loops, states are%s equal @]@]@."
            Stmt.pretty_sid stmt' (if compare c1 c2 = 0 then "" else " not")
        else
          let c1' = diff_loops c1.current c2.current in
          let c2' = diff_loops c2.current c1.current in
          if (Bottom.compare compare_loops) c1' c2' = 0 then
            Format.printf "@[<hv 2>@[widen %a diff equal:@]@ @[<hv 1>@[c1:@]@ %a@]@ @[<hv 1>@[c2:@]@ %a@]@]@."
              Stmt.pretty_sid stmt'
              pretty_loops c1.current
              pretty_loops c2.current

          else
            Format.printf "@[<hv 2>@[widen %a diff different:@]@ @[<hv 1>@[c1':@]@ %a@]@ @[<hv 1>@[c2':@]@ %a@]@]@."
              Stmt.pretty_sid stmt'
              (Bottom.pretty pretty_loops) c1'
              (Bottom.pretty pretty_loops) c2'
      end;
    if false then
      begin
        if compare_loops c1.current c2.current = 0
        then
          Format.printf "@[<hv 2>@[widen %a: same loops, states are%s equal @]@]@."
            Stmt.pretty_sid stmt' (if compare c1 c2 = 0 then "" else " not")
        else
            Format.printf "@[<hv 2>@[widen %a@]@]@." Stmt.pretty_sid stmt'
      end;
    if not (Value_parameters.TracesUnrollLoop.get ())
    then c2
    else begin
      match c2.current with
      | Base _ -> assert false (** must be in a loop *)
      | OpenLoop(stmt,_,_,_,_,_) ->
        assert (Stmt.equal stmt' stmt);
        c2
      | UnrollLoop(stmt,l) ->
        assert (Stmt.equal stmt' stmt);
        add_loop stmt' {c2 with current = l}
    end


  let narrow _c1 c2 = `Value c2
end


module GraphDot = OCamlGraph.Graphviz.Dot(struct
    module V = struct type t = {node : Node.t; loops : Node.t list} end
    module E = struct
      open V
      type t =
        | Usual of Node.t * Edge.t * Node.t list
        | Head of Node.t * Node.t list * Node.t * Node.t list
      let src = function
        | Usual (src,_,loops) -> {node=src;loops}
        | Head (src,loops,_,_) -> {node=src;loops}
      let dst = function
        | Usual (_,edge,loops) -> {node=Traces.get_node edge;loops}
        | Head (_,_,s,loops) -> {node=s;loops}
    end
    open V
    open E
    type t = Graph.t
    let iter_vertex f g =
      let rec iter_edge k (l: Node.t list) = function
        | Loop(_,_,_,g) -> iter_vertex (k::l) g
        | _ -> ()
      and iter_vertex l g =
        GraphShape.iter (fun k e -> f {node=k;loops=l}; List.iter (iter_edge k l) e) g
      in
      iter_vertex [] (Graph.shape g)
    let iter_edges_e f g =
      let rec iter_edge k l e =
        f (Usual(k,e,l));
        match e with
        | Loop(_,_,s,g) ->
          let l' = (k::l) in
          f (Head(k,l,s,l'));
          iter_vertex l' g
        | _ -> ()
      and iter_vertex l g =
        GraphShape.iter (fun k e -> List.iter (iter_edge k l) e) g
      in
      iter_vertex [] (Graph.shape g)

    let graph_attributes _ = []
    let default_vertex_attributes :
      t -> OCamlGraph.Graphviz.DotAttributes.vertex list = fun _ -> []
    let subgraph_name loops =
      Format.asprintf "S%a"
        (fun fmt -> List.iter (fun s -> Format.fprintf fmt "L%a" Node.pretty s))
        loops
    let vertex_name v = Format.asprintf "n%a%s" Node.pretty v.node
        (subgraph_name v.loops)
    let vertex_attributes :
      V.t -> OCamlGraph.Graphviz.DotAttributes.vertex list =
      fun n -> [`Label (Format.asprintf "%a" Node.pretty n.node)]
    let get_subgraph v =
      match v.loops with
      | [] -> None
      | _::l -> Some
                  {OCamlGraph.Graphviz.DotAttributes.sg_name = subgraph_name v.loops;
                   sg_attributes = [];
                   sg_parent = if l = [] then None else Some (subgraph_name l); }
    let default_edge_attributes :
      t -> OCamlGraph.Graphviz.DotAttributes.edge list = fun _ -> []
    let edge_attributes : E.t -> OCamlGraph.Graphviz.DotAttributes.edge list =
      function
      | Usual(_,Loop _,_) -> [`Label (Format.asprintf "leave_loop")]
      | Usual(_,e,_) -> [`Label (Format.asprintf "%a" Edge.pretty e)]
      | Head _ -> []
end)

let key = Structure.Key_Domain.create_key "traces domain"

module Internal = struct
  type nonrec state = state
  type value = Cvalue.V.t
  type location = Precise_locs.precise_location

  include (Traces: sig
             include Datatype.S_with_collections with type t = state
             include Abstract_domain.Lattice with type state := state
           end)

  let structure : t Abstract_domain.structure = Abstract_domain.Leaf key
  let log_category = Value_parameters.register_category "d-traces"

  type origin = unit

  module Transfer (Valuation: Abstract_domain.Valuation
                   with type value = value
                    and type origin = origin
                    and type loc = Precise_locs.precise_location)
    : Abstract_domain.Transfer
      with type state = state
       and type value = Cvalue.V.t
       and type location = Precise_locs.precise_location
       and type valuation = Valuation.t
  = struct
    type value = Cvalue.V.t
    type state = t
    type location = Precise_locs.precise_location
    type valuation = Valuation.t

    let assign _ki lv e _v _valuation state =
      `Value(Traces.add_edge state (Assign(Node.dumb,lv.Eval.lval,lv.Eval.ltyp,e)))

    let assume _stmt e pos _valuation state =
      `Value(Traces.add_edge state (Assume(Node.dumb,e,pos)))

    let start_call _stmt call _valuation state =
      if Kernel_function.is_definition call.Eval.kf
      then
        let msg = Format.asprintf "start_call: %s (%b)" (Kernel_function.get_name call.Eval.kf)
            (Kernel_function.is_definition call.Eval.kf) in
        let state = Traces.add_edge state (Msg(Node.dumb,msg)) in
        let formals = List.map (fun arg -> arg.Eval.formal) call.Eval.arguments in
        let state = Traces.add_edge state (EnterScope(Node.dumb,formals)) in
        let state = List.fold_left (fun state arg ->
            Traces.add_edge state (Assign(Node.dumb,
                                          Cil.var arg.Eval.formal,
                                          arg.Eval.formal.Cil_types.vtype,
                                          arg.Eval.concrete))) state call.Eval.arguments in
        `Value state
      else
        (** enter the scope of the dumb result variable *)
        let var = call.Eval.return in
        let state = match var with
          | Some var -> Traces.add_edge state (EnterScope(Node.dumb,[var]))
          | None -> state in
        let exps = List.map (fun arg -> arg.Eval.concrete) call.Eval.arguments in
        let state = Traces.add_edge state (CallDeclared(Node.dumb, call.Eval.kf, exps,
                                                        Extlib.opt_map Cil.var var)) in
        `Value {state with call_declared_function = true}

    let finalize_call _stmt call ~pre:_ ~post =
      if post.call_declared_function
      then `Value {post with call_declared_function = false}
      else
        let msg = Format.asprintf "finalize_call: %s" (Kernel_function.get_name call.Eval.kf) in
        let state = Traces.add_edge post (Msg(Node.dumb,msg)) in
        `Value state

    let update _valuation state = `Value state

    let show_expr _valuation state fmt _expr = Traces.pretty fmt state
  end

  (* Memexec *)
  (* This domains infers no relation between variables. *)
  let relate _kf _bases _state = Base.SetLattice.bottom
  (* Do not filter the state: the memexec cache will be applied only on function
     calls for which the entry states are equal. This almost completely
     disable memexec, but is always sound. *)
  let filter _kf _kind _bases state = state
  (* As memexec cache is only applied on equal entry states, the previous
     output state is a correct output for the current input state. *)
  let reuse _kf _bases ~current_input:_ ~previous_output:state = state

  let empty () = Traces.empty
  let introduce_globals vars state =
    {state with globals = vars @ state.globals}
  let initialize_variable lv _ ~initialized:_ _ state =
    Traces.add_edge state (Msg(Node.dumb,Format.asprintf "initialize variable: %a" Printer.pp_lval lv ))
  let initialize_variable_using_type init_kind varinfo state =
    let state =
      match init_kind with
      | Abstract_domain.Main_Formal -> {state with main_formals = varinfo::state.main_formals}
      | _ -> state
    in
    let msg = Format.asprintf "initialize@ variable@ using@ type@ %a@ %a"
        (fun fmt init_kind ->
           match init_kind with
           | Abstract_domain.Main_Formal -> Format.pp_print_string fmt "Main_Formal"
           | Abstract_domain.Library_Global -> Format.pp_print_string fmt "Library_Global"
           | Abstract_domain.Spec_Return kf -> Format.fprintf fmt "Spec_Return(%s)" (Kernel_function.get_name kf))
        init_kind
        Varinfo.pretty varinfo
    in
    Traces.add_edge state (Msg(Node.dumb,msg))

  (* TODO *)
  let logic_assign _assign _location ~pre:_ state =
    Traces.add_edge state (Msg(Node.dumb,"logic assign"))

  (* Logic *)
  let evaluate_predicate _ _ _ = Alarmset.Unknown
  let reduce_by_predicate _ state _ _ = `Value state

  let storage () = true

  let top_query = `Value (Cvalue.V.top, ()), Alarmset.all

  let extract_expr _oracle _state _expr = top_query
  let extract_lval _oracle _state _lv _typ _locs = top_query

  let backward_location _state _lval _typ loc value =
    `Value (loc, value)

  let enter_loop stmt state =
    let state = Traces.add_edge state (Msg(Node.dumb,"enter_loop")) in
    let state = if not (Value_parameters.TracesUnrollLoop.get ())
      then Traces.add_loop stmt state
      else { state with current = UnrollLoop(stmt,state.current) } in
    state

  let incr_loop_counter _ state =
    match state.current with
    | Base _ -> assert false
    | UnrollLoop(_,_) -> state
    | OpenLoop(stmt,s,last,_,g,l) ->
      let last = Traces.join_graph last g in
      let last = if Value_parameters.TracesUnifyLoop.get () then
        let s',old_last = Stmt.Hashtbl.find state.all_loop_start stmt in
        let last = Traces.join_graph last old_last in
        assert (Node.equal s s');
        Stmt.Hashtbl.add state.all_loop_start stmt (s,last);
        last
      else last
      in
      let current = OpenLoop(stmt,s,last,s,Graph.empty,l) in
      let state = { state with current } in
      (* Traces.add_edge state (Msg(Node.dumb,"incr_loop_counter")) *)
      state

  let leave_loop stmt' state =
    match state.current with
    | Base _ -> assert false (* absurd: we are in at least a loop *)
    | UnrollLoop(_,l) -> { state with current = l }
    | OpenLoop(stmt,s,last,old_current_node,g,current) ->
      assert (Stmt.equal stmt stmt');
      let state = { state with current } in
      let last = if Value_parameters.TracesUnifyLoop.get () then
          let s',old_last = Stmt.Hashtbl.find state.all_loop_start stmt in
          let last = Traces.join_graph last old_last in
          assert (Node.equal s s');
          Stmt.Hashtbl.add state.all_loop_start stmt (s,last);
          last
        else last
      in
      let state = if Graph.is_empty last then state
        else Traces.add_edge state (Loop(Node.dumb,stmt,s,Graph.shape last)) in
      let state = Traces.copy_edges s old_current_node g state in
      Traces.add_edge state (Msg(Node.dumb,"leave_loop"))


  let enter_scope _kf vars state = Traces.add_edge state (EnterScope(Node.dumb,vars))
  let leave_scope _kf vars state = Traces.add_edge state (LeaveScope(Node.dumb,vars))

  let reduce_further _state _expr _value = [] (*Nothing intelligent to suggest*)

end

module D = Domain_builder.Complete (Internal)

let dummy_loc = Location.unknown

let subst_in_full var_mapping =
  let visit = Cil.copy_visit (Project.current ()) in
  visit, object
  inherit Cil.genericCilVisitor (visit)
  method! vvrbl vi =
    match Varinfo.Map.find vi var_mapping with
    | exception Not_found -> Cil.DoChildren
    | v -> Cil.ChangeTo v
  method! vlogic_var_use lv =
    match lv.Cil_types.lv_origin with
    | None -> Cil.DoChildren
    | Some vi ->
      match Varinfo.Map.find vi var_mapping with
      | exception Not_found -> Cil.DoChildren
      | v -> Cil.ChangeTo (Cil.cvar_to_lvar v)
end

let subst_in var_mapping = (snd (subst_in_full var_mapping))

let sanitize_name s =
  String.map
    (fun c ->
       if
         ('0' <= c && c <= '9') ||
         ('a' <= c && c <= 'z') ||
         ('A' <= c && c <= 'Z')
       then c else '_') s

let subst_in_exp var_map exp = Cil.visitCilExpr (subst_in var_map) exp
let subst_in_lval var_map exp = Cil.visitCilLval (subst_in var_map) exp
let subst_in_varinfo var_map v =
  match Varinfo.Map.find v var_map with
  | exception Not_found -> v
  | v -> v

let fresh_varinfo var_map v =
  let v' = Cil.copyVarinfo v (sanitize_name v.Cil_types.vname) in
  v'.Cil_types.vdefined <- false;
  Varinfo.Map.add v v' var_map

let valid_sid = true

let rec stmts_of_cfg cfg current var_map locals return_exp acc =
  match Graph.find current cfg with
  | exception Not_found ->
    begin match return_exp with
    | None -> List.rev acc
    | Some (var,exp) ->
      let exp = subst_in_exp var_map exp in
      let return_stmt = Cil.mkStmtOneInstr ~valid_sid (Cil_types.Set(Cil.var var,exp,dummy_loc)) in
      List.rev (return_stmt::acc)
    end
  | [] -> assert false
  | [a] -> begin
      match a with

      | Assign (n,lval,_typ,exp) ->
        let exp = subst_in_exp var_map exp in
        let lval = subst_in_lval var_map lval in
        let stmt = Cil.mkStmtOneInstr ~valid_sid (Cil_types.Set(lval,exp,dummy_loc)) in
        stmts_of_cfg cfg n var_map locals return_exp (stmt::acc)

      | Assume (n,exp,b) ->
        let exp = subst_in_exp var_map exp in
        let predicate = (Logic_utils.expr_to_predicate ~cast:true exp).Cil_types.ip_content in
        let predicate = if b then predicate else Logic_const.pnot predicate in
        let code_annot = Logic_const.new_code_annotation(Cil_types.AAssert([],predicate)) in
        let stmt = Cil.mkStmtOneInstr ~valid_sid (Cil_types.Code_annot(code_annot,dummy_loc)) in
        stmts_of_cfg cfg n var_map locals return_exp (stmt::acc)

      | EnterScope (n,vs) ->
        (** all our variables are assigned, not defined *)
        let var_map = List.fold_left fresh_varinfo var_map vs in
        let vs = List.map (subst_in_varinfo var_map) vs in
        locals := vs @ !locals;
        let block = { Cil_types.battrs = [];
                      bscoping = true;
                      blocals = vs;
                      bstatics = [];
                      bstmts = stmts_of_cfg cfg n var_map locals return_exp [] } in
        let stmt = Cil.mkStmt ~valid_sid (Cil_types.Block(block)) in
        List.rev (stmt::acc)

      | LeaveScope (n,_) -> stmts_of_cfg cfg n var_map locals return_exp acc

      | CallDeclared (n,kf,exps,lval) ->
        let exps = List.map (subst_in_exp var_map) exps in
        let lval = Extlib.opt_map (subst_in_lval var_map) lval in
        let call = Cil.evar ~loc:dummy_loc (subst_in_varinfo var_map (Kernel_function.get_vi kf)) in
        let stmt = Cil.mkStmtOneInstr ~valid_sid (Cil_types.Call(lval,call,exps,dummy_loc)) in
        stmts_of_cfg cfg n var_map locals return_exp (stmt::acc)

      | Msg (n,_) -> stmts_of_cfg cfg n var_map locals return_exp acc
      | Loop(n,_,s,g) ->
        let g = Graph.from_shape (fun _ v -> v) g in
        let is_while =
          match Traces.find_succs s g, Traces.find_succs n cfg with
          | [Assume(n1',exp1,b1)], [Assume(n2',exp2,b2)]
            when ExpStructEq.equal exp1 exp2 && b1 != b2 ->
            Some (exp1, n1', b1, n2')
          | _ -> None in
        match is_while with
        | None -> Value_parameters.not_yet_implemented "Traces_domain: Loop without condition"
        | Some(exp,nloop,bloop,n2) ->
          let exp = subst_in_exp var_map exp in
          let exp = if bloop then exp else Cil.new_exp ~loc:dummy_loc (UnOp(LNot,exp,Cil.intType)) in
          let body = stmts_of_cfg g nloop var_map locals None [] in
          let acc = (List.rev (Cil.mkWhile ~guard:exp ~body)) @ acc in
          stmts_of_cfg cfg n2 var_map locals return_exp acc
    end
  | l ->
    let is_if = match l with
      | [] | [_] -> assert false (* absurd *)
      | [Assume(n1',exp1,b1) ; Assume(n2',exp2,b2)]
        when ExpStructEq.equal exp1 exp2 && b1 != b2 ->
        if b1 then Some (exp1, n1', n2') else Some (exp1,n2',n1')
      | _ -> None in
    let stmt =
      match is_if with
      | None -> Value_parameters.not_yet_implemented "Traces_domain: switch at node(%a)" Node.pretty current
      | Some(exp,n1,n2) ->
        let exp = subst_in_exp var_map exp in
        let block1 = Cil.mkBlock (stmts_of_cfg cfg n1 var_map locals return_exp []) in
        let block2 = Cil.mkBlock (stmts_of_cfg cfg n2 var_map locals return_exp []) in
        Cil.mkStmt ~valid_sid (Cil_types.If(exp,block1,block2,dummy_loc)) in
    List.rev (stmt::acc)

let project_of_cfg vreturn s =
  let main = Kernel_function.get_vi (fst (Globals.entry_point ())) in

  let visit project =
    let visitor =
      object (self)
        inherit Visitor.frama_c_copy project
        method! vglob_aux global =
          match global with
          | Cil_types.GFun(fundec,_) when Varinfo.equal fundec.svar main ->
            Cil.DoChildren
          | Cil_types.GFun _ -> Cil.ChangeTo([])
          | _ -> Cil.JustCopy
        method! vfunc fundec =
          if Varinfo.equal (Cil.get_original_varinfo self#behavior fundec.Cil_types.svar) main then begin
            (** copy of the fundec structure has already been done *)
            fundec.slocals <- [];
            let var_map = Varinfo.Map.empty in
            let return_stmt, return_equal, blocals = match vreturn with
              | None -> Cil.mkStmt ~valid_sid (Cil_types.Return(None,dummy_loc)), None, []
              | Some exp ->
                let var = Cil.makeVarinfo false false "__traces_domain_return" (Cil.typeOf exp) in
                Cil.mkStmt ~valid_sid (Cil_types.Return(Some (Cil.evar var),dummy_loc)),
                Some (var,exp), [var]
            in
            let locals = ref [] in
            let graph = match s.current with | Base (_,g) -> g | _ ->
              Value_parameters.fatal "Traces.project_of_cfg used with open loops" in
            let stmts = stmts_of_cfg graph s.start var_map locals return_equal [] in
            let sbody = Cil.mkBlock (stmts@[return_stmt])  in
            sbody.Cil_types.blocals <- blocals;
            fundec.sbody <- sbody;
            fundec.slocals <- blocals @ !locals @ fundec.slocals;
            Cil.setMaxId fundec;
            let fundec = {fundec with sbody} in
            Cil.ChangeDoChildrenPost(fundec,(fun x -> x))
          end
          else
            Cil.JustCopy
      end
    in
    visitor
  in

  let _project = Frama_c_File.create_project_from_visitor "Eva.Traces_domain" visit in
  ()
  (* let selection = *)
  (*   State_selection.diff *)
  (*     State_selection.full *)
  (*     (State_selection.list_union *)
  (*        (List.map State_selection.with_dependencies *)
  (*           [Cil.Builtin_functions.self; *)
  (*            Ast.self; *)
  (*            Frama_c_File.files_pre_register_state])) *)
  (* in *)
  (* let project = Project.create_by_copy ~selection ~last:true "Eva.Traces_domain" in *)
  (* let fundecls = *)
  (*   let l = ref [] in *)
  (*   Globals.Functions.iter (fun kf -> *)
  (*       if not (Kernel_function.is_definition kf) then *)
  (*         l := (kf.Cil_types.spec, Kernel_function.get_vi kf)::!l *)
  (*     ); *)
  (*   !l in *)
  (* Project.on project (fun () -> *)

  (*     let var_map = Varinfo.Map.empty in *)
  (*     let var_map = List.fold_left fresh_varinfo var_map s.globals in *)
  (*     let var_map = List.fold_left fresh_varinfo var_map s.main_formals in *)
  (*     let fundecls, var_map = List.fold_left (fun (fundecls,var_map) (funspec,v) -> *)
  (*         let fundecl = Cil_types.GFunDecl(funspec,v,dummy_loc) in *)
  (*         let behavior,visitor = subst_in_full var_map in *)
  (*         let fundecl = Cil.visitCilGlobal visitor fundecl in *)
  (*         let v' = Cil.get_varinfo behavior v in *)
  (*         (fundecl @ fundecls), Varinfo.Map.add v v' var_map *)
  (*         (\* (fundecl :: fundecls, var_map) *\) *)
  (*       ) ([],var_map) fundecls in *)
  (*     let globals = [] in *)
  (*     (\** main function *\) *)
  (*     let var_map = fresh_varinfo var_map main in *)
  (*     let main = subst_in_varinfo var_map main in *)
  (*     let fundec = Cil.emptyFunctionFromVI main in *)
  (*     fundec.Cil_types.sformals <- List.map (subst_in_varinfo var_map) s.main_formals; *)
  (*     let stmts = Cil.mkBlock (stmts_of_cfg s.graph s.start var_map vreturn []) in *)
  (*     fundec.Cil_types.sbody <- stmts; *)
  (*     let globals = Cil_types.GFun(fundec,dummy_loc) :: globals in *)
  (*     (\* declared functions *\) *)
  (*     let globals = fundecls @ globals in *)
  (*     (\* globals *\) *)
  (*     let globals = (List.map (fun v -> Cil_types.GVarDecl(subst_in_varinfo var_map v,dummy_loc)) s.globals) @ globals in *)
  (*     let file = { Cil_types.fileName = "Traces_domain"; *)
  (*                  globals; *)
  (*                  globinit = None; *)
  (*                  globinitcalled = false; } in *)
  (*     Globals.set_entry_point (main.Cil_types.vname) false; *)
  (*     Format.printf "@[<2>@[file1:@] %a@]@." Printer.pp_file file; *)
  (*     (\* let file = Cil.visitCilFileCopy (new Cil.genericCilVisitor (Cil.refresh_visit project)) file in *\) *)
  (*     Format.printf "@[<2>@[file2:@] %a@]@." Printer.pp_file file; *)
  (*     Ast.set_file file; *)
  (*     Format.printf "@[<2>@[file3:@] %a@]@." Printer.pp_file file; *)
  (*   ) () *)

let finish_computation () =
  let return_stmt = Kernel_function.find_return (fst (Globals.entry_point ())) in
  let return_exp = match return_stmt.Cil_types.skind with
    | Cil_types.Return (oexp,_) -> oexp
    | _ -> assert false in
  let state = D.Store.get_stmt_state ~after:true return_stmt  in
  let header fmt = Format.fprintf fmt "Trace domains:" in
  let body = Bottom.pretty Traces.pretty in
  Value_parameters.printf ~dkey:Internal.log_category ~header " @[%a@]" body state;
  match state with
  | `Bottom ->
    Value_parameters.failure "The trace is Bottom can't generate code"
  | `Value state when state ==Traces.top ->
    Value_parameters.failure "The trace is TOP can't generate code"
  | `Value state ->
    if false then begin
      let out = open_out "traces_domain.dot" in
      GraphDot.output_graph out (snd (Traces.get_current state));
      close_out out;
    end;
    project_of_cfg return_exp state


(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
