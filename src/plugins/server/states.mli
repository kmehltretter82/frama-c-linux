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

val register_value :
  page:Doc.page ->
  name:string ->
  descr:Markdown.text ->
  ?details:Markdown.block ->
  output:'a Request.output ->
  get:(unit -> 'a) ->
  Request.signal

val register_state :
  page:Doc.page ->
  name:string ->
  descr:Markdown.text ->
  ?details:Markdown.block ->
  data:'a Data.data ->
  get:(unit -> 'a) ->
  set:('a -> unit) ->
  Request.signal

type 'a model (** Columns array model *)

val model : unit -> 'a model
val column :
  'a model -> name:string -> descr:Markdown.text ->
  'a Request.output -> unit

type 'a array (** Synchronized array state *)

val reload : 'a array -> unit
val update : 'a array -> 'a -> unit
val remove : 'a array -> 'a -> unit

val register_array :
  page:Doc.page ->
  name:string ->
  descr:Markdown.text ->
  ?details:Markdown.block ->
  key:('a -> string) ->
  iter:(('a -> unit) -> unit) ->
  'a model -> 'a array

(* -------------------------------------------------------------------------- *)
