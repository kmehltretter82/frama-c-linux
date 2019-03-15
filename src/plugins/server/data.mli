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
(** Data Encoding *)
(* -------------------------------------------------------------------------- *)

type json = Json.t

val pretty : Format.formatter -> json -> unit

module type S =
sig
  type t
  val syntax : Syntax.t
  val of_json : json -> t
  val to_json : t -> json
end


(** Datatype registration.

    Name and page must be consistent with each other:
     - The name must be lowercase, dash-separated list of identifiers
     - Protocol data must start with ["<server>-*"]
     - Plugin data must start with ["<plugin>-*"]
*)
module type Info =
sig
  val page : Doc.page
  val name : string
  val descr : Markdown.text
end

type 'a data = (module S with type t = 'a)

(* -------------------------------------------------------------------------- *)
(** {2 Collections} *)
(* -------------------------------------------------------------------------- *)

module type S_collection =
sig
  include S
  module Joption : S with type t = t option
  module Jlist : S with type t = t list
  module Jarray : S with type t = t array
end

module Collection(A : S) : S_collection with type t = A.t

(* -------------------------------------------------------------------------- *)
(** {2 Constructors} *)
(* -------------------------------------------------------------------------- *)

module Joption(A : S) : S with type t = A.t option
module Jpair(A : S)(B : S) : S with type t = A.t * B.t
module Jtriple(A : S)(B : S)(C : S) : S with type t = A.t * B.t * C.t
module Jlist(A : S) : S with type t = A.t list
module Jarray(A : S) : S with type t = A.t array

(* -------------------------------------------------------------------------- *)
(** {2 Atomic Data} *)
(* -------------------------------------------------------------------------- *)

module Junit : S with type t = unit
module Jany : S with type t = json
module Jbool : S_collection with type t = bool
module Jint : S_collection with type t = int
module Jfloat : S_collection with type t = float
module Jstring : S_collection with type t = string
module Jident : S_collection with type t = string (** Syntax is {i ident}. *)
module Jtext : S with type t = json (** Rich text encoding, see [Jbuffer] *)

(* -------------------------------------------------------------------------- *)
(** {2 Records} *)
(* -------------------------------------------------------------------------- *)

module Record(R : Info) :
sig
  (** A new type [t] is created for each application of the functor. *)
  include S

  (** Parametric field. Can only be used with type [t]. *)
  type 'a field

  (** Field constructor *)
  val field : string -> descr:Markdown.text -> ?default:'a -> 'a data -> 'a field

  (** Optional field constructor *)
  val option : string -> descr:Markdown.text -> 'a data -> 'a option field

  (** Field presence. If the field has a default value, it will be always
      present. *)
  val has : 'a field -> t -> bool

  (** Field accessor.
      @raise Not_found if the field is optional and not present *)
  val get : 'a field -> t -> 'a

  (** Field updator. *)
  val set : 'a field -> 'a -> t -> t

  (** Contains only the default values. *)
  val default : unit -> t

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

module type Index =
sig
  include S_collection
  val get : t -> int
  val find : int -> t (** @raise Not_found if not registered *)
  val clear : unit -> unit
  (** Clear index tables. Use with extreme care. *)
end

(** Builds an indexer that {i does not} depend on current project. *)
module Static(M : Map)(I : Info) : Index with type t = M.key

(** Builds a {i projectified} index. *)
module Index(M : Map)(I : Info) : Index with type t = M.key

(* -------------------------------------------------------------------------- *)
(** {2 Identified Types} *)
(* -------------------------------------------------------------------------- *)

module type IdentifiedType =
sig
  type t
  val id : t -> int
  include Info
end

(** Builds a {i projectified} index on types with {i unique} identifiers *)
module Identified(A : IdentifiedType) : Index with type t = A.t

(* -------------------------------------------------------------------------- *)
(** {2 Dictionary} *)
(* -------------------------------------------------------------------------- *)

module type Enum =
sig
  type t
  val values : (t * string * Markdown.text) list
  include Info
end

module Dictionary(E : Enum) : S_collection with type t = E.t

(* -------------------------------------------------------------------------- *)
(** {2 Misc} *)
(* -------------------------------------------------------------------------- *)

val failure : string -> json -> 'a
(** @raise Yojson.Basic.Util.Type_error with the given arguments *)

(* -------------------------------------------------------------------------- *)
