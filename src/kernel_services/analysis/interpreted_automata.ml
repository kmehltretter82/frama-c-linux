(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(* If enabled, all automata built by this module are printed as dot files. *)
let debug_output_to_dot = false

(* ---------------------------------------------------------------------- *)
(* --- Graph definitions                                              --- *)
(* ---------------------------------------------------------------------- *)

type vertex_info =
  | NoneInfo
  | LoopHead of { stmt : stmt; level : int }

type 'a control =
  | Edges (* control flow is only given by vertex edges *)
  | Loop of 'a (* start vertex of a Loop stmt with breaking vertex *)
  | If of { cond: exp; vthen: 'a; velse: 'a }
  (* edges are guaranteed to be two guards `Then` else `Else`
     with the given condition and successor vertices. *)
  | Switch of { value: exp; cases: (exp * 'a) list; default: 'a }
  (* edges are guaranteed to be issued from a `switch()` statement with
     the given cases and default vertices. *)

type vertex = {
  vertex_kf : Cil_types.kernel_function;
  vertex_key : int;
  vertex_blocks : Cil_types.block list;
  mutable vertex_start_of : Cil_types.stmt option;
  mutable vertex_info : vertex_info;
  mutable vertex_control : vertex control;
}

type assert_kind =
  | Invariant
  | Assert
  | Check
  | Assume

type 'vertex labels = 'vertex Cil_datatype.Logic_label.Map.t

type 'vertex annotation = {
  kind: assert_kind;
  predicate: identified_predicate;
  labels: 'vertex labels;
  property: Property.t;
}

type 'vertex transition =
  | Skip
  | Return of exp option * stmt
  | Guard of exp * guard_kind * stmt
  | Prop of 'vertex annotation * stmt
  | Instr of instr * stmt
  | Enter of block
  | Leave of block

and guard_kind = Then | Else

type 'vertex edge = {
  edge_kf : Cil_types.kernel_function;
  edge_key : int;
  edge_kinstr : Cil_types.kinstr;
  edge_transition : 'vertex transition;
  edge_loc : location;
}

(* --- Dummy representatives --- *)

let dummy_kf = List.hd (Cil_datatype.Kf.reprs)

let dummy_vertex = {
  vertex_kf = dummy_kf;
  vertex_key = -1;
  vertex_blocks = [];
  vertex_start_of = None;
  vertex_info = NoneInfo;
  vertex_control = Edges;
}

let dummy_edge = {
  edge_kf = dummy_kf;
  edge_key = -1;
  edge_kinstr = Kglobal;
  edge_transition = Skip;
  edge_loc = Cil_datatype.Location.unknown;
}

(* --- Datatypes --- *)

(* Compare function helper *)
let (<?>) c lcmp =
  if c <> 0 then c else Lazy.force lcmp

module Vertex = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = vertex
    let reprs = [dummy_vertex]
    let name = "Interpreted_automata.Vertex"
    let copy v =
      { v with vertex_key = v.vertex_key }
    let compare v1 v2 =
      v1.vertex_key - v2.vertex_key <?>
      lazy (Kernel_function.compare v1.vertex_kf v2.vertex_kf)
    let hash v =
      Hashtbl.hash (Kernel_function.hash v.vertex_kf, v.vertex_key)
    let equal v1 v2 =
      v1.vertex_key = v2.vertex_key &&
      Kernel_function.equal v1.vertex_kf v2.vertex_kf
    let pretty fmt v =
      Format.pp_print_int fmt v.vertex_key;
      Option.iter (fun stmt -> Format.fprintf fmt "@s%d" stmt.sid) v.vertex_start_of
  end)

module Transition = Datatype.Make (struct
    include Datatype.Serializable_undefined
    type t = vertex transition
    let name = "Interpreted_automata.Transition"
    let reprs = [Skip]
    let pretty fmt =
      let open Format in
      let print_var_list fmt l =
        Pretty_utils.pp_list ~sep:", " Printer.pp_varinfo fmt l
      and pretty_kind fmt = function
        | Invariant -> Format.pp_print_string fmt "Invariant"
        | Assert -> Format.pp_print_string fmt "Assert"
        | Assume -> Format.pp_print_string fmt "Assume"
        | Check -> Format.pp_print_string fmt "Check"
      in function
        | Skip -> ()
        | Return (None,_) -> fprintf fmt "return"
        | Return (Some exp,_) -> fprintf fmt "return %a" Printer.pp_exp exp
        | Guard (exp,Then,_) -> Printer.pp_exp fmt exp
        | Guard (exp,Else,_) -> fprintf fmt "!(%a)" Printer.pp_exp exp
        | Prop (a,_) ->
          fprintf fmt "%a: %a"
            pretty_kind a.kind Printer.pp_identified_predicate a.predicate
        | Instr (instr,_) -> Printer.pp_instr fmt instr
        | Enter (b) -> fprintf fmt "Enter %a" print_var_list b.blocals
        | Leave (b)  -> fprintf fmt "Exit %a" print_var_list b.blocals
  end)

module Edge = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = vertex edge
    let reprs = [dummy_edge]
    let name = "Interpreted_automata.Edge"
    let copy e = e
    let compare e1 e2 =
      e1.edge_key - e2.edge_key <?>
      lazy (Kernel_function.compare e1.edge_kf e2.edge_kf)
    let hash e =
      Hashtbl.hash (Kernel_function.hash e.edge_kf, e.edge_key)
    let equal e1 e2 =
      e1.edge_key = e2.edge_key &&
      Kernel_function.equal e1.edge_kf e2.edge_kf
    let pretty fmt e =
      Transition.pretty fmt e.edge_transition
  end)


