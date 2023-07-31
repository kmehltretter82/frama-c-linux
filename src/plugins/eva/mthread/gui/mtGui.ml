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
open Mthread__MtThread

type ui = Design.main_window_extension_points

let thread_hook = ref []
let register_thread_hook hook = thread_hook := hook :: !thread_hook

(* Restore the value analysis results for the thread [th]. *)
let select_thread (ui:ui) th =
  ui#protect ~cancelable:false
    (fun () ->
       match th.th_projects with
       | [] -> ()
       | p :: _ -> Project.set_current p
    );
  (* Reset in particular the list of called functions *)
  ui#reset ()

(* Gtk menu-item which displays a thread *)
let make_thread_menu_entry ui (menu: GMenu.menu) th =
  let th_item = GMenu.menu_item ~packing:menu#append () in
  let callback () =
    select_thread ui th;
    List.iter (fun hook -> hook ui th) !thread_hook;
  in
  ignore (th_item#connect#activate ~callback);
  let box = GPack.hbox ~packing:th_item#add () in
  ignore (GMisc.label ~text:th.th_id.id_name ~packing:box#pack ());
  th_item

(* Create the menu entries for Mthread. *)
let populate_menu =
  let menu_items = ref [] in
  fun (ui: ui) (menu: GMenu.menu) analysis ->
    let threads = Mthread__MtThread.threads analysis in
    let threads = List.filter Mthread__MtThread.should_compute_thread threads in
    List.iter (fun r -> menu#remove (r :> GMenu.menu_item)) !menu_items;
    menu_items := List.map (make_thread_menu_entry ui menu) threads

(** Register this dialog in main window menu bar *)
let () =
  Design.register_extension
    (fun ui ->
       let menu_manager = ui#menu_manager () in
       let item, menu = menu_manager#add_menu "M_thread" in
       item#misc#hide ();
       let hook analysis =
         item#misc#show ();
         populate_menu ui menu analysis
       in
       Mthread__MtMain.register_analysis_hook hook;
       Mthread__MtMain.apply_analysis_hooks ())
