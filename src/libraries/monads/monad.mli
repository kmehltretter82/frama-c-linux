(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(** This module provides generic signatures for monads along with tools
    to build them based on minimal definitions. Those tools are provided
    for advanced users that would like to define their own monads. Any
    user that only wants to use the monads provided by the kernel can
    completly ignore them. *)



(** {2 Monad signature with let-bindings}

    This signature provides all the usual monadic operators along with
    let-bindings definitions used to simplify codes relying on monads.
    The provides operators are as follows:
    - [return] embeds a value [x] in the monad.
    - [bind] encodes the idea of "sequence" in the monadic world, i.e the
      call [bind f m] comes down to performing the computation [m] before
      applying the next computation step, represented by the function [f],
      to the resulting value.
    - [map] applies a function through the monad. One can examplify it by
      making a parallel with the list [map] operator.
    - [flatten] is used to handle nested applications of the monad.

    The provided let-bindings operators can be used to write simpler and
    cleaner code. For example, one can write [let+ v = compute x in v + 1]
    instead of [map (fun v -> v + 1) (compute x)]. The more monadic steps,
    the more simpler the code will get when written using those operators.
    In this module, [>>-] and [let*] always correspond to the [bind]
    operator while [>>-:] and [let+] always correspond to the [map].
    All those operators are provided in an [Operators] module to avoid
    spacename conflicts. Indeed, one can use the expression
    [let open Monad.Operators in] to use all the let-bindings without
    risking conflicts by including the other definitions, which have
    rather common names. This idiom also helps indicate which monad is
    currently used in a code. *)
module type S = sig
  type 'a t
  val return : 'a -> 'a t
  val flatten : 'a t t -> 'a t
  val map  : ('a -> 'b  ) -> 'a t -> 'b t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
  module Operators : sig
    val ( >>-  ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( >>-: ) : 'a t -> ('a -> 'b) -> 'b t
    val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
  end
end



(** {2 Monad signature with product}

    In a computational point of view, a monad is an abstraction of a sequence
    of operations. But sometimes, one may need to specify that two operations
    can be perform in *any* order, for instance when dealing with concurrency
    or generic errors handling using the [option] type. To do so, one needs
    a *product* on monadic values, i.e a way to combine two monads into a new
    one. Thus a second signature is provided, including a product operator
    and two the let-bindings [and*] and [and+]. *)
module type S_with_product = sig
  type 'a t
  val return : 'a -> 'a t
  val flatten : 'a t t -> 'a t
  val map  : ('a -> 'b  ) -> 'a t -> 'b t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
  val product : 'a t -> 'b t -> ('a * 'b) t
  module Operators : sig
    val ( >>-  ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
    val ( and* ) : 'a t -> 'b t -> ('a * 'b) t
    val ( >>-: ) : 'a t -> ('a -> 'b) -> 'b t
    val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
    val ( and+ ) : 'a t -> 'b t -> ('a * 'b) t
  end
end



(** {2 Building monads from minimal signatures}

    From now on, all provided definitions are designed for advanced users
    that would like to build their own monads. Each monad can be build
    by directly implementing all required operators in the previous
    signatures. However, this is a tedious and error prone work, in
    particular for the let-binging operators which are just syntactic
    sugars for other operators.

    To simplify this, two minimal definitions and the corresponding
    functors are provided to alleviate this as much as possible. Both
    definitions lead to strictly equivalent monads, as all operators of
    one definition can be build from the other. Therefore, one can use
    the simplest one to implement for their monad. 

    In depth explanations on those minimal definitions and the properties
    they should respect are given. A huge effort has been made to make
    those explanations as simple as possible even if deep down, monads
    take roots in the category theory, a notoriously difficult topic. *)


(** {3 Minimal signature based on bind}

    This is the usual minimal definition of a monadic type constructor, also
    called a Kleisli triple. The [return] function embeds a value {m x} in
    the monad. The [bind] function, also called the "combinator", corresponds
    to the idea of "sequence" in the monadic world, i.e the call [bind f m]
    comes down to performing the computation [m] before applying the next
    computation step, represented by the function [f], to the resulting value.

    To fully qualify as a monad, these three parts must respect the three
    following laws :

    1. [return] is a left-identity for [bind] :
       ∀f:('a -> 'b t), ∀x:'a, [bind f (return x) ≣ return (f x)]

    2. [return] is a right-identity for [bind] :
       ∀m:'a t, [bind return m ≣ m]

    3. [bind] is associative :
       ∀m:'a t, ∀f:('a -> 'b t), ∀g:('b -> 'c t),
       [bind (fun x -> bind g (f x)) m ≣ bind g (bind f m)]

    As there is no way in the OCaml type system to enforce those properties,
    users have to trust the implemented monad when using it, and developpers
    have to manually check that they are respected. *)
module type Based_on_bind = sig
  type 'a t
  val return : 'a -> 'a t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
end


(** {3 Minimal signature based on bind with product}

    This signature simply extends the previous one with a product operator. *)
module type Based_on_bind_with_product = sig
  type 'a t
  val return : 'a -> 'a t
  val bind : ('a -> 'b t) -> 'a t -> 'b t
  val product : 'a t -> 'b t -> ('a * 'b) t
end


(** {3 Minimal definition based on map}

    In a computer science context, this is a rarer definition of a monadic
    type constructor. It is however equivalent to the Kleisli triple one,
    and may be simpler to use for certain monads, such as the [list] one.

    To be pedantic, this approach defines a monad as a categoric functor
    equipped with two natural transformations. This does sounds frightening
    but this breaks down to rather simple concepts.

    Let's start at the beginning. A category is just a collection of objets
    and arrows (or morphisms) between those objets that satisfies two
    properties: there exists a morphism from all objects to themselves, i.e
    an identity, and if there is a morphism between objects [a] and [b] and
    a morphism between objects [b] and [c], then there must be a morphism
    between [a] and [c], i.e morphisms are associative.

    There is a strong parallel between categories and type systems. Indeed,
    if one uses the collection of all types as objects, then for all types
    ['a] and ['b], the function [f : 'a -> 'b] can be seen as a morphism
    between the objets ['a] and ['b]. As functions are naturally associative
    and, for any type ['a], one can trivially defines the identity function
    ['a -> 'a], one can conclude that types along with all functions of
    arithy one forms a category.

    Next, there is the idea of functors. In the category theory, a functor
    is a mapping between categories. That means that, given two categories
    [A] and [B], a functor maps all objects of [A] to an object of [B] and
    maps all morphisms of [A] into a morphims of [B]. But, not all mappings
    are functors. Indeed, to be a valid functor, one as to preserve the
    identity morphisms and the composition of morphims.

    The idea of functors can also be seen in a type systems. At least, the
    more restricted but enough here of an endofunctor, a functor from a
    category to itself. Indeed, for any type [v] and for any parametric
    type ['a t], the type [v t] can be seen as a mapping from values of
    type [v] to values of type [v t]. Thus the type ['a t] encodes the first
    part of what a functor is, a mapping from objects of the Type category
    to objects of the Type category. For the second part, we need a way to
    transform morphisms of the Type category, i.e functions of type ['a -> 'b],
    in a way that preserves categoric properties. Expressed as a type, this
    transformation can be seen as a higher-order function [map] with the
    type [map : ('a -> 'b) -> ('a t -> 'b t)].

    Finally, this definition of a monad requires two natural transformations.
    Simply put, a natural transformation is a mapping between functors that
    preserves the structures of all the underlying categories (mathematicians
    and naming conventions...). That may be quite complicated to grasp, but in
    this case, the two required transformations are quite simple and intuitive.

    The first one, as in a Kleisli triple, is a [return] function that embeds
    values {m x} of type [v] into the monad. This function must satisfies
    similar laws than in a Kleisli triple, but expressed in terms of [map] :

    1. ∀x:'a, ∀f:('a -> 'b), [return (f x) ≣ map f (return x)]

    The second one is called [flatten], and can be seen as a way to "flatten"
    nested applications of the monad. It must also satisfy some laws :

    2. ∀m:('a t t t), [map flatten (flatten m) ≣ flatten (flatten m)]

    3. ∀m:('a t), [flatten (map return m) ≣ flatten (return m) ≣ m]

    4. ∀m:('a t t), ∀f: ('a -> 'b), [flatten (map (map f) m) ≣ map f (flatten m)]

    As there is no way in the OCaml type system to enforce those properties,
    users have to trust the implemented monad when using it, and developpers
    have to manually check that they are respected. *)
module type Based_on_map = sig
  type 'a t
  val return : 'a -> 'a t
  val map : ('a -> 'b) -> 'a t -> 'b t
  val flatten : 'a t t -> 'a t
end


(** {3 Minimal signature based on map with product}

    This signature simply extends the previous one with a product operator. *)
module type Based_on_map_with_product = sig
  type 'a t
  val return : 'a -> 'a t
  val map : ('a -> 'b) -> 'a t -> 'b t
  val flatten : 'a t t -> 'a t
  val product : 'a t -> 'b t -> ('a * 'b) t
end


(** {3 Functors extending minimal signatures}

    Those functors provide a way to extend a minimal signature into a full
    monad that satisfies the signatures defined above. This is possible
    because one can defines operations from one monadic definition
    using the operations required by the others. Indeed :

    1. ∀m:('a t), ∀f:('a -> 'b), [map f m ≣ bind (fun x -> return (f x)) m]

    2. ∀m:('a t t), [flatten m ≣ bind identity m]

    3. ∀m:('a t), ∀f:('a -> 'b t), [bind f m ≣ flatten (map f m)]

    All required laws expressed in both minimal signatures are respected
    using those definitions. *)

(** Extend a minimal monad based on bind *)
module Make_based_on_bind (M : Based_on_bind) :
  S with type 'a t = 'a M.t

(** Extend a minimal monad based on map *)
module Make_based_on_map (M : Based_on_map) :
  S with type 'a t = 'a M.t

(** Extend a minimal monad based on bind with product *)
module Make_based_on_bind_with_product (M : Based_on_bind_with_product) :
  S_with_product with type 'a t = 'a M.t

(** Extend a minimal monad based on map with product *)
module Make_based_on_map_with_product (M : Based_on_map_with_product) :
  S_with_product with type 'a t = 'a M.t
