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

module Node = struct include Datatype.Int let id x = x end

type edge =
  | Assign of Node.t * Cil_types.kinstr
  | Assume of Node.t * Cil_types.exp * bool
  | EnterScope of Node.t * Cil_types.varinfo list
  | LeaveScope of Node.t * Cil_types.varinfo list
  | Msg of Node.t * string
  | Top

(* Frama-C "datatype" for type [inout] *)
module Edge = struct
  module Counter = State_builder.Counter(struct let name = "Traces_domain.Edge.Counter" end)

  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type nonrec t = edge
      let name = "Value.Traces_domain.Edge.t"

      let reprs = [Top]

      let structural_descr = Structural_descr.t_abstract

      let compare (m1:t) (m2:t) =
        match m1, m2 with
        | Top, Top -> 0
        | Assign (n1,s1), Assign (n2,s2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          Cil_datatype.Kinstr.compare s1 s2
        | Assume(n1,e1,b1), Assume(n2,e2,b2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = Cil_datatype.Exp.compare e1 e2 in
          if c <> 0 then c else
            Pervasives.compare b1 b2
        | EnterScope(n1,vs1),EnterScope(n2,vs2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = Extlib.list_compare Cil_datatype.Varinfo.compare vs1 vs2 in
          c
        | LeaveScope(n1,vs1), LeaveScope(n2,vs2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = Extlib.list_compare Cil_datatype.Varinfo.compare vs1 vs2 in
          c
        | Msg(n1,s1), Msg(n2,s2) ->
          let c = Node.compare n1 n2 in
          if c <> 0 then c else
          let c = String.compare s1 s2 in
          c
        | Assign _, _ -> -1
        | _ , Assign _ -> 1
        | Assume _, _ -> -1
        | _ , Assume _ -> 1
        | EnterScope _, _ -> -1
        | _ , EnterScope _ -> 1
        | LeaveScope _, _ -> -1
        | _ , LeaveScope _ -> 1
        | Msg _, _ -> -1
        | _, Msg _ -> 1

      let equal = Datatype.from_compare

      let pretty fmt = function
        | Top -> Format.fprintf fmt "@[Top@]"
        | Assign(n,s) -> Format.fprintf fmt "@[Assign:@ %a -> %a@]" Cil_datatype.Kinstr.pretty s Node.pretty n
        | Assume(n,e,b) -> Format.fprintf fmt "@[Assume:@ %a %b -> %a@]" Cil_datatype.Exp.pretty e b Node.pretty n
        | EnterScope(n,vs) -> Format.fprintf fmt "@[EnterScope:@ %a -> %a@]"
                              (Pretty_utils.pp_list ~sep:"@ " Cil_datatype.Varinfo.pretty) vs Node.pretty n
        | LeaveScope(n,vs) -> Format.fprintf fmt "@[LeaveScope:@ %a -> %a@]"
                              (Pretty_utils.pp_list ~sep:"@ " Cil_datatype.Varinfo.pretty) vs Node.pretty n
        | Msg(n,s) -> Format.fprintf fmt "@[%s -> %a@]" s Node.pretty n

      let hash = function
        | Top -> Hashtbl.hash 0
        | Assume(n,e,b) -> Hashtbl.seeded_hash n (Hashtbl.seeded_hash (Hashtbl.hash b) (Cil_datatype.Exp.hash e))
        | Assign(n,s) -> Hashtbl.seeded_hash n (Hashtbl.seeded_hash 2 (Cil_datatype.Kinstr.hash s))
        | EnterScope(n,vs) ->
          let x = List.fold_left (fun acc e -> Hashtbl.seeded_hash acc (Cil_datatype.Varinfo.hash e)) 3 vs in
          Hashtbl.seeded_hash n x
        | LeaveScope(n,vs) ->
          let x = List.fold_left (fun acc e -> Hashtbl.seeded_hash acc (Cil_datatype.Varinfo.hash e)) 4 vs in
          Hashtbl.seeded_hash n x
        | Msg(n,s) -> Hashtbl.seeded_hash n (Hashtbl.seeded_hash 5 s)

      let copy c = c

    end)
end

module EdgeList = struct
  include Datatype.List_with_collections(Edge)(struct let module_name = "Traces_domain.EdgeList" end)
  let pretty_debug = pretty
end

module Graph =
  Hptmap.Make(Node)(EdgeList)
    (Hptmap.Comp_unused)(struct let v = [[]] end)
    (struct let l = [Ast.self] end)

type t = { start : int; current : int; graph : Graph.t}

(* Lattice structure for the abstract state above *)
module Traces = struct

  (* Frama-C "datatype" for type [inout] *)
  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type nonrec t = t
      let name = "Value.Traces_domain.Traces.t"

      let reprs = [{start = 0; current = 0; graph = Graph.empty }]

      let structural_descr = Structural_descr.t_record
          [| Descr.pack Datatype.Int.descr;
             Descr.pack Datatype.Int.descr;
             Descr.pack Graph.descr |]

      let compare m1 m2 =
        let c = Datatype.Int.compare m1.start m2.start in
        if c <> 0 then c else
          let c = Datatype.Int.compare m1.current m2.current in
          if c <> 0 then c else
            let c = Graph.compare m1.graph m2.graph in
            if c <> 0 then c else
              0

      let equal = Datatype.from_compare

      let pretty fmt m =
        Format.fprintf fmt "@[<hv>@[start: %i@]@ %a@ @[current: %i]" m.start Graph.pretty m.graph m.current

      let hash m =
        Hashtbl.seeded_hash m.start (Hashtbl.seeded_hash m.current (Graph.hash m.graph))

      let copy c = c

    end)

  (** impossible for normal values start must be bigger than current *)
  let empty = { start = 0; current = 0; graph = Graph.empty }
  let top = { start = 0; current = -1; graph = Graph.empty }

  let view m =
    if m == top then `Top
    else
      match Graph.find m.current m.graph with
      | exception Not_found -> `Other m
      | l when List.exists (Edge.equal Top) l -> `Top
      | _ -> `Other m

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

  let add_edge c edge =
    let n = Edge.Counter.next () in
    let e = match edge with
      | Assign (_,e) -> Assign(n,e)
      | Assume (_,a,b) -> Assume(n,a,b)
      | EnterScope (_,vs) -> EnterScope(n,vs)
      | LeaveScope (_,vs) -> LeaveScope(n,vs)
      | Msg (_,s) -> Msg(n,s)
      | Top -> Top
    in
    let m = Graph.singleton c.current [e] in
    let g = join_graph m c.graph in
    { start = c.start; current = n; graph = g}


  let is_included c1 c2 =
    (* start is the same *)
    c1.start = c2.start &&
    (* there are epsilons transition (Msg) between c1.current and
        c2.current *)
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
    in
    epsilon_path c1.current c2.current c2.graph
    &&
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
       c1.graph c2.graph

  let join c1 c2 =
    match view c1, view c2 with
    | `Top, _ -> c1
    | _, `Top -> c2
    | `Other c1, `Other c2 when is_included c1 c2 -> c2
    | `Other c1, `Other c2 when is_included c2 c1 -> c1
    | `Other c1, `Other c2 ->
      if c1.start <> c2.start then assert false
      else
        let n = Edge.Counter.next () in
        let m = Msg(n,"join") in
        let m1 = Graph.singleton c1.current [m] in
        let m2 = Graph.singleton c2.current [m] in
        let g = join_graph (join_graph m1 c1.graph) (join_graph m2 c2.graph) in
        {start = c1.start; current = n; graph = g}

  let widen _ _ c1 c2 =
    match view c1, view c2 with
    | `Top, _ -> c1
    | _, `Top -> c2
    | `Other c1, `Other c2 ->
      if c1.start <> c2.start then assert false
      else
        let n = Edge.Counter.next () in
        let m = Msg(n,"widen") in
        let m1 = Graph.add n [Top] (Graph.singleton c1.current [m]) in
        let g = join_graph m1 c1.graph in
        {start = c1.start; current = n; graph = g}

  let narrow _c1 c2 = `Value c2
end

let key = Structure.Key_Domain.create_key "traces domain"

module Internal = struct
  type state = t
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

    let assign ki _lv _e _v _valuation state =
      `Value(Traces.add_edge state (Assign(0,ki)))

    let assume _stmt e pos _valuation state =
      `Value(Traces.add_edge state (Assume(0,e,pos)))

    let start_call _stmt call _valuation state =
      let msg =
        Format.asprintf "start_call: %a" (Pretty_utils.pp_list ~sep:",@ "
                                               (fun fmt v -> Cil_datatype.Varinfo.pretty fmt v.Eval.formal))
          call.Eval.arguments in
      let state = Traces.add_edge state (Msg(0,msg)) in
      `Value state

    let finalize_call _stmt call ~pre:_ ~post =
      `Value (Traces.add_edge post (Msg(0,Format.asprintf "finalize_call: %a"
                                          (Pretty_utils.pp_opt Cil_datatype.Varinfo.pretty) call.Eval.return)))

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
  let introduce_globals _vars state = Traces.add_edge state (Msg(0,"introduce globals"))
  let initialize_variable lv _ ~initialized:_ _ state =
    Traces.add_edge state (Msg(0,Format.asprintf "initialize variable: %a" Printer.pp_lval lv ))
  let initialize_variable_using_type _ _ state  = Traces.add_edge state (Msg(0,"initialize variable using type"))

  (* TODO *)
  let logic_assign _assign _location ~pre:_ _state = top

  (* Logic *)
  let evaluate_predicate _ _ _ = Alarmset.Unknown
  let reduce_by_predicate _ state _ _ = `Value state

  let storage () = true

  let top_query = `Value (Cvalue.V.top, ()), Alarmset.all

  let extract_expr _oracle _state _expr = top_query
  let extract_lval _oracle _state _lv _typ _locs = top_query

  let backward_location _state _lval _typ loc value =
    `Value (loc, value)

  let enter_loop _ state = Traces.add_edge state (Msg(0,"enter_loop"))
  let incr_loop_counter _ state = Traces.add_edge state (Msg(0,"incr_loop_counter"))
  let leave_loop _ state = Traces.add_edge state (Msg(0,"leave_loop"))

  let enter_scope _kf vars state = Traces.add_edge state (EnterScope(0,vars))
  let leave_scope _kf vars state = Traces.add_edge state (LeaveScope(0,vars))

  let reduce_further _state _expr _value = [] (*Nothing intelligent to suggest*)

end

module D = Domain_builder.Complete (Internal)


(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
