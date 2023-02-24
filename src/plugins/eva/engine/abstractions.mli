(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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



(** Registration and building of the analysis abstractions. *)

(** {2 Registration of abstractions.} *)

(** Dynamic registration of the abstractions to be used in an Eva analysis:
    - value abstractions, detailed in the {!Abstract_value} signature;
    - location abstractions, detailed in the {!Abstract_location} signature;
    - state abstractions, or abstract domains, detailed in {!Abstract_domain}.
*)

(** Value abstractions registration. *)
module Value : sig
  type 'v key = 'v Abstract.Value.key
  type 'v value = (module Abstract_value.S with type t = 'v)

  (** Registering a value abstraction requires a single module and a key. The
      returned [`v registered] is a witness of the registration process and is
      used by the location and domain abstractions registration to declare their
      value dependencies. *)
  type 'v register = { key : 'v key ; value : 'v value }
  type 'v registered
  val register : 'v register -> 'v registered

  (** Other abstractions need to declare their value dependencies, i.e. the
      value abstractions they rely on to perform their computations. Those
      dependencies are declared as a heterogenous list containing at least one
      element. *)
  type 'v dependencies =
    | Last : 'v registered -> 'v dependencies
    | (::) : 'a registered * 'b dependencies -> ('a * 'b) dependencies
end


(** Location abstractions registration. *)
module Location : sig
  type 'l key = 'l Abstract.Location.key
  type ('v, 'l) location =
    (module Abstract_location.S with type value = 'v and type location = 'l)

  (** Registering a location abstraction requires a single module, a key and the
      registered value abstractions needed to perform the computations. The
      returned [`l registered] is a witness of the registration process and is
      used by the domain abstractions registration to declare their location
      dependencies. *)
  type ('v, 'l) register =
    { key : 'l key
    ; location : ('v, 'l) location
    ; dependencies : 'v Value.dependencies
    }
  type 'l registered
  val register : ('v, 'l) register -> 'l registered

  (** Domain abstractions need to declare their location dependencies. As for
      the value dependencies, they are declared as a heterogenous list. *)
  type 'l dependencies =
    | Last : 'l registered -> 'l dependencies
    | (::) : 'a registered * 'b dependencies -> ('a * 'b) dependencies
end


(** Domain abstractions registration. *)
module Domain : sig
  type 's key = 's Abstract.Domain.key

  (** Leaf domain abstraction, i.e. a simple domain with fixed values and
      locations dependencies. The registration of such domains requires a
      key, a single module and values and locations dependencies. *)
  module Leaf : sig
    type ('v, 'l, 's) domain =
      (module Abstract_domain.S
        with type value = 'v and type location = 'l and type state = 's)

    type ('v, 'l, 's) register =
      { key : 's key
      ; domain : ('v, 'l, 's) domain
      ; values : 'v Value.dependencies
      ; locations : 'l Location.dependencies
      }
  end

  (** Functor domain abstraction, i.e. a domain that can be built over any value
      abstractions, but with fixed locations dependencies. The registraction of
      such domains requires only the location dependencies, as the abstraction
      produced by the functor cannot rely on any particular value and the key
      can depend on the value abstractions used. *)
  module Functor : sig
    module type Domain = sig
      type location
      module Make (V : Abstract.Value.External) : sig
        include Abstract_domain.S
          with type value = V.t and type location = location
        val key : state key
      end
    end
    type 'l domain = (module Domain with type location = 'l)

    type 'l register =
      { domain : 'l domain
      ; locations : 'l Location.dependencies
      }
  end

  (** Registration of both kind of domain abstractions is done using the same
      functions. The two kind of registration information are thus regrouped
      under the same type. The returned [registered] is a witness of the
      registration process and can be used to programmatically enable the
      domain. *)
  type register =
    | Domain : ('v, 'l, 's) Leaf.register -> register
    | Functor : 'l Functor.register -> register
  type registered

  (** Registers an abstract domain. Returns a flag for the given domain.
      - [name] must be unique. The domain is used if the -eva-domains option
        has been set to [name].
      - [descr] is a description printed in the help message of -eva-domains.
      - [experimental] is false by default. If set to true, a warning is emitted
        when the domain is enabled.
      - [priority] can be any integer; domains with higher priority are always
        processed first. The domains currently provided by Eva have priority
        ranging between 1 and 19, so a priority of 0 (respectively 20) ensures
        that a new domain is processed after (respectively before) the classic
        Eva domains. The default priority is 0. *)
  val register :
    name:string -> descr:string -> ?experimental:bool -> ?priority:int ->
    register -> registered

  (** Register a dynamic abstraction: the abstraction is built by applying
      the last argument when starting an analysis, if the -eva-domains option
      has been set to [name]. See function {!register} for more details. *)
  val dynamic_register :
    name:string -> descr:string -> ?experimental:bool -> ?priority:int ->
    (unit -> register) -> unit
end


(** Value reduced product registration. Registering a value reduced product
    requires the keys of each value abstractions involved along with a reducer,
    i.e. a function that perform the reduction. *)
module Reducer : sig
  type ('a, 'b) reducer = 'a -> 'b -> 'a * 'b
  val register : 'a Value.key -> 'b Value.key -> ('a, 'b) reducer -> unit

  (** The value abstractions signature used in the engine. It is composed of the
      external signature of value abstractions, plus the reduction function of
      the reduced product. *)
  module type Value = sig
    include Abstract.Value.External
    val reduce : t -> t
  end
end



(** {2 Configuration of an analysis.} *)

(** Configuration defining the abstractions to be used in an analysis. A
    configuration can either be built from a given domain along with its
    name or can be built based on the command line parameters. The first
    approach relies on the [singleton] function and is mainly used to
    build a default abstraction during the engine initialization. The
    second one relies on the [configure] function. *)
module Config : sig
  type t
  val equal : t -> t -> bool
  val singleton : string -> Domain.registered -> t
  val configure : unit -> t
end



(** {2 Types and functions used in the engine.} *)

(** The three abstractions used in an Eva analysis. *)
module type S = sig
  module Val : Reducer.Value
  module Loc : Abstract.Location.External with type value = Val.t
  module Dom : Abstract.Domain.External
    with type value = Val.t and type location = Loc.location
end

(* The three abstractions plus an evaluation engine for these abstractions. *)
module type S_with_evaluation = sig
  include S
  module Eval : Evaluation_sig.S
    with type state = Dom.t
     and type value = Val.t
     and type loc = Loc.location
     and type origin = Dom.origin
end

(** Builds the abstractions according to a configuration. *)
val make : Config.t -> (module S)



(** {2 Analysis low level modifications.} *)

(** Registration of a hook, i.e. a function that modifies directly the three
    abstractions after their building by the engine and before the start of
    each analysis. *)
module Hooks : sig
  type hook = (module S) -> (module S)
  val register : hook -> unit
end
