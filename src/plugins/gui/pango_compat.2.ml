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

include Wutil_once

let small_font =
  once (fun f ->
      let f = Pango.Font.copy f in
      let s = Pango.Font.get_size f in
      Pango.Font.set_size f (s-2) ; f)

let bold_font =
  once (fun f ->
      let f = Pango.Font.copy f in
      Pango.Font.set_weight f `BOLD ; f)

let modify_font phi widget =
  widget#misc#modify_font (phi widget#misc#pango_context#font_description)

let set_font w name = w#misc#modify_font_by_name name
let set_monospace w = set_font w "monospace"
let set_small_font w = modify_font small_font w
let set_bold_font w = modify_font bold_font w