(* ---------------------------------------------------------------------- *)
(* --- Generic graphs                                                 --- *)
(* ---------------------------------------------------------------------- *)

module type Graph = sig
  include Graph.Sig.I

  type wto = V.t Wto.partition
  module WTO : Wto.S with type node = V.t

  val pretty : t Pretty_utils.formatter
  val build_wto : pref:(V.t -> V.t -> int) -> t -> V.t -> wto
  val output_to_dot :
    ?pp_vertex:(V.t Pretty_utils.formatter) ->
    ?pp_edge:(E.label Pretty_utils.formatter) ->
    ?wto:wto ->
    out_channel -> t -> unit
  val exit_strategy : t -> V.t Wto.component -> wto
end

module StmtTable = Cil_datatype.Stmt.Hashtbl

module MakeGraph (Vertex : Datatype.S) (Edge : Datatype.S) = struct
  module G = Graph.Imperative.Digraph.ConcreteBidirectionalLabeled
      (Vertex)
      (struct include Edge let default = List.hd reprs end)
  include G

  let pretty fmt g =
    let iter_succ f = G.iter_succ f g in
    Pretty_utils.pp_iter G.iter_vertex ~pre:"@[" ~suf:"@]" ~sep:";@ "
      (fun fmt v ->
         Format.fprintf fmt "@[<2>@[%a ->@]@ %a@]"
           Vertex.pretty v
           (Pretty_utils.pp_iter iter_succ ~sep:",@ " Vertex.pretty) v
      )
      fmt g

  module WTO = Wto.Make (Vertex)
  type wto = Vertex.t Wto.partition

  let build_wto ~pref graph entry_point =
    WTO.partition ~pref ~init:entry_point ~succs:(G.succ graph)

  let output_to_dot ?(pp_vertex=Vertex.pretty) ?(pp_edge=Edge.pretty) ?wto
      out_channel (graph : t) =
    (* Label conversion *)
    let htmllabel fmt =
      let string_to_label s =
        (* Escape for html embedding *)
        let substitution s =
          match Str.matched_string s with
          | "<" -> "&lt;"
          | ">" -> "&gt;"
          | "&" -> "&amp;"
          | "\n" -> "<br />"
          | s -> s (* should not happen *)
        and regexp = Str.regexp "<\\|>\\|&\\|\n" in
        let s = Str.global_substitute regexp substitution s in
        let s = if s = "" then " " else s in (* graph viewers don't like empty labels *)
        `HtmlLabel s
      in
      Pretty_utils.ksfprintf string_to_label fmt
    in
    (* Build vertex attributes and subgraphs from wto if present *)
    let open Graph.Graphviz.DotAttributes in
    let module Table = FCHashtbl.Make (G.V) in
    let subgraphs = Table.create (G.nb_vertex graph) in
    let tag =
      let c = ref 0 in
      let h = (Table.create (G.nb_vertex graph)) in
      fun v -> Table.memo h v (fun _ -> incr c; !c)
    in
    let component_count = ref 0 in
    let donode subgraph head v =
      let label = htmllabel "%a" pp_vertex v in
      let vertex_attributes =
        if head && Option.is_some subgraph
        then [`Shape `Invtriangle ; label]
        else [label]
      in
      Table.add subgraphs v (vertex_attributes,subgraph,!component_count,head)
    in
    let rec traverse_element subgraph = function
      | Wto.Node v -> donode subgraph false v
      | Wto.Component (v,w) ->
        incr component_count;
        let subgraph = Some {
            sg_name = string_of_int !component_count;
            sg_parent = Option.map (fun s -> s.sg_name) subgraph;
            sg_attributes = []} in
        donode subgraph true v;
        traverse_component subgraph w
    and traverse_component subgraph w =
      List.iter (traverse_element subgraph) w
    in
    begin match wto with
      | Some w -> traverse_component None w
      | None -> ()
    end;

    (* Instanciate Dot module *)
    let module Dot = Graph.Graphviz.Dot (
      struct
        let graph_attributes _g = [`Fontname "fixed"]
        let default_vertex_attributes _g = (* [`Shape `Point] *) [`Shape `Circle]
        let vertex_name v = "cp" ^ (string_of_int (tag v))
        let vertex_attributes v =
          try let (x,_,_,_) = Table.find subgraphs v in x
          with Not_found ->
            htmllabel "%a" pp_vertex v ::
            if wto = None then [] else [`Style `Dashed]
        let get_subgraph v =
          try let (_,x,_,_) = Table.find subgraphs v in x
          with Not_found -> None
        let default_edge_attributes _g = []
        let edge_attributes (v1,e,v2) =
          htmllabel "%a" pp_edge e ::
          if Table.mem subgraphs v1 && Table.mem subgraphs v2 then
            let (_,_,c1,_) = Table.find subgraphs v1 in
            let (_,_,c2,head2) = Table.find subgraphs v2 in
            if head2 && c2 <= c1 then [`Constraint false] else []
          else if wto = None then [] else [`Style `Dashed]
        include G
      end)
    in
    Dot.output_graph out_channel graph

  let exit_strategy graph component =
    let head, l = match component with
      | Wto.Component (v, w) -> v, Wto.Node (v) :: w
      | Wto.Node (v) -> v, [component]
    in
    (* Build a table of vertices that should not be passed through to get
       a path to an exit. At the begining it only contains the component head. *)
    let table = Hashtbl.create (G.nb_vertex graph) in
    Hashtbl.add table head ();
    (* Filter elements at the top level of the wto, in reverse order *)
    let rec f acc = function
      | [] -> acc
      | Wto.Node v :: l ->
        if List.for_all (Hashtbl.mem table) (G.succ graph v) then
          (Hashtbl.add table v (); f acc l)
        else
          f (Wto.Node v :: acc) l
      | Wto.Component (v, w) :: l ->
        let vertices = v :: Wto.flatten w in (* All vertices of the sub wto *)
        List.iter (fun v -> Hashtbl.add table v ()) vertices; (* Temporarilly add them *)
        let succs = List.flatten (List.map (G.succ graph) vertices) in
        if List.for_all (Hashtbl.mem table) succs then
          f acc l
        else (
          List.iter (Hashtbl.remove table) vertices; (* Undo *)
          f (Wto.Component (v, w) :: acc) l)
    in
    f [] (List.rev l)
end


(* ---------------------------------------------------------------------- *)
(* --- Automaton                                                      --- *)
(* ---------------------------------------------------------------------- *)

module G = MakeGraph (Vertex) (Edge)

type graph = G.t

type automaton = {
  graph : graph;
  entry_point : vertex;
  return_point : vertex;
  exit_points : vertex list;
  stmt_table : (vertex * vertex) StmtTable.t;
}

type wto = G.wto

module Automaton = Datatype.Make
    (struct
      include Datatype.Serializable_undefined
      type t = automaton
      let reprs = [{
          graph=G.create ();
          entry_point=dummy_vertex;
          return_point=dummy_vertex;
          exit_points=[];
          stmt_table=StmtTable.create 0;
        }]
      let name = "Interpreted_automata.Automaton"
      let copy automaton =
        {
          automaton with
          graph = G.copy automaton.graph;
          stmt_table = StmtTable.copy automaton.stmt_table;
        }
    end)

module WTO = G.WTO

let output_to_dot ?pp_vertex ?pp_edge ?wto out_channel automaton =
  G.output_to_dot ?pp_vertex ?pp_edge ?wto out_channel automaton.graph

let exit_strategy automaton wto =
  G.exit_strategy automaton.graph wto


(* ---------------------------------------------------------------------- *)
(* --- Building                                                       --- *)
(* ---------------------------------------------------------------------- *)

(** Each goto statement is referenced during the traversal of the AST so
    that the jumps can be added to the graph afterward using a stmt_table.
    They are stored as a (vertex,stmt,stmt) tuple, where the vertex is the
    origin and the two statements are the origin and the destination of the
    jump. *)
type goto_list = (vertex * stmt * stmt) list ref

(** The following record contains the control points from and to which the
    current processed node of the AST may connect. *)
type control_points = {
  src: vertex;
  dest: vertex;
  continue: vertex;
  break: vertex;
  return: vertex;
  blocks: Cil_types.block list;
  loop_level: int;
}

let blocks_closed v1 v2 =
  let rec aux acc = function
    | [] -> acc
    | b :: l ->
      if List.memq b v2.vertex_blocks then acc
      else aux (b :: acc) l
  in
  aux [] v1.vertex_blocks

let blocks_opened c1 c2 =
  blocks_closed c2 c1 |> List.rev


(** Helpers *)

let is_loop stmt = match stmt.skind with Loop _ -> true | _ -> false
let is_goto stmt = match stmt.skind with Goto _ -> true | _ -> false

let is_goto_destination stmt = List.exists is_goto stmt.preds

let stmt_loc stmt =
  Cil_datatype.Stmt.loc stmt

let unknown_loc =
  Cil_datatype.Location.unknown

let first_loc block =
  let rec f = function
    | [] ->
      raise Not_found
    | {skind = Block b} :: l ->
      (try f b.bstmts with Not_found -> f l)
    | stmt :: _ ->
      stmt_loc stmt
  in
  try f block.bstmts
  with Not_found -> unknown_loc

let last_loc block =
  let rec f = function
    | [] ->
      raise Not_found
    | {skind = Block b} :: l ->
      (try f (List.rev b.bstmts) with Not_found -> f l)
    | stmt :: _ ->
      stmt_loc stmt
  in
  try f (List.rev block.bstmts)
  with Not_found -> unknown_loc

module LabelMap = struct
  include Cil_datatype.Logic_label.Map
  let add_builtin name = add (BuiltinLabel name)
end

(** Predicate for a loop variant v:
    \at(v,start) > \at(v,end_loop) /\ \at(v,start) >= 0  *)
let variant_predicate stmt v =
  let loc = stmt_loc stmt in
  let v_start = Logic_const.tat ~loc (v, BuiltinLabel LoopCurrent) in
  let rel1 = Rlt, v_start, Logic_const.tat ~loc (v, BuiltinLabel Here)
  and rel2 = Rle, Logic_const.tint ~loc Integer.zero, v_start in
  let pred1 = Logic_const.prel ~loc rel1 in
  let pred2 = Logic_const.prel ~loc rel2 in
  Logic_const.pand ~loc (pred1, pred2)

let supported_annotation annot = match annot.annot_content with
  | AAssert ([], _)
  | AInvariant ([], _, _)
  | AVariant (_, None) -> true
  | _ -> false (* TODO *)

let code_annot = Annotations.code_annot ~filter:supported_annotation

let make_annotation kf stmt annot labels =
  let kind, pred =
    match annot.annot_content with
    | AAssert ([], {tp_kind; tp_statement = pred}) ->
      begin
        match tp_kind with
        | Cil_types.Assert -> Assert, pred
        | Cil_types.Check -> Check, pred
        | Cil_types.Admit -> Assume, pred
      end
    | AInvariant ([], _, pred) -> Invariant, pred.tp_statement
    | AVariant (v, None) -> Assert, variant_predicate stmt v
    | _ -> assert false
  in
  let predicate = Logic_const.new_predicate pred in
  let property = Property.ip_of_code_annot_single kf stmt annot in
  {kind; predicate; labels; property}

(** Build an automaton from a kf. It first traverses all the statements
    recursively. The recursion does not go deeper into instructions or
    expression. After this traversal, the goto edges are added. *)
let build_automaton ~annotations kf =
  let fundec = Kernel_function.get_definition kf in
  (* These objects are "global" through the traversal of the function *)
  let g = G.create () in
  let table : (vertex * vertex) StmtTable.t = StmtTable.create 17 in
  let gotos : goto_list = ref [] in
  let exit_points : vertex list ref = ref [] in

  (* Edges and vertices are numbered consecutively *)
  let next_vertex = ref 0
  and next_edge = ref 0 in
  let add_vertex vertex_blocks =
    let v = {
      vertex_kf = kf;
      vertex_key = !next_vertex;
      vertex_blocks;
      vertex_start_of = None;
      vertex_info = NoneInfo;
      vertex_control = Edges;
    } in
    incr next_vertex;
    G.add_vertex g v; v
  and add_edge src dest edge_kinstr edge_transition edge_loc =
    let e = {
      edge_kf = kf;
      edge_key = !next_edge;
      edge_kinstr;
      edge_transition;
      edge_loc;
    } in
    incr next_edge;
    G.add_edge_e g (src, e, dest)
  in

  (* Helpers to add edges *)
  let build_jump src dest stmt guard =
    (* Build a transition followed with a jump to the [dest] vertex consisting
       in several enter/leave.
       Returns the vertex just following the transition, before the enter/leave
       transitions. *)
    let kinstr = Kstmt stmt and loc = stmt_loc stmt in
    (* Add a list of transitions *)
    let build_enter dest b =
      assert (b == List.hd dest.vertex_blocks);
      let blocks = List.tl dest.vertex_blocks in
      let v = add_vertex blocks in
      add_edge v dest kinstr (Enter b) loc;
      v
    and build_leave dest b =
      let blocks = b :: dest.vertex_blocks in
      let v = add_vertex blocks in
      add_edge v dest kinstr (Leave b) loc;
      v
    in
    let v = dest in
    let v = List.fold_left build_enter v (blocks_opened src dest) in
    let v = List.fold_left build_leave v (blocks_closed src dest) in
    add_edge src v kinstr guard loc;
    v
  in

  let rec do_list do_one control labels = function
    | [] -> assert false
    | stmt :: [] -> do_one control labels stmt
    | stmt :: l ->
      let point = add_vertex control.blocks in
      do_one {control with dest = point} labels stmt;
      do_list do_one {control with src = point} labels l
  in

  (* AST traversal *)
  let rec do_block control kinstr labels block =
    if block.bstmts = [] then
      add_edge control.src control.dest kinstr Skip unknown_loc
    else begin
      let englobing_blocks = block :: control.blocks in
      let block_start = add_vertex englobing_blocks
      and block_end = add_vertex englobing_blocks
      and loc_start = first_loc block
      and loc_end = last_loc block
      in
      add_edge control.src block_start kinstr (Enter block) loc_start;
      add_edge block_end control.dest kinstr (Leave block) loc_end;
      let block_control =
        { control with
          src = block_start;
          dest = block_end;
          blocks = englobing_blocks
        }
      in
      do_list do_stmt block_control labels block.bstmts
    end

  and do_stmt control (labels:vertex labels) stmt =
    let kinstr = Kstmt stmt
    and loc = stmt_loc stmt in
    let do_annot control labels (annot: code_annotation) : unit =
      let labels = LabelMap.add_builtin Here control.src labels in
      let annotation = make_annotation kf stmt annot labels in
      let transition = Prop (annotation, stmt) in
      add_edge control.src control.dest kinstr transition loc
    in
    let do_annot_list control labels l =
      if l = [] then control.src else
        let point = add_vertex control.blocks in
        do_list do_annot {control with dest = point} labels l;
        point
    in

    (* Adds statement annotations to the graph if required, except on loops
       where variants and invariants need some special processing. *)
    let control =
      if not annotations || is_loop stmt then control else
        let src = do_annot_list control labels (code_annot stmt) in
        { control with src }
    in

    (* Adds an empty vertex before goto destinations, allowing Eva
       to distinguish between the state juste before the label
       and the joined states from the gotoes. *)
    let control =
      if is_goto_destination stmt then
        let src = add_vertex control.blocks in
        add_edge control.src src kinstr Skip loc;
        { control with src }
      else control
    in

    (* Handle statement *)
    let dest = match stmt.skind with
      | Cil_types.Instr instr ->
        let dest =
          if Cil.instr_falls_through instr
          then control.dest
          else
            let v = add_vertex [] in
            exit_points := v :: !exit_points;
            v
        in
        add_edge control.src dest kinstr (Instr (instr, stmt)) loc;
        dest

      | Cil_types.Return (opt_exp, _) ->
        let transition = Return (opt_exp,stmt) in
        build_jump control.src control.return stmt transition

      | Goto (dest_stmt, _) ->
        gotos := (control.src,stmt,!dest_stmt) :: !gotos;
        control.src

      | Break _ | Continue _ as skind ->
        let dest =
          match skind with
          | Break _ -> control.break
          | Continue _ -> control.continue
          | _ -> assert false
        in
        build_jump control.src dest stmt Skip

      | If (exp, then_block, else_block, _) ->
        let then_point = add_vertex control.blocks
        and else_point = add_vertex control.blocks in
        let then_transition = Guard (exp, Then, stmt)
        and else_transition = Guard (exp, Else, stmt)
        in
        add_edge control.src then_point kinstr then_transition loc;
        add_edge control.src else_point kinstr else_transition loc;
        do_block { control with src = then_point } kinstr labels then_block;
        do_block { control with src = else_point } kinstr labels else_block;
        control.src.vertex_control <- If {
            cond = exp ; vthen = then_point; velse = else_point
          };
        control.dest

      | Switch (exp1, block, cases, _) ->
        (* Guards for edges of the switch *)
        let build_guard exp2 kind =
          let enode = BinOp (Eq,exp1,exp2,Cil_const.intType) in
          Guard (Cil.new_exp ~loc:exp2.eloc enode, kind, stmt)
        in
        (* First build the automaton for the block *)
        let block_control =
          { control with
            src = add_vertex control.blocks; (* This vertex is unreachable *)
            break = control.dest;
          }
        in
        do_block block_control kinstr labels block;
        (* Then link the cases *)
        let default_case : vertex option ref = ref None in
        let value_cases : (Cil_types.exp * vertex) list ref = ref [] in
        (* For all statements *)
        let values = List.fold_left
            begin fun values case_stmt ->
              let dest,_ = StmtTable.find table case_stmt in
              (* For all cases for this statement *)
              List.fold_left
                begin fun values -> function
                  | Case (exp2,_) ->
                    let guard = build_guard exp2 Then in
                    let v2 = build_jump control.src dest stmt guard in
                    value_cases := (exp2,v2) :: !value_cases ;
                    exp2 :: values
                  | Default (_) ->
                    default_case := Some dest;
                    values
                  | Label _ -> values
                end values case_stmt.Cil_types.labels
            end [] cases
        in
        (* Finally, link the default case *)
        let rec add_default_edge src = function
          | [] ->
            add_last_edge src Skip
          | exp2 :: [] ->
            let guard = build_guard exp2 Else in
            add_last_edge src guard
          | exp2 :: l ->
            let point = add_vertex control.blocks
            and guard = build_guard exp2 Else in
            add_edge src point kinstr guard loc;
            add_default_edge point l
        and add_last_edge src transition =
          match !default_case with
          | None ->
            add_edge src control.dest kinstr transition loc ;
            control.dest
          | Some case_vertex ->
            build_jump src case_vertex stmt transition |> ignore;
            case_vertex
        in
        let default_vertex = add_default_edge control.src values in
        control.src.vertex_control <- Switch {
            value = exp1;
            cases = List.rev !value_cases;
            default = default_vertex;
          };
        control.dest

      | Loop (_annotations, block, _, _, _) ->
        let loop_control =
          if not annotations
          then
            { control with
              src = control.src;
              dest = control.src;
              break = control.dest;
              continue = control.src;
              loop_level = control.loop_level + 1;
            }
          else
            (* We separate loop head from first statement of the loop, otherwise
                 we can't separate loop_entry from loop_current *)
            let loop_head_point = add_vertex control.blocks in
            add_edge control.src loop_head_point kinstr Skip loc;
            loop_head_point.vertex_info <-
              LoopHead { stmt; level = control.loop_level };
            let labels =
              LabelMap.(add_builtin LoopEntry control.src
                          (add_builtin LoopCurrent loop_head_point labels))
            in
            (* for variant to have one point at the end of the loop *)
            let loop_end_point = add_vertex control.blocks in
            let start_annot, end_annot =
              List.partition
                (function { annot_content = AVariant _ } -> false | _ -> true)
                (code_annot stmt)
            in
            let loop_start_body =
              do_annot_list {control with src = loop_head_point} labels start_annot
            in
            let loop_back =
              do_annot_list {control with src = loop_end_point} labels end_annot
            in
            add_edge loop_back loop_head_point kinstr Skip loc;
            { control with
              src = loop_start_body;
              dest = loop_end_point;
              break = control.dest;
              continue = loop_head_point;
              loop_level = control.loop_level + 1;
            }
        in
        do_block loop_control kinstr labels block;
        control.src.vertex_control <- Loop control.dest ;
        control.dest

      | Block block ->
        do_block control kinstr labels block;
        control.dest

      | UnspecifiedSequence us ->
        let block = Cil.block_from_unspecified_sequence us in
        do_block control kinstr labels block;
        control.dest

      | Throw _ | TryCatch _ | TryFinally _ | TryExcept _
        -> Kernel.not_yet_implemented ~source:(fst loc)
             "[interpreted_automata] exception handling"
    in
    (* Update statement table *)
    assert (control.src.vertex_start_of = None);
    control.src.vertex_start_of <- Some stmt;
    StmtTable.add table stmt (control.src,dest)
  in

  (* Iterate through the AST *)
  let entry_point = add_vertex []
  and return_point = add_vertex [] in
  let control =
    { src = entry_point;
      dest = return_point;
      break = dummy_vertex;
      continue = dummy_vertex;
      return = return_point;
      blocks = [];
      loop_level = 0;
    }
  in

  let labels_body =
    LabelMap.(add_builtin Pre entry_point (add_builtin Post return_point empty))
  in
  do_block control Kglobal labels_body fundec.sbody;

  (* Handle gotos *)
  List.iter
    begin fun (src,src_stmt,dest_stmt) ->
      let dest = fst (StmtTable.find table dest_stmt) in
      build_jump src dest src_stmt Skip |> ignore
    end !gotos;

  (* For annotation transitions, bind statement labels to their corresponding
     vertices once the graph has been built. The label map built with the graph
     already contains the builtin labels. *)
  let bind_labels (v1, edge, v2) =
    match edge.edge_transition with
    | Prop (annot, stmt) ->
      let l =
        Cil.extract_labels_from_pred
          (Logic_const.pred_of_id_pred annot.predicate)
      in
      let bind label map =
        try
          let vertex = match label with
            | FormalLabel _ -> raise Not_found
            | BuiltinLabel _ -> LabelMap.find label annot.labels
            | StmtLabel stmt -> snd (StmtTable.find table !stmt)
          in
          LabelMap.add label vertex map
        with Not_found -> map
      in
      let new_map = Cil_datatype.Logic_label.Set.fold bind l LabelMap.empty in
      let new_annot = { annot with labels = new_map } in
      let new_transition = Prop (new_annot, stmt) in
      let new_edge = { edge with edge_transition = new_transition } in
      G.remove_edge_e g (v1, edge, v2);
      G.add_edge_e g (v1, new_edge, v2)
    | _ -> ()
  in
  G.iter_edges_e bind_labels g;

  (* Recursively removes unreachable vertices, except those bound to a statement
     in [table]. *)
  let stmt_vertices =
    let add _stmt (v1, v2) acc = Vertex.Set.(add v1 (add v2 acc)) in
    StmtTable.fold add table Vertex.Set.empty
  in
  let is_unreachable vertex =
    G.in_degree g vertex = 0
    && not (Vertex.equal vertex entry_point)
    && not (Vertex.Set.mem vertex stmt_vertices)
  in
  let rec remove_unreachable vertex =
    let succs = G.succ g vertex in
    G.remove_vertex g vertex;
    List.iter remove_unreachable (List.filter is_unreachable succs)
  in
  let unreachables =
    G.fold_vertex (fun v l -> if is_unreachable v then v :: l else l)  g []
  in
  List.iter remove_unreachable unreachables;

  (* Build the record *)
  let automaton =
    { graph = g;
      entry_point;
      return_point;
      exit_points = !exit_points;
      stmt_table = table
    }
  in

  (* Debug output *)
  if debug_output_to_dot then begin
    let function_name = Kernel_function.get_name kf in
    let file_name, file_out = Filename.open_temp_file function_name ".dot" in
    Kernel.result "Output the interpreted automaton for %s into %s"
      function_name file_name;
    output_to_dot file_out automaton;
    close_out file_out
  end;

  (* Return the result *)
  automaton


module AutomatonState = Kernel_function.Make_Table (Automaton)
    (struct
      let size = 97
      let name = "Interpreted_automata.AutomatonState"
      let dependencies = [Ast.self]
    end)

let get_automaton = AutomatonState.memo (build_automaton ~annotations:false)


(* ---------------------------------------------------------------------- *)
(* --- Weak Topological Order                                         --- *)
(* ---------------------------------------------------------------------- *)

(* Preferences for wto head vertices *)
let default_pref v1 v2 =
  match v1.vertex_info, v2.vertex_info with
  (* If there is a loop statement in the Cil representation, use the
     LoopCurrent labelled vertex as the loop head. Use the outermost
     (lowest level) loop first in case of nested loops. *)
  | LoopHead {level = i}, LoopHead {level = j} -> - (compare i j)
  | NoneInfo, LoopHead _ -> -1
  | LoopHead _ , NoneInfo -> 1
  | NoneInfo, NoneInfo ->
    (* Otherwise, use the vertex which is the start of a statement. *)
    match v1.vertex_start_of, v2.vertex_start_of with
    | None, None -> 0
    | None, _ -> -1
    | _ , None -> 1
    | Some _, Some _ -> 0

let build_wto ?(pref=default_pref) automaton =
  G.build_wto ~pref automaton.graph automaton.entry_point


(* ---------------------------------------------------------------------- *)
(* --- WTO Indexes                                                    --- *)
(* ---------------------------------------------------------------------- *)

type wto_index = vertex list

module WTOIndex =
struct

  let diff index1 index2 =
    let rec remove_common_prefix l1 l2 =
      match l1, l2 with
      | x :: l1, y :: l2 when Vertex.equal x y ->
        remove_common_prefix l1 l2
      | l1, l2 -> l1, l2
    in
    let l1 = List.rev index1
    and l2 = List.rev index2
    in
    let left, entered = remove_common_prefix l1 l2 in
    List.rev left, entered

  module Table =
  struct
    type t = wto_index Vertex.Hashtbl.t

    let build wto =
      let table = Vertex.Hashtbl.create 17 in
      let rec iter_wto index w =
        List.iter (iter_element index) w
      and iter_element index = function
        | Wto.Node v ->
          Vertex.Hashtbl.add table v index
        | Wto.Component (h, w) ->
          let new_index = h :: index in
          iter_wto new_index (Wto.Node h :: w)
      in
      iter_wto [] wto;
      table

    let find table v =
      Vertex.Hashtbl.find_def table v []

    let is_head table v =
      match find table v with
      | v' :: _ -> Vertex.equal v v'
      | [] -> false

    let is_back_edge table (v1,v2) =
      List.exists (Vertex.equal v2) (find table v1)
  end
end


(* ---------------------------------------------------------------------- *)
(* --- Graph with only one entry per component                        --- *)
(* ---------------------------------------------------------------------- *)

module UnrollUnnatural  = struct
  module Vertex_Set = struct
    include Datatype.Make_with_collections(struct
        include Datatype.Undefined
        include Vertex.Set
        let name = "Interpreted_automata.OnlyHead.Vertex_Set"
        let pretty fmt m = Pretty_utils.pp_iter ~sep:",@ "
            Vertex.Set.iter Vertex.pretty fmt m
        let reprs = [Vertex.Set.empty]
      end)

  end

  module Version = Datatype.Pair_with_collections(Vertex)(Vertex_Set)

  module Edge = Datatype.Make_with_collections (struct
      include Datatype.Serializable_undefined
      type t = Version.t edge
      let reprs = [dummy_edge]
      let name = "Interpreted_automata.UnrollUnnatural.Edge"
      let copy e = e
      let compare e1 e2 = e1.edge_key - e2.edge_key
      let hash e = e.edge_key
      let equal e1 e2 = e1.edge_key = e2.edge_key
      let pretty fmt e = Format.pp_print_int fmt e.edge_key
    end)

  module OldG = G

  include MakeGraph(Version)(Edge)

  let build (g:automaton) (wto:OldG.wto) (index:WTOIndex.Table.t) : t =

    let g' = create () in

    let needed = Vertex.Hashtbl.create 10 in
    let need v s =
      Vertex.Hashtbl.replace needed v
        (Vertex_Set.Set.add s
           (Vertex.Hashtbl.find_def needed v Vertex_Set.Set.empty))
    in

    need g.entry_point Vertex.Set.empty;

    let convert_edge nl version (e: OldG.E.label) : E.label =
      let t = match e.edge_transition with
        | Skip -> Skip
        | Return (a,b) -> Return (a,b)
        | Guard (a,b,c) -> Guard(a,b,c)
        | Instr (a,b) -> Instr (a,b)
        | Enter a -> Enter a
        | Leave a -> Leave a
        | Prop (a,b) ->
          let labels = LabelMap.map (fun v2 ->
              let v2l = WTOIndex.Table.find index v2 in
              let d1,d2 = WTOIndex.diff nl v2l in
              let version2 = List.fold_left
                  (fun acc e -> Vertex.Set.remove e acc) version d1 in
              let version2 = List.fold_left
                  (fun acc e -> Vertex.Set.add e acc) version2 d2 in
              let version2 = Vertex.Set.remove v2 version2 in
              (v2,version2)
            ) a.labels in
          Prop ({a with labels}, b)
      in
      {e with edge_transition = t}
    in

    let do_version n version =
      let n' = (n,version) in
      add_vertex g' n';
      let nl = WTOIndex.Table.find index n in
      OldG.iter_succ_e (fun (_,e,v2) ->
          let v2l = WTOIndex.Table.find index v2 in
          let d1,d2 = WTOIndex.diff nl v2l in
          let version2 = List.fold_left
              (fun acc e -> Vertex.Set.remove e acc) version d1 in
          let version2 = List.fold_left
              (fun acc e -> Vertex.Set.add e acc) version2 d2 in
          let version2 = Vertex.Set.remove v2 version2 in
          let e = convert_edge nl version e in
          add_edge_e g' (n',e,(v2,version2));
          need v2 version2
        ) g.graph n;
    in

    let do_node n =
      let s = Vertex.Hashtbl.find_def needed n Vertex_Set.Set.empty in
      Vertex_Set.Set.iter (do_version n) s;
    in

    let rec component_ext a =
      match a with
      | Wto.Node n -> do_node n
      | Wto.Component (n,l) ->
        let rec aux s =
          do_node n;
          partition_ext l;
          let s' = Vertex.Hashtbl.find_def needed n Vertex_Set.Set.empty in
          if not (Vertex_Set.Set.equal s s') then
            aux s'
        in
        aux (Vertex.Hashtbl.find_def needed n Vertex_Set.Set.empty)
    and partition_ext l =
      List.iter component_ext l
    in
    partition_ext wto;
    g'

end

(* ---------------------------------------------------------------------- *)
(* --- Dataflow computation                                           --- *)
(* ---------------------------------------------------------------------- *)

type 'a widening = Fixpoint | Widening of 'a

module type Domain =
sig
  type t

  val join : t -> t -> t
  val widen : t -> t -> t widening
  val transfer : vertex -> vertex edge ->  t -> t option
end

module type DataflowAnalysis =
sig
  type state
  type result

  val fixpoint : ?wto:wto -> Cil_types.kernel_function -> state -> result

  module Result :
  sig
    val at_entry : result -> state option
    val at_return : result -> state option
    val before : result -> Cil_types.stmt -> state option
    val after : result -> Cil_types.stmt -> state option
    val iter_vertex : (vertex -> state -> unit) -> result -> unit
    val iter_stmt : (Cil_types.stmt -> state -> unit) -> result -> unit
    val iter_stmt_asc : (Cil_types.stmt -> state -> unit) -> result -> unit
    val to_dot_output : (Format.formatter -> state -> unit) ->
      result -> out_channel -> unit
    val to_dot_file : (Format.formatter -> state -> unit) ->
      result -> Filepath.Normalized.t -> unit
    val as_table : result -> state Vertex.Hashtbl.t
  end
end

module DataflowAnalysis (D : Domain) =
struct
  type state = D.t
  type result = automaton * wto * D.t Vertex.Hashtbl.t

  module States = Vertex.Hashtbl

  let compute ~fold_pred automaton wto initial_value  =
    let results = States.create (G.nb_vertex automaton.graph) in

    let initial_values =
      match Wto.head wto with
      | None -> fun _ -> [] (* should not happen *)
      | Some v -> fun u -> if v == u then [ initial_value ] else []
    in

    (* Compute the transfer function for the given edge and add the result to
       acc *)
    let process_edge v e acc =
      (* Retrieve origin value *)
      let value = States.find_opt results v in
      let result = Option.bind (D.transfer v e) value in
      Option.to_list result @ acc
    in

    (* Compute the abstract value for the given control point ; compute all
       incoming transfer functions *)
    let process_vertex v =
      let incoming = fold_pred process_edge automaton.graph v [] in
      match initial_values v @ incoming with
      | [] -> (* Zero incoming values -> Bottom *)
        States.remove results v
      | v1 :: vl ->
        (* Join incoming values *)
        let result = List.fold_left D.join v1 vl in
        States.replace results v result
    in

    (* widen returns whether it is necessary to continue to iterate or not *)
    let widen v previous =
      let current = States.find_opt results v in
      match previous, current with
      | _, None -> false (* Current is bottom, let's quit *)
      | None, _ -> true (* Previous was bottom *)
      | Some v1, Some v2 ->
        match D.widen v1 v2 with
        | Fixpoint -> false (* End of iteration *)
        | Widening value -> (* new value *)
          States.replace results v value;
          true
    in

    let rec iterate_list l =
      List.iter iterate_element l
    and iterate_element = function
      | Wto.Node v ->
        ignore (process_vertex v)
      | Wto.Component (v, w) ->
        (* Do at least one iteration *)
        process_vertex v;
        iterate_list w;
        (* Then reach a fixpoint *)
        while
          let previous = States.find_opt results v in
          process_vertex v;
          widen v previous
        do
          iterate_list w;
        done;
    in
    iterate_list wto;
    automaton, wto, results

  module Result =
  struct
    open Option.Operators
    module Stmts = Cil_datatype.Stmt.Hashtbl

    let at_entry (automaton,_wto,states) =
      States.find_opt states automaton.entry_point

    let at_return (automaton,_wto,states) =
      States.find_opt states automaton.return_point

    let before (automaton,_wto,states) stmt =
      let* before, _ = Stmts.find_opt automaton.stmt_table stmt in
      States.find_opt states before

    let after (automaton,_wto,states) stmt =
      let* _, after = Stmts.find_opt automaton.stmt_table stmt in
      States.find_opt states after

    let iter_vertex f (_automaton,_wto,states) =
      States.iter f states

    let iter_stmt f (_automaton,_wto,states) =
      let f' v s =
        Option.iter (fun stmt -> f stmt s) v.vertex_start_of
      in
      States.iter f' states

    let iter_stmt_asc f (_automaton,_wto,states) =
      let filter (v,s) =
        match v.vertex_start_of with
        | None -> None
        | Some stmt -> Some (stmt,s)
      in
      let cmp (stmt1,_) (stmt2,_) =
        Cil_datatype.Stmt.compare stmt1 stmt2
      in
      States.to_seq states |> Seq.filter_map filter |>
      List.of_seq |> List.fast_sort cmp |>
      List.iter (fun (stmt,s) -> f stmt s)

    let to_dot_output pp_value (automaton,wto,states) out =
      let pp_vertex fmt v =
        match States.find_opt states v with
        | None -> Format.fprintf fmt "⊥"
        | Some v -> pp_value fmt v
      in
      output_to_dot ~pp_vertex ~wto out automaton

    let to_dot_file pp_value result filepath =
      match Filepath.with_open_out filepath (to_dot_output pp_value result) with
      | Ok () -> ()
      | Error error ->
        Kernel.warning "cannot output automaton to dot file %a: %s"
          Filepath.Normalized.pretty filepath error

    let as_table (_automaton,_wto,states) =
      states
  end
end

module ForwardAnalysis (D : Domain) =
struct
  include DataflowAnalysis (D)

  let build_wto automaton =
    let init = automaton.entry_point
    and succs = fun v -> G.succ automaton.graph v
    and pref = fun _ _ -> 0 in
    WTO.partition ~pref ~init ~succs

  let fixpoint ?wto kf initial_value =
    let fold_pred f =
      let f' (v,t,_) = f v t in
      G.fold_pred_e f'
    in
    let automaton = get_automaton kf in
    let wto = match wto with
      | Some wto -> wto
      | None -> build_wto automaton
    in
    compute ~fold_pred automaton wto initial_value
end

module BackwardAnalysis (D : Domain) =
struct
  include DataflowAnalysis (D)

  let build_wto automaton =
    let init = automaton.return_point
    and succs = fun v -> G.pred automaton.graph v
    and pref = fun _ _ -> 0 in
    WTO.partition ~pref ~init ~succs

  let fixpoint ?wto kf initial_value =
    let fold_pred f =
      let f' (_,t,v) = f v t in
      G.fold_succ_e f'
    in
    let automaton = get_automaton kf in
    let wto = match wto with
      | Some wto -> wto
      | None -> build_wto automaton
    in
    compute ~fold_pred automaton wto initial_value
end
