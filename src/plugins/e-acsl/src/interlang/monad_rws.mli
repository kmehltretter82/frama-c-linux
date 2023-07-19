(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2025                                               *)
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

(** This is an implementation the RWS monad. It is a monad to model
    computations with side-effects and environments in a purely functional and
    a safe manner.
    RWS stands for Reader, Writer, State.
    - Reader: during recursive descent one often carries around an environment
      (or context) gradually enriching it when encountering terms that
      introduce new variables. Implementing this without a monad in a purely
      functional fashion requires the addition of a dedicated parameter to
      every function that partakes in the recursive descent.
      This monad renders this dedicated parameter implicit (but explicit on the
      type level). One can access the current value of the environment from
      within the monad using [read], and use [with_env] to pass on a modified
      version of the current environment to a given sub-computation.
    - Writer offers a side-channel for emitting additional data alongside the
      principal result. When transforming some structured term, one might want
      to produce additional data alongside the principal result, for example a
      list of all the fresh variables in the generated expression, or simply a
      Boolean saying whether any change has been made to the term at all.
      Implementing this in a purely functional manner usually requires passing
      around this secondary result alongside the principal result in a tuple,
      which is cumbersome.
      This monad renders this implicit. One can generate such secondary output
      using the [write] function. Note, that there is no function to access
      this secondary output from within the monad. If this is required, one
      should rely on State portion of this monad.
    - State: when one requires a value to be both written and read during a
      computation, i.e. having both Reader and Writer semantics for the same
      value one can use the State portion of this monad. A State value can be
      read using the [get] function and written to using the [set] function.

    The RWS monad is especially useful when implementing a compiler in a purely
    functional fashion. It offers a clean approach, when one wants to descend
    recursively into a term structure with the main result being the
    transformed term, where an environment needs to be maintained (Reader),
    some additional initialisation statements are generated along the way
    (Writer), and where some part of the environment has more complex semantics
    than a simple read-and-forget approach.
*)

module type Conf = sig
  (** specification for building a RWS monad using the {!Make} functor *)

  type env (** Reader variable type *)

  type out (** Writer variable type *)

  type state (** State variable type *)

  (** how to generate Writer values out of thin air ([return], [read]) *)
  val empty_out : unit -> out

  (** how to combine two writer values resulting from two computations
      combined with a [bind] *)
  val merge_out : out -> out -> out
end

module type S = sig
  (** module type of an RWS monad *)

  type env (** Reader variable type *)

  type out (** Writer variable type *)

  type state (** State variable type *)

  (** {1 Standard monad functions and types} *)

  include Monad.S

  (** execute state monad with initial environment [env] and initial state [state] *)
  val run : env:env -> state:state -> 'a t -> 'a * out * state

  (** {1 Reader monad} *)

  val read : env t (** obtain the Reader value *)

  (** run a sub-computation using a modified Reader value *)
  val with_env : (env -> env) -> 'a t -> 'a t

  (** {1 Writer monad} *)

  val write : out -> unit t (** send a value to the Writer side-channel *)

  (** {1 State monad} *)

  val get : state t (** obtain the current value of the State variable *)

  val set : state -> unit t (** set a new value for the State variable *)

  val modify : (state -> state) -> unit t
  (** modify the current value of the State variable by applying a function *)

  (** {1 Standard monadic helper functions} *)

  module Bool : sig
    val only_if : bool -> unit t -> unit t
  end

  module Option : sig
    val iter : ('a -> unit t) -> 'a option -> unit t
  end
end

(** create an RWS monad from specification [C] *)
module Make (C : Conf) : S with type out = C.out
                            and type env = C.env
                            and type state = C.state
