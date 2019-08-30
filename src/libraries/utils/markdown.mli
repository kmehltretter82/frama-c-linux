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
(* --- Markdown Documentation Generation Utility                          --- *)
(* -------------------------------------------------------------------------- *)

(** {2 Markdown}

    A lightweight helper for generating Markdown documentation.
    Two levels of formatters are defined to help managing indentation and
    spaces: [text] for inline markdown, and [block] for markdown paragraphs.

*)

type text
type block
type section

val (<@>) : text -> text -> text (** Infix operator for [glue] *)
val (<+>) : text -> text -> text (** Infix operator for [text] *)
val (</>) : block -> block -> block (** Infix operator for [concat] *)

(** {2 Text Constructors} *)

val nil : text (** Empty *)
val raw : string -> text (** inlined markdown format *)
val rm : string -> text (** roman (normal) style *)
val it : string -> text (** italic style *)
val bf : string -> text (** bold style *)
val tt : string -> text (** typewriter style *)

val glue : ?sep:text -> text list -> text (** Glue text fragments *)
val text : text list -> text (** Glue text fragments with spaces *)

(** {2 Block Constructors} *)

val empty : block (** Empty *)
val hrule : block (** Horizontal rule *)

val h1 : ?name:string -> string -> block (** Title level 1 *)
val h2 : ?name:string -> string -> block (** Title level 2 *)
val h3 : ?name:string -> string -> block (** Title level 3 *)
val h4 : ?name:string -> string -> block (** Title level 4 *)

val in_h1 : block -> block (** Increment title levels by 1 *)
val in_h2 : block -> block (** Increment title levels by 2 *)
val in_h3 : block -> block (** Increment title levels by 3 *)
val in_h4 : block -> block (** Increment title levels by 4 *)

val par : text -> block (** Simple text paragraph *)
val praw : string -> block (** Simple raw paragraph *)
val list : text list -> block (** Itemized list *)
val enum : text list -> block (** Enumerated list *)
val description : (string * text) list -> block (** Description list *)

(** Formatted code.

    The code content is pretty-printed in a vertical [<v0>] box
    with default [Format] formatter.
    Leading and trailing empty lines are removed and indentation is
    preserved. *)
val code : ?lang:string -> (Format.formatter -> unit) -> block

val concat : block list -> block (** Glue paragraphs with empty lines *)

(** {2 Hyperlinks}

    [`Page], [`Name] and [`Section] links refers to the current document,
    see [dump] function below.

    In [`Section(p,t)], [p] is the page path relative to the
    document {i root}, and [t] is the section title {i or} name.

    For [`Name a], the links refers to name or title [a]
    in the {i current} page.

    Hence, everywhere throughout a self-content document directory [~root],
    local page [~page] inside [~root] can be referenced
    by [`Page page], and its sections can by [`Section(page,title)]
    or [`Section(page,name)].

*)

type href = [
  | `URL of string
  | `Page of string
  | `Name of string
  | `Section of string * string
]

(** Default [~title] is taken from [href]. When printed,
    actual link will be relativized with respect to current page. *)
val href : ?title:string -> href -> text

(** Define a local anchor *)
val aname : string -> block

(** {2 Tables} *)

type column = [
  | `Left of string
  | `Right of string
  | `Center of string
]

val table : column list -> text list list -> block

(** {2 Markdown Generator}
    Generating function are called each time the markdown
    fragment is printed. *)

val mk_text : (unit -> text) -> text
val mk_block : (unit -> block) -> block

(** {2 Sections}

    Sections are an alternative to [h1-h4] constructors to build
    properly nested sub-sections. Deep sections at depth 5 and more are
    flattened.
*)

val section : ?name:string -> title:string -> block -> section list -> section
val subsections : section -> section list -> section
val document : section -> block

(** {2 Dump to file}

    Generate the markdown [~page] in directory [~root] with the given content.
    The [~root] directory shall be absolute or relative to the current working
    directory. The [~page] file-path shall be relative to the [~root] directory
    and will be used to relocate hyperlinks to other [`Page] and [`Section]
    properly.

    Hence, everywhere throughout the document, [dump ~root ~page doc]
    is referenced by [`Page page], and its sections are referenced by
    [`Section(page,title)].

*)

(** Callback to listen for actual sections when printing a page. *)
type toc = level:int -> name:string -> title:string -> unit

(** Create a markdown page.
    - [~root] document directory (relocatable)
    - [~page] relative file-path of the page in [~root] (non relocatable)
    - [~names] generate explicit [<a name=...>] tags for all titles
    - [~toc] optional callback to register table of contents
*)
val dump : root:string -> page:string -> ?names:bool -> ?toc:toc -> block -> unit

(** {2 Miscellaneous} *)

val read_text : string -> text
val read_block : string -> block
val read_section : string -> section

val fmt_text : (Format.formatter -> unit) -> text
val fmt_block : (Format.formatter -> unit) -> block
val pp_text : Format.formatter -> text -> unit
val pp_block : Format.formatter -> block -> unit
val pp_section : Format.formatter -> section -> unit

(* -------------------------------------------------------------------------- *)
