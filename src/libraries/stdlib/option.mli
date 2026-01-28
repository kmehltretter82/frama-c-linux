(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of OCaml's {!Stdlib.Option} module. Be wary that the parameters
    order of the [bind] function are reversed compared to the standard library
    and that [get] takes an optional [exn] argument.
    @see https://frama-c.com/download/frama-c-plugin-development-guide.pdf
    @since 31.0-Gallium *)

include Monad.S_with_product with type 'a t = 'a option
include module type of Stdlib.Option

module Make_monadic_iterators (M : Monad.S) : Monad.Iterators
  with type 'a iterable := 'a option
   and type 'a monad := 'a M.t

(** The call [opt <? default] is equivalent to [value ~default opt].
    @since Frama-C+dev
*)
val ( <? ) : 'a t -> 'a -> 'a

(** Reverse {!Stdlib.Option.bind} parameters for monad compatibility.
    [bind f o] is [f v] if [o] is [Some v] and [None] if [o] is [None].
*)
val bind: ('a -> 'b t) -> 'a t -> 'b t

(** Redefines {!Stdlib.Option.get} with a [exn] parameter.
    @raise Exn if the value is [None] and [exn] is specified.
    @raise Invalid_argument if the value is [None] and [exn] is not specified.
    @return v if the value is [Some v].
    @since Frama-C+dev
*)
val get: ?exn:exn -> 'a option -> 'a

(** Compute a hash for the option given a hash for the element.
    @since Frama-C+dev *)
val hash: ('a -> int) -> 'a option -> int

(** Merges two options such that
    - [merge None None = None]
    - [merge (Some a) None = Some a]
    - [merge None (Some b) = Some b]
    - [merge (Some a) (Some b) = Some (f a b)]
      See also {!product} and {!map2} for other ways to combine options.
      @since Frama-C+dev *)
val merge: ('a -> 'a -> 'a) -> 'a option -> 'a option -> 'a option

(** Maps two options such that
    - [map2 None None = None]
    - [map2 (Some a) None = None]
    - [map2 None (Some b) = None]
    - [map2 (Some a) (Some b) = Some (f a b)]
      See also {!product} and {!merge} for other ways to combine options.
      @since Frama-C+dev *)
val map2: ('a -> 'b -> 'c) -> 'a option -> 'b option -> 'c option

(** Same as {!Stdlib.Option.map} but avoid creating a copy of the option if the
    mapped function returns its argument (tested through physical equality).
    @since Frama-C+dev *)
val map_no_copy: ('a -> 'a) -> 'a option -> 'a option

(** [filter f (Some a)] applies [f] to [a] and returns [Some a] if [f a] is true
    or [None] if [f a] is false. [filter f None] always returns [None].
    @since Frama-C+dev *)
val filter: ('a -> bool) -> 'a option -> 'a option
