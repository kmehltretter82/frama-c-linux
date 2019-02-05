(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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
(** Data Encoding *)
(* -------------------------------------------------------------------------- *)

type json = Yojson.Basic.json

val pretty : Format.formatter -> json -> unit

module type S =
sig
  type t
  val descr : Markdown.text
  val of_json : json -> t
  val to_json : t -> json
end

(* -------------------------------------------------------------------------- *)
(** {2 Collections} *)
(* -------------------------------------------------------------------------- *)

(** Record field specification. *)
type 'a field = {

  name: string ; (** Name of JSON field *)
  field: Markdown.text ; (** Format of JSON field *)
  default: Markdown.text option ; (** Description of the field default *)
  descr: Markdown.text ; (** Description of the JSON field *)

  optional: bool ; (** Whether the field is optional or not *)

  get: ('a -> json option) option ;
  (** Accessor for building the « field » value from type ['a], if
      to be including in the output. *)

  set: ('a -> json -> 'a) option ;
  (** Updater for some under-construction « record » value of type ['a]
      with the field value. *)

}

module type S_field =
sig
  include S

  (** Generic field build.
      At least one of [~get] or [~set] shall be specified. *)
  val mk_field :
    name:string ->
    optional:bool ->
    ?default:Markdown.text ->
    descr:Markdown.text ->
    ?get:('a -> t option) ->
    ?set:('a -> t -> 'a) ->
    unit -> 'a field

  (** Helper for simple (required) field *)
  val field :
    name:string ->
    descr:string ->
    ('a -> t) ->
    ('a -> t -> 'a) ->
    'a field

  (** Helper for simple (optional) field *)
  val option :
    name:string ->
    ?default:string ->
    descr:string ->
    ('a -> t option) ->
    ('a -> t -> 'a) ->
    'a field

  (** Helper for simple fields with only a getter. *)
  val getter :
    name:string ->
    descr:string ->
    ('a -> t) ->
    'a field

  (** Helper for simple fields with only an optional getter. *)
  val getopt :
    name:string ->
    ?default:string ->
    descr:string ->
    ('a -> t option) ->
    'a field

  (** Helper for simple fields with only a (required) setter. *)
  val setter :
    name:string ->
    descr:string ->
    ('a -> t -> 'a) ->
    'a field

  (** Helper for simple fields with only a (required) setter. *)
  val setopt :
    name:string ->
    ?default:string ->
    descr:string ->
    ('a -> t -> 'a) ->
    'a field

end

module type S_collection =
sig
  include S_field
  module Joption : S_field with type t = t option
  module Jlist : S_field with type t = t list
  module Jarray : S_field with type t = t array
end

module Field(A : S) : S_field with type t = A.t
module Collection(A : S) : S_collection with type t = A.t

(* -------------------------------------------------------------------------- *)
(** {2 Constructors} *)
(* -------------------------------------------------------------------------- *)

module Joption(A : S) : S_field with type t = A.t option
module Jpair(A : S)(B : S) : S_field with type t = A.t * B.t
module Jtriple(A : S)(B : S)(C : S) : S_field with type t = A.t * B.t * C.t
module Jlist(A : S) : S_field with type t = A.t list
module Jarray(A : S) : S_field with type t = A.t array

(* -------------------------------------------------------------------------- *)
(** {2 Atomic Data} *)
(* -------------------------------------------------------------------------- *)

module Junit : S with type t = unit
module Jany : S_field with type t = json
module Jbool : S_collection with type t = bool
module Jint : S_collection with type t = int
module Jfloat : S_collection with type t = float
module Jstring : S_collection with type t = string
module Jtext : S_field with type t = json
(** Rich text encoding, see [Jbuffer] *)

(* -------------------------------------------------------------------------- *)
(** {2 Record Helper} *)
(* -------------------------------------------------------------------------- *)

module Record :
sig

  (** Ordered collection of fields to finally build values of type ['a] *)
  type 'a record = 'a field list

  (** Create a parser of JSON records from the specification.
      Each field setter is applied in its order of declaration.
      Extra fields or missing required ones leads to errors. *)
  val of_json : 'a record -> ('a -> json -> 'a)

  (** Create a formatter into JSON records from the specification.
      Each field getter is applied when specified. *)
  val to_json : 'a record -> ('a -> json)

  (** Output a description table for the field specification.
      Options allow to configure the columns of the table, and the rows to
      be printed.
      - [~field] is the field name column title (defaults to [`Center "Field"])
      - [~format] is the field format column title (defaults to [`Center "Format"])
      - [~default] if an optional column title for defaults (defaults to [`Center "Default"])
      - [~descr] is the field description title (defaults to [`Left "Description"])
      - [~filter] is an optional filer over field specifications

      The [default] column is discarded if none of the filtered field has
      a default description. The output is [Markdown.empty] if all fields are
      filtered out. *)
  val descr_table :
    ?field:Markdown.column ->
    ?format:Markdown.column ->
    ?default:Markdown.column ->
    ?descr:Markdown.column ->
    ?filter:('a field -> bool) ->
    'a record -> Markdown.block

end

(* -------------------------------------------------------------------------- *)
(** {2 Indexed Values} *)
(* -------------------------------------------------------------------------- *)

(** Simplified [Map.S] *)
module type Map =
sig
  type 'a t
  type key
  val empty : 'a t
  val add : key -> 'a -> 'a t -> 'a t
  val find : key -> 'a t -> 'a
end

module type IndexInfo =
sig
  val name : string
  val descr : Markdown.text (** Actually an integer JSON *)
end

module type Index =
sig
  include S_collection
  val get : t -> int
  val find : int -> t (** @raise Not_found if not registered *)
  val clear : unit -> unit
  (** Clear index tables. Use with extreme care. *)
end

(** Builds an indexer that {i does not} depend on current project. *)
module Static(M : Map)(I : IndexInfo) : Index with type t = M.key

(** Builds a {i projectified} index. *)
module Index(M : Map)(I : IndexInfo) : Index with type t = M.key

(* -------------------------------------------------------------------------- *)
(** {2 Identified Types} *)
(* -------------------------------------------------------------------------- *)

module type IdentifiedType =
sig
  type t
  val id : t -> int
  val name : string
  val descr : Markdown.text
end

(** Builds a {i projectified} index on types with {i unique} identifiers *)
module Identified(A : IdentifiedType) : Index with type t = A.t

(* -------------------------------------------------------------------------- *)
(** {2 Dictionary} *)
(* -------------------------------------------------------------------------- *)

module type Enum =
sig
  type t
  val name : string
  val descr : Markdown.text
  val values : (t * string * Markdown.text) list
end

module Dictionary(E : Enum) :
sig
  val descr_table :
    ?tag:Markdown.column ->
    ?descr:Markdown.column ->
    unit -> Markdown.block
  include S_collection with type t = E.t
end

(* -------------------------------------------------------------------------- *)
(** {2 Misc} *)
(* -------------------------------------------------------------------------- *)

val failure : string -> json -> 'a
(** @raise Yojson.Basic.Util.Type_error with the given arguments *)

val d_tuple : Markdown.text list -> Markdown.text
val d_array : Markdown.text -> Markdown.text
val d_option : Markdown.text -> Markdown.text
val d_record : Markdown.text -> Markdown.text

(* -------------------------------------------------------------------------- *)
