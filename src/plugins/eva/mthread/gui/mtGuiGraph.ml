(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

open Mthread__MtIds
open Mthread__MtTypes
open Mthread__MtSharedVarsTypes
open Mthread__MtCfgTypes
open Mthread__MtThread

open DGRAPH_MODULE


type ui = Design.main_window_extension_points
type gtk_node = Graph.DGraphModel.DotG.vertex DGraphViewItem.view_item
type cfg_view =
  (DGraphContainer.Dot.vertex,
   DGraphContainer.Dot.edge,
   DGraphContainer.cluster)
    DGraphView.view

(* Print a cfg into a hopefully fresh disk file, and returns the name
   of this file *)
let cfg_to_file cfg =
  let f = Extlib.temp_file_cleanup_at_exit "framac_graph_view" ".dot" in
  let fd = open_out f in
  let fmt = Format.formatter_of_out_channel fd in
  Mthread__MtCfg.dot_fprint_graph fmt cfg (fun _stmt -> "");
  close_out fd;
  f

(* Given a dot graph obtained by printing a cfg and then parsing the
   dot layout, give a mapping between the parsed nodes and the original ones
   (obtained by looking at the name of the nodes) *)
let cfg_mapping cfg =
  let hash_nodes = Datatype.Int.Hashtbl.create 17 in
  CfgNode.iter
    ~f_before:(fun n -> Datatype.Int.Hashtbl.add hash_nodes n.cfgn_id n) cfg;
  (fun (node: gtk_node) ->
     let node = node#item in
     let label = Graph.DGraphModel.DotG.V.label node in
     let id = Scanf.sscanf label.Graph.XDot.n_name "v%d" (fun v -> v) in
     Datatype.Int.Hashtbl.find hash_nodes id
  )

(* Given a node (which contains some multithreaded events or some var accesses),
   decides which other nodes are related, and should be highlighted with
   the first one *)
let predicate_highlight_node n n' =
  let corresponding_evt e e' = match e, e' with
    | (CreateThread id | CancelThread id),
      (CreateThread id' | CancelThread id')
    | (MutexLock id | MutexRelease id),
      (MutexLock id' | MutexRelease id')
    | (SendMsg (id, _) | ReceiveMsg (id, _, _) | CreateQueue (id, _)),
      (SendMsg (id', _) | ReceiveMsg (id', _, _) | CreateQueue (id', _)) ->
      Mthread__MtIds.Id.equal id id'
    | VarAccess (_, z), VarAccess (_, z') -> Locations.Zone.intersects z z'
    | _ -> false
  in
  let corresponding_evts s s' =
    EventsSet.exists
      (fun evt -> EventsSet.exists (corresponding_evt evt) s') s
  in
  let corresponding_zone_access s s' =
    SetZoneAccess.exists
      (fun (_, z) ->
         SetZoneAccess.exists (fun (_, z') -> Locations.Zone.intersects z z') s')
      s
  in
  (match n.cfgn_kind, n'.cfgn_kind with
   | NMT (_, evts, _), NMT (_, evts', _) -> corresponding_evts evts evts'
   | _ -> false
  ) || corresponding_zone_access
    n.cfgn_var_access.concur_accesses n'.cfgn_var_access.concur_accesses


(* Go to the statement corresponding to the node. For WholeCall nodes of
   functions with definitions, we go the first statement of the function
   called. For WholeCall nodes for declarations, the node should contain
   the callsite as its unique statement. *)
let node_press_goto_stmt (ui: ui) node =
  match node with
  | { cfgn_kind = NStart (kf, _) }
  | { cfgn_kind = NWholeCall (kf, _, _, _) }
    when Kernel_function.is_definition kf ->
    let s = Kernel_function.find_first_stmt kf in
    ui#view_stmt s
  | _ -> match  CfgNode.node_stmt node with
    | [s] -> ui#view_stmt s
    | _ -> ()

let print_context (ui: ui) node context =
  ui#pretty_information "%a"
    (fun fmt context ->
       Format.fprintf fmt "@[%a@]@." CfgNode.pretty_with_stmts node;
       let aux_stmt fmt stmt =
         let kf = Kernel_function.find_englobing_kf stmt in
         Format.fprintf fmt "%a, function %a"
           Mthread__MtCil.pretty_stmt stmt Kernel_function.pretty kf
       in
       (match node.cfgn_kind with
        | NWholeCall _ ->
          (match node.cfgn_preds with
           | [ { cfgn_kind = NCall (s, _)} ] ->
             Format.fprintf fmt "@[call originating at %a@]@."
               aux_stmt s
           | _ -> ()
          )
        | _ ->
          (match CfgNode.node_stmt node with
           | [s] -> Format.fprintf fmt "@[stmt at %a@]@." aux_stmt s
           | _ -> ()
          )
       );
       Format.fprintf fmt "@[Callstack: @[<hv>%a@]@]@."
         Mthread__MtCil.Stack.pretty node.cfgn_stack;
       Format.fprintf fmt "@[Locked mutexes: ";
       if Presence.is_empty context.locked_mutexes then
         Format.fprintf fmt "%s" "none"
       else
         Presence.pretty fmt context.locked_mutexes;
       Format.fprintf fmt "@]@.";
       Format.fprintf fmt "@[Possible other threads: %a@]@."
         Presence.pretty context.started_threads;
    ) context

(* Print the context of a node of the cfg in a pretty way *)
let node_press_show_context (ui: ui) node =
  (*  ui#annot_window#clear; *)
  print_context ui node node.cfgn_context


(* Highlight all the nodes corresponding to the given node *)
let node_press_highlight node (view: cfg_view) mapping =
  view#iter_nodes (fun gtk_node -> gtk_node#dehighlight ());
  view#iter_nodes
    (fun gtk_node ->
       let node' = mapping gtk_node in
       if predicate_highlight_node node node' then
         gtk_node#highlight ()
    )

(* Callback when a node of the cfg is called.
   Currently, we go to the statement corresponding to the node,
   and print the node context in the cfg *)
let node_press_callback (ui: ui) (view : cfg_view) mapping (node: gtk_node) =
  let node = mapping node in
  node_press_goto_stmt ui node;
  node_press_show_context ui node;
  node_press_highlight node view mapping


(* Show the cfg for the given thread in a Gtk Ocamlgraph window,
   and register some callbacks *)
let view_cfg ui ~packing th =
  let cfg = th.th_cfg in
  let file = cfg_to_file cfg in
  let cfg_view = DGraphContainer.Dot.from_dot ~default_callbacks:false
      ~status:DGraphContainer.Global ~packing file
  in
  let mapping = cfg_mapping cfg in
  (match cfg_view#global_view with
   | None -> ()
   | Some view ->
     view#iter_nodes
       (fun node ->
          let callback ev =
            match ev with
            | `BUTTON_PRESS _ ->
              node_press_callback ui view mapping node;
              false
            | _ -> false
          in
          node#connect_event ~callback
       );
     match cfg_view#tree_root with
     | None -> ()
     | Some node -> (view#get_node node)#center ()
  );
  cfg_view

(* Creates a window that contains the cfg *)
let cfg_window (ui : ui) thread =
  let title = Format.asprintf "Cfg for thread %a" Id.pretty thread.th_id in
  let main = ui#main_window in
  let height = int_of_float (float main#default_height *. 3. /. 4.) in
  let width = int_of_float (float main#default_width *. 3. /. 4.) in
  let window =
    GWindow.window
      ~width ~height ~title ~allow_shrink:true ~allow_grow:true
      ~position:`CENTER ()
  in
  let view = view_cfg ui thread ~packing:window#add in
  window#show ();
  view#adapt_zoom ()

let () = MtGui.register_thread_hook cfg_window
