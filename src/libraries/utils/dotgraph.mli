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

(** Helper for Printing Dot-graphs *)

open Pretty_utils

(** {1 Attributes} *)

type attr = [
  | `LR
  | `TB
  | `Label of string
  | `Color of string
  | `Fillcolor of string
  | `Shape of string
  | `Style of string
  | `Circle
  | `Box
  | `Oval
  | `Point
  | `Dotted
  | `Filled
  | `ArrowBoth
  | `ArrowBack
  | `ArrowForward
  | `ArrowHead of string
  | `ArrowTail of string
  | `Attr of string * string
]

val pp_attr : Format.formatter -> attr -> unit

(** {1 Dot Ouput} *)

type dot
(** Buffer to a [dot] file with a graph environment (nodes, edges, etc.) *)

val open_dot : ?name:string -> ?attr:attr list -> ?file:string -> unit -> dot
val close : dot -> unit

val is_dot_installed : unit -> bool
(** Memoized *)

val layout :
  ?force:bool ->
  ?target:string ->
  ?engine:string ->
  ?output:string -> dot -> string
(** Invoke [dot] command (if installed) with specified target and engine.
    Defaults are [~force:false], [~target:"pdf"], [~engine:"dot"].

    The [dot] buffer must be {i closed} before being laid out, although you can
    invoke several layouts.

    Output is stored in [~output] or in a filename derived from the one of [dot].
    The function returns the generated output file.

    @raise Invalid_argument if [dot] buffer is not closed, or when [dot]
    command fails and [~force:true] (not by default). *)

val printf : dot -> ('a,Format.formatter,unit,unit) format4 -> 'a
(** Low-level routine to directly write material in the [dot] file *)

val println : dot -> ('a,Format.formatter,unit,unit) format4 -> 'a
(** Low-level routine to directly write material with an end-of-line (["\n"])
    in the [dot] file *)

val flush : dot -> unit
(** Flushes the [dot] file buffer to disk. *)

(** {1 Nodes and Edges} *)

type node

(** Set default node attributes *)
val node_default : dot -> attr list -> unit

(** Set default edge attributes *)
val edge_default : dot -> attr list -> unit

(** Create a fresh node identifier *)
val fresh : ?prefix:string -> dot -> node

val pp_node : node formatter
val pp_edge : (node * node) formatter (** [a -> b] *)

(** Set attributes to node *)
val node : dot -> node -> attr list -> unit

(** Create an edge with attributes *)
val edge : dot -> node -> node -> attr list -> unit

(** Link the node sequence with attributed edges *)
val link : dot -> node list -> attr list -> unit

(** Combinaison of [fresh] and [node] *)
val inode : dot -> ?prefix:string -> ?id:node -> attr list -> node

(** {1 Clustering} *)

val rank : dot -> node list -> unit
(** Layout nodes at the same rank *)

val subgraph : dot -> ?cluster:bool -> attr list -> (unit -> unit) -> unit
(** The continuation shall add the graph content in the [dot] file.
    Clustering is true by default *)

type record = [
  | `Empty
  | `Hbox of record list
  | `Vbox of record list
  | `Label of string
  | `Port of string * link list * string
  (** Port with output edges to other nodes.
      Use [Record.link] and [Record.label] smart-constructors to create
      complex ports. *)
] and link = string * attr list * node

(** Complex node layout. Smart constructors to create records. *)
module Record :
sig
  val (<->) : record -> record -> record
  val (<|>) : record -> record -> record
  val link : ?anchor:string -> ?attr:attr list -> node -> link
  val label : ?port:string -> ?link:link list -> string -> record
end

(** Create a port to a node, and returns the associated pseudo-node so you
    can link an edge to it. *)
val port : node -> string -> node

(** Define the node to be a record *)
val record : dot -> node ->
  ?rounded:bool -> ?attr:attr list -> record -> unit

(** Create a new node from a record (combines [fresh] and [record]) *)
val irecord : dot -> ?prefix:string -> ?id:node ->
  ?rounded:bool -> ?attr:attr list -> record -> node

(** {1 Node Indexing} *)

module type Map =
sig
  type key
  type 'a t
  val empty : 'a t
  val find : key -> 'a t -> 'a
  val add : key -> 'a -> 'a t -> 'a t
end

(** Lazily associates a node to any element *)
module Node(M : Map) :
sig
  type t = M.key
  val get : t -> node
  val node : dot -> t -> attr list -> unit
  val inode : dot -> t -> attr list -> node
  val record : dot -> t -> ?rounded:bool -> ?attr:attr list -> record -> unit
  val irecord : dot -> t -> ?rounded:bool -> ?attr:attr list -> record -> node
  val clear : unit -> unit

  (** Execute the callback {i once} for all created nodes.
      Any previously registered callback by [once] or [push] is replaced
      by the new one. *)
  val once : (t -> node -> unit) -> unit

  (** Pushes the callback {i once} for all created nodes.
      You must call [pop_call] at some point to flush them.
      Any previsously registred callback by [once] or [push] is replaced
      by the new one. *)
  val push : dot -> (t -> node -> unit) -> unit

  (** Set node prefix.
      Otherwize, some default one is created for each functor application. *)
  val prefix : string -> unit
end

(** Register a continuation to be executed later *)
val push : dot -> (unit -> unit) -> unit

(** Flushes all pending continuations *)
val pop_all : dot -> unit

(** {1 Decorator} *)

(** A text buffer to compose labels and attributes.
    You may add text and attributes to the buffer, and finally
    flush it by calling [attributes] on it.
    Any text material will be output into a single [`Label] attribute. *)
type buffer

(** Create a buffer initialized with the given attributes. *)
val buffer : attr list -> buffer

(** Add text material to buffer label. *)
val bprintf : buffer -> ('a,Format.formatter,unit,unit) format4 -> 'a

val add_char : buffer -> char -> unit
val add_label : buffer -> string -> unit

(** Add attributes to the buffer. *)
val add_attr : buffer -> attr list -> unit

(** Only add attributes with a [true] boolean flag *)
val add_options : buffer -> (bool * attr list) list -> unit

(** Flushes the buffer into a list of attributes *)
val attributes : buffer -> attr list

(** Concat the attributes with flagged ones *)
val decorate : attr list -> ( bool * attr list ) list -> attr list
