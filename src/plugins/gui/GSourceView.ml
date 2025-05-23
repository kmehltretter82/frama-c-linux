(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** compatibility layer between gtksourceview 2 and 3. *)
include GSourceView3

let make_marker_attributes
    ~(source:source_view)
    ~(category:string)
    ~(priority: int)
    ?(background: Gdk.rgba option)
    ?(pixbuf:GdkPixbuf.pixbuf option)
    ?(icon_name:string option)
    () =
  let my_attributes = GSourceView3.source_mark_attributes () in
  Option.iter my_attributes#set_background background;
  Option.iter my_attributes#set_pixbuf pixbuf;
  Option.iter my_attributes#set_icon_name icon_name;
  source#set_mark_attributes ~category my_attributes priority
