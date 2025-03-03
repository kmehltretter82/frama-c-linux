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

type ui = Design.main_window_extension_points

let thread_hook = ref []
let register_thread_hook hook = thread_hook := hook :: !thread_hook

(* Restore the value analysis results for the thread [th]. *)
let select_thread (ui: ui) (th: Mt_thread.thread_state) =
  ui#protect ~cancelable:false
    (fun () ->
       match th.th_projects with
       | [] -> ()
       | p :: _ -> Project.set_current p
    );
  (* Reset in particular the list of called functions *)
  ui#reset ()

(* Gtk menu-item which displays a thread *)
let make_thread_menu_entry (ui: ui) (menu: GMenu.menu) (th: Mt_thread.thread_state) =
  let th_item = GMenu.menu_item ~packing:menu#append () in
  let callback () =
    select_thread ui th;
    List.iter (fun hook -> hook ui th) !thread_hook;
  in
  ignore (th_item#connect#activate ~callback);
  let box = GPack.hbox ~packing:th_item#add () in
  let text = Thread.label th.th_eva_thread in
  ignore (GMisc.label ~text ~packing:box#pack ());
  th_item

(* Create the menu entries for Mthread. *)
let populate_menu =
  let menu_items = ref [] in
  fun (ui: ui) (menu: GMenu.menu) analysis ->
    let threads = Mt_thread.threads analysis in
    let threads = List.filter Mt_thread.should_compute_thread threads in
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
       Mt_main.register_analysis_hook hook;
       Mt_main.apply_analysis_hooks ())
