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

(* -------------------------------------------------------------------------- *)
(** Request Registry *)
(* -------------------------------------------------------------------------- *)

type json = Data.json
type kind = [ `GET | `SET | `EXEC ]

module type Input =
sig
  type t
  val descr : Markdown.text
  val of_json : json -> t
end

module type Output =
sig
  type t
  val descr : Markdown.text
  val to_json : t -> json
end

module type RequestInfo =
sig
  type input
  type output
  val page : Doc.page (** Page to publish the request in *)
  val name : string (** Shall starts with the plug-in name *)
  val kind : kind (** Request kind *)
  val descr : Markdown.text (** Short introduction (one paragraph) *)
  val details : Markdown.section list (** Detailed documentation *)
  val process : input -> output (** Request processing *)
end

module type S =
sig
  include RequestInfo
  val href : Markdown.href
  val process_json : json -> json
end

(** Register a server request.

    The documentation is automatically published into the specified page.
    Some (case-insensitive) sanity checks are performed on the request
    informations:
    - it shall not be published in [`Protocol] pages;
    - its name shall starts the plug-in name, eg. ["MyPlugin.*"], or ["Kernel.*"] for
    kernel plug-ins;
    - its name shall contains ["get"], ["set"] or ["exec"] depending on its
    specified kind.

*)
module Register
    (Input : Input)
    (Output : Output)
    (Rq : RequestInfo with type input = Input.t and type output = Output.t) :
  (S with type input = Input.t and type output = Output.t)

(* -------------------------------------------------------------------------- *)
