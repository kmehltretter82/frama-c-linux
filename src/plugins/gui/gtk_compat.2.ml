(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

let get_toolbar_index (toolbar:GButton.toolbar) (item:GButton.tool_item) =
  toolbar#get_item_index item

let window
    ?(kind:Gtk.Tags.window_type option)
    ?(title:string option)
    ?(decorated:bool option)
    ?(deletable:bool option)
    ?(focus_on_map:bool option)
    ?(icon:GdkPixbuf.pixbuf option)
    ?(icon_name:string option)
    ?(modal:bool option)
    ?(position:Gtk.Tags.window_position option)
    ?(resizable:bool option)
    ?(screen:Gdk.screen option)
    ?(type_hint:Gdk.Tags.window_type_hint option)
    ?(urgency_hint:bool option)
    ?(wmclass:(string * string) option)
    ?(border_width:int option)
    ?(width:int option)
    ?(height:int option)
    ?(show:bool option)
    ()
  =
  let allow_shrink = resizable in
  let allow_grow = resizable in
  ignore wmclass;
  GWindow.window
    ?kind ?title ?decorated ?deletable ?focus_on_map ?icon ?icon_name
    ?modal ?position ?resizable ?allow_grow ?allow_shrink ?screen
    ?type_hint ?urgency_hint ?border_width ?width ?height ?show ()
