2(**************************************************************************)
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

module Frama_c_File = File
open Cil_datatype

[@@@ warning "-40-42"]

module Node : sig
  include Datatype.S_with_collections
  val id: t -> int
  val of_int: int -> t
  val dumb: t
end = struct
  include Datatype.Int
  let id x = x
  let of_int x = x
  let dumb = 0
end

type edge =
  | Assign of Node.t * Cil_types.lval * Cil_types.typ * Cil_types.exp
  | Assume of Node.t * Cil_types.exp * bool
  | EnterScope of Node.t * Cil_types.varinfo list
  | LeaveScope of Node.t * Cil_types.varinfo list
  (** For call of functions without definition *)
  | CallDeclared of Node.t * Cil_types.kernel_function * Cil_types.exp list * Cil_types.lval option
  | Loop of Node.t * Node.t (** start *)
  | Msg of Node.t * string

(* Frama-C "datatype" for type [inout] *)
module Edge = struct
  module Counter = State_builder.Counter(struct let name = "Traces_domain.Edge.Counter" end)

  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type nonrec t = edge
      let name = "Value.Traces_domain.Edge.t"

      let reprs = [Msg(Node.of_int 0,"msg")]

      let structural_descr = Structural_descr.t_abstract

      let compare (m1:t) (m2:t) =
        match m1, m2 with
        | Assign (n1,loc1,typ1,exp1), Assign (n2,loc2,typ2,exp2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
            let c = Lval.compare loc1 loc2 in
            if c <> 0 then c else
              let c = Typ.compare typ1 typ2 in
              if c <> 0 then c else
                Exp.compare exp1 exp2
        | Assume(n1,e1,b1), Assume(n2,e2,b2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = Exp.compare e1 e2 in
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
            let c = Extlib.list_compare Exp.compare exp1 exp2 in
            if c <> 0 then c else
              let c = Extlib.opt_compare Lval.compare lval1 lval2 in
              c
        | Msg(n1,s1), Msg(n2,s2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = String.compare s1 s2 in
          c
        | Loop(n1,s1), Loop(n2,s2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = Node.compare s1 s2 in
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

      let pretty fmt = function
        | Assign(n,loc,_typ,exp) -> Format.fprintf fmt "@[Assign:@ %a = %a -> %a@]"
                                      Lval.pretty loc Exp.pretty exp Node.pretty n
        | Assume(n,e,b) -> Format.fprintf fmt "@[Assume:@ %a %b -> %a@]" Exp.pretty e b Node.pretty n
        | EnterScope(n,vs) -> Format.fprintf fmt "@[EnterScope:@ %a -> %a@]"
                              (Pretty_utils.pp_list ~sep:"@ " Varinfo.pretty) vs Node.pretty n
        | LeaveScope(n,vs) -> Format.fprintf fmt "@[LeaveScope:@ %a -> %a@]"
                              (Pretty_utils.pp_list ~sep:"@ " Varinfo.pretty) vs Node.pretty n
        | CallDeclared(n,kf1,exp1,lval1) ->
          Format.fprintf fmt "@[CallDeclared:@ %a%s(%a) -> %a@]"
            (Pretty_utils.pp_opt ~pre:"" ~suf:" =@ " Lval.pretty) lval1
            (Kernel_function.get_name kf1)
            (Pretty_utils.pp_list ~sep:",@ " Exp.pretty) exp1
             Node.pretty n
        | Msg(n,s) -> Format.fprintf fmt "@[%s -> %a@]" s Node.pretty n
        | Loop(n,s) -> Format.fprintf fmt "@[Loop(%a) -> %a@]"
                           Node.pretty s Node.pretty n

      let hash = function
        | Assume(n,e,b) ->
          Hashtbl.seeded_hash (Node.hash n)
            (Hashtbl.seeded_hash (Hashtbl.hash b) (Exp.hash e))
        | Assign(n,loc,typ,exp) ->
          (Hashtbl.seeded_hash (Exp.hash exp)
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
          let x = List.fold_left (fun acc e -> Hashtbl.seeded_hash acc (Exp.hash e)) x exps in
          Hashtbl.seeded_hash (Node.hash n) x
        | Msg(n,s) -> Hashtbl.seeded_hash (Node.hash n) (Hashtbl.seeded_hash 5 s)
        | Loop(n,s) ->
          Hashtbl.seeded_hash (Node.hash n) (Node.hash s)

      let copy c = c

    end)
end

module EdgeList = struct
  include Datatype.List_with_collections(Edge)(struct let module_name = "Traces_domain.EdgeList" end)
  let pretty_debug = pretty
end

module NodeList = struct
  include Datatype.List_with_collections(Node)(struct let module_name = "Traces_domain.NodeList" end)
  let pretty_debug = pretty
end

module Graph =
  Hptmap.Make(Node)(EdgeList)
    (Hptmap.Comp_unused)(struct let v = [[]] end)
    (struct let l = [Ast.self] end)

module Used =
  Hptmap.Make(Node)(NodeList)
    (Hptmap.Comp_unused)(struct let v = [[]] end)
    (struct let l = [Ast.self] end)

type loops =
  | Base of Node.t (* current last *)
  | Loop of Cil_types.stmt * Node.t (* start node *) * Used.t * Node.t (** current *) * loops

type state = { start : Node.t; graph : Graph.t;
               current : loops;
               call_declared_function: bool;
               globals : Cil_types.varinfo list;
               main_formals : Cil_types.varinfo list;
             }

(* Lattice structure for the abstract state above *)
module Traces = struct

  (** impossible for normal values start must be bigger than current *)
  let empty = { start = Node.of_int 0; current = Base (Node.of_int 0);
                graph = Graph.empty; call_declared_function = false;
                globals = []; main_formals = []}
  let top = { start = Node.of_int 0; current = Base (Node.of_int (-1));
              graph = Graph.empty; call_declared_function = false;
              globals = []; main_formals = []}

  let rec compare_loops l1 l2 =
    match l1,l2 with
    | Base c1, Base c2 -> Node.compare c1 c2
    | Loop(stmt1,s1, used1, c1, l1), Loop(stmt2,s2, used2, c2, l2) ->
      let c = Stmt.compare stmt1 stmt2 in
      if c <> 0 then c else
        let c = Node.compare s1 s2 in
        if c <> 0 then c else
          let c = Used.compare used1 used2 in
          if c <> 0 then c else
            let c = Node.compare c1 c2 in
            if c <> 0 then c else
              compare_loops l1 l2
    | Base _, _ -> -1
    | _, Base _ -> 1

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
            let c = Graph.compare m1.graph m2.graph in
            if c <> 0 then c else
              let c = Datatype.Bool.compare m1.call_declared_function m2.call_declared_function in
              if c <> 0 then c else
                  0

      let equal = Datatype.from_compare

      let rec pretty_loops fmt = function
        | Base c -> Node.pretty fmt c
        | Loop(_,s,_,c,l) ->
          Format.fprintf fmt "@[(%a,%a);@]@ %a"
            Node.pretty s Node.pretty c pretty_loops l

      let pretty fmt m =
        if m == top then Format.fprintf fmt "TOP"
        else
          Format.fprintf fmt "@[<hv>@[@[start: %a;@]@ @[globals = %a;@]@ @[main_formals = %a;@]@]@ %a@ @[<hv>@[current: @]%a@]"
            Node.pretty m.start
            (Pretty_utils.pp_list ~sep:",@ " Varinfo.pretty) m.globals
            (Pretty_utils.pp_list ~sep:",@ " Varinfo.pretty) m.main_formals
            Graph.pretty m.graph
            pretty_loops m.current

      let rec hash_loops = function
        | Base c -> Hashtbl.seeded_hash 1 (Node.hash c)
        | Loop(stmt,n,used,c,l) ->
          Hashtbl.seeded_hash 2
            (Stmt.hash stmt,Node.hash n, Used.hash used, Node.hash c, hash_loops l)

      let hash m =
        Hashtbl.seeded_hash (Node.hash m.start)
          (Hashtbl.seeded_hash (hash_loops m.current) (Graph.hash m.graph))

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

  let join_used g1 g2 =
    let rec merge_edge k l1 l2 =
      match l1, l2 with
      | [], l2 -> l2
      | l1, [] -> l1
      | h1 :: t1, h2 :: t2 ->
        let c = Node.compare h1 h2 in
        if c = 0
        then h1 :: merge_edge k t1 t2
        else if c < 0
        then h1 :: merge_edge k t1 l2
        else h2 :: merge_edge k l1 t2
    in
    Used.join
      ~symmetric:true
      ~idempotent:true
      ~cache:Hptmap_sig.NoCache
      ~decide:merge_edge g1 g2

  let get_node = function
      | Assign (n,_,_,_)
      | Assume (n,_,_)
      | EnterScope (n,_)
      | LeaveScope (n,_)
      | CallDeclared (n,_,_,_)
      | Msg (n,_)
      | Loop(n,_) -> n

  let move_to c state =
    let current = match state.current with
      | Base _ -> Base c
      | Loop(stmt,s,used,c',l) ->
        let used = join_used (Used.singleton c' [c]) used in
        Loop(stmt,s,used,c,l) in
    {state with current}

  let get_current_node state =
    match state.current with
    | Base c -> c
    | Loop(_,_,_,c,_) -> c

  let find_succs current c =
    match Graph.find current c.graph with
    | exception Not_found -> []
    | l -> l

  let change_next n = function
    | Assign (_,loc,typ,exp) -> Assign(n,loc,typ,exp)
    | Assume (_,a,b) -> Assume(n,a,b)
    | EnterScope (_,vs) -> EnterScope(n,vs)
    | LeaveScope (_,vs) -> LeaveScope(n,vs)
    | CallDeclared (_,kf,exps,lval) -> CallDeclared(n,kf,exps,lval)
    | Msg (_,s) -> Msg(n,s)
    | Loop(_,s) -> Loop(n,s)

  let add_edge c edge =
    if c == top then c
    else if c.call_declared_function then c (** forget intermediary state *)
    else
      let current = get_current_node c in
      let succs = find_succs current c in
      let same edge' =
        match edge, edge' with
        | Assign (_,loc1,typ1,exp1), Assign (_,loc2,typ2,exp2) ->
            let c = Lval.compare loc1 loc2 in
            if c <> 0 then false else
              let c = Typ.compare typ1 typ2 in
              if c <> 0 then false else
                Exp.compare exp1 exp2 = 0
        | Assume(_,e1,b1), Assume(_,e2,b2) ->
          let c = Exp.compare e1 e2 in
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
            let c = Extlib.list_compare Exp.compare exp1 exp2 in
            if c <> 0 then false else
              let c = Extlib.opt_compare Lval.compare lval1 lval2 in
              c = 0
        | Msg(_,s1), Msg(_,s2) ->
          let c = String.compare s1 s2 in
          c = 0
        | Loop(_,s1), Loop(_,s2) ->
          Node.equal s1 s2
        | _ -> false
      in
      match List.find_opt same succs with
      | Some e ->
        (** reuse an edge *)
        move_to (get_node e) c
      | None ->
        (** create a new edge *)
        let n = Node.of_int (Edge.Counter.next ()) in
        let e = change_next n edge in
        let m = Graph.singleton current [e] in
        let g = join_graph m c.graph in
        move_to n { c with graph = g }

  let rec filter_edge l1 l2 =
    match l1, l2 with
    | [], _ -> []
    | _, [] -> []
    | h1 :: t1, h2 :: t2 ->
      let c = Node.compare h1 (get_node h2) in
      if c = 0
      then h2 :: filter_edge t1 t2
      else if c < 0
      then filter_edge t1 l2
      else filter_edge l1 t2

  let copy_edges used s old_current_node state =
    let cache = Node.Hashtbl.create 10 in
    let rec aux old_current_node state =
      let u = try Used.find old_current_node used with Not_found -> [] in
      let current_node = get_current_node state in
      let succs = find_succs old_current_node state in
      let succs = filter_edge u succs in
      let fold state e =
        let next_old = get_node e in
        match Node.Hashtbl.find cache next_old with
        | exception Not_found ->
          let state = add_edge state e in
          Node.Hashtbl.add cache next_old (get_current_node state);
          let state = aux next_old state in
          move_to current_node state
        | next ->
          let e = change_next next e in
          let m = Graph.singleton current_node [e] in
          {state with graph = join_graph m state.graph}
      in
      List.fold_left fold state succs
    in
    let state = aux s state in
    let c = Node.Hashtbl.find cache old_current_node in
    let current = match state.current with
      | Base _ -> Base c
      | Loop(stmt,s,used,_,l) ->
        Loop(stmt,s,used,c,l) in
    {state with current}

  let remove_unused used s state =
    let cache = Node.Hashtbl.create 10 in
    let rec aux s state =
      if Node.Hashtbl.mem cache s then state
      else begin
        Node.Hashtbl.add cache s ();
        let succs = find_succs s state in
        let state = List.fold_left (fun state e -> aux (get_node e) state) state succs in
        let u = try Used.find s used with Not_found -> [] in
        let succs = filter_edge u succs in
        if succs = []
        then { state with graph = Graph.remove s state.graph }
        else { state with graph = Graph.add s succs state.graph }
      end
    in
    aux s state

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

  let is_included_used g1 g2 =
    (* The graph is c1.graph is included into c2.graph *)
    let rec decide_both k l1 l2 =
      match l1, l2 with
      | [], _ -> true
      | _, [] -> false
      | h1 :: t1, h2 :: t2 ->
        let c = Node.compare h1 h2 in
        if c = 0
        then decide_both k t1 t2
        else if c < 0
        then false
        else decide_both k l1 t2
    in
    Used.binary_predicate
      Hptmap_sig.NoCache
      Used.UniversalPredicate
      ~decide_fast:Used.decide_fast_inclusion
      ~decide_fst:(fun _ _ -> false)
      ~decide_snd:(fun _ _ -> true)
      ~decide_both
      g1 g2

  let rec is_included_loops l1 l2 graph =
    match l1, l2 with
    | Base _, Loop _ | Loop _, Base _ ->
      (* not in the same number of loops *)
      false
    | Base c1, Base c2 ->
      epsilon_path c1 c2 graph
    | Loop(stmt1,_,_,_,_), Loop(stmt2,_,_,_,_) when not (Stmt.equal stmt1 stmt2) ->
      (* not same loop *)
      false
    | Loop(_,s1,_,_,_), Loop(_,s2,_,_,_) when not (Node.equal s1 s2) ->
      (* not entered in the loop at the same time, take arbitrarily one of them *)
      false
    | Loop(_,_,used1,c1,l1), Loop(_,_,used2,c2,l2) ->
      is_included_loops l1 l2 graph &&
      is_included_used used1 used2 &&
      epsilon_path c1 c2 graph

  let is_included c1 c2 =
    (* start is the same *)
    c1.start = c2.start &&
    is_included_loops c1.current c2.current c2.graph &&
    is_included_graph c1.graph c2.graph

  let not_same_origin c1 c2 =
    c1.start != c2.start ||
    c1.globals != c2.globals ||
    c1.main_formals != c2.main_formals

  let join_path graph c1 c2 =
    if epsilon_path c1 c2 graph
    then (c2, graph)
    else if epsilon_path c2 c1 graph
    then (c1, graph)
    else
      let n = Node.of_int (Edge.Counter.next ()) in
      let m = Msg(n,"join") in
      let m1 = Graph.singleton c1 [m] in
      let m2 = Graph.singleton c2 [m] in
      let g = join_graph (join_graph m1 graph) m2 in
      ( n, g)

  let rec join_loops graph l1 l2 =
    match l1, l2 with
    | Base _, Loop _ | Loop _, Base _ ->
      (* not in the same number of loops *)
      `Top
    | Base c1, Base c2 ->
      let (n,g) = join_path graph c1 c2 in
      `Value( Base n, g)
    | Loop(stmt1,_,_,_,_), Loop(stmt2,_,_,_,_) when not (Stmt.equal stmt1 stmt2) ->
      (* not same loop *)
      `Top
    | Loop(stmt1,s1,used1,c1,l1), Loop(_,s2,_,_,l2) when not (Node.equal s1 s2) ->
      (* not entered in the loop at the same time, take arbitrarily one of them *)
      begin match join_loops graph l1 l2 with
        | `Top -> `Top
        | `Value(l,graph) ->
          `Value(Loop(stmt1,s1,used1,c1,l), graph)
      end
    | Loop(stmt,s,used1,c1,l1), Loop(_,_,used2,c2,l2) ->
      begin match join_loops graph l1 l2 with
        | `Top -> `Top
        | `Value(l,graph) ->
          let (n,graph) = join_path graph c1 c2 in
          let used = join_used used1 used2 in
          let used = join_used (Used.singleton c1 [n]) used in
          let used = join_used (Used.singleton c2 [n]) used in
          `Value(Loop(stmt,s,used,n,l),graph)
      end

  let join c1 c2 =
    if c1.call_declared_function || c2.call_declared_function
    then assert false (* should not appended, since nothing append during a call to a not defined function *);
    match view c1, view c2 with
    | `Top, _ -> c1
    | _, `Top -> c2
    | `Other c1, `Other c2 when is_included c1 c2 -> c2
    | `Other c1, `Other c2 when is_included c2 c1 -> c1
    | `Other c1, `Other c2 ->
      if not_same_origin c1 c2 then assert false
      else
        let graph = join_graph c1.graph c2.graph in
        match join_loops graph c1.current c2.current with
        | `Top -> top
        | `Value(current,graph) -> {
            start = c1.start; current; graph; call_declared_function = false;
            globals = c1.globals; main_formals = c1.main_formals;
          }

  let widen _ _ c1 c2 =
    if c1.call_declared_function || c2.call_declared_function
    then assert false (* should not appended, since nothing append during a call to a not defined function *);
    match view c1, view c2 with
    | `Top, _ -> c1
    | _, `Top -> c2
    | `Other c1, `Other c2 ->
      if not_same_origin c1 c2 then assert false
      else c2

  let narrow _c1 c2 = `Value c2
end

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
    let s = Node.of_int (Edge.Counter.next ()) in
    let current = Loop(stmt,s,Used.empty,s,state.current) in
    { state with current }

  let incr_loop_counter _ state =
    Format.printf "@[<hv>@[incr_loop_counter:@] %a@]@." Traces.pretty state;
    match state.current with
    | Base _ -> assert false (* absurd: we are in at least a loop *)
    | Loop(stmt,s,used,_,l) ->
      let current = Loop(stmt,s,Used.empty,s,l) in
      let state = { state with current } in
      let state = Traces.remove_unused used s state in
      (* Traces.add_edge state (Msg(Node.dumb,"incr_loop_counter")) *)
      state

  let leave_loop stmt' state =
    match state.current with
    | Base _ -> assert false (* absurd: we are in at least a loop *)
    | Loop(stmt,s,used,old_current_node,current) ->
      assert (Stmt.equal stmt stmt');
      let state = { state with current } in
      let state = Traces.add_edge state (Loop(Node.dumb,s)) in
      let state = Traces.copy_edges used s old_current_node state in
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
      | Loop(_,_) ->
        assert false (* TODO *)
    end
  | l ->
    let is_if = match l with
      | [] | [_] -> assert false
      | [Assume(n1',exp1,b1) ; Assume(n2',exp2,b2)]
        when Exp.equal exp1 exp2 && b1 != b2 ->
        if b1 then Some (exp1, n1', n2') else Some (exp1,n2',n1')
      | _ -> None in
    let stmt =
      match is_if with
      | None -> assert false (* todo *)
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
            let stmts = stmts_of_cfg s.graph s.start var_map locals return_equal [] in
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
  Bottom.iter (project_of_cfg return_exp) state


(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
