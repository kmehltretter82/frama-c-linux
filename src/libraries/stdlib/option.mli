(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extend the [option] type to a full fleshed monad. Be wary that the
    parameters order of the [bind] function are reversed compared to
    the standard library and that [get] takes a mandatory [exn] argument.
    @since 31.0-Gallium *)

include Monad.S_with_product with type 'a t = 'a option
include module type of Stdlib.Option

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
    - [union None None = None]
    - [union (Some a) None = Some a]
    - [union None (Some b) = Some b]
    - [union (Some a) (Some b) = Some (f a b)]
      @since Frama-C+dev *)
val union: ('a -> 'a -> 'a) -> 'a option -> 'a option -> 'a option

(** Merges two options such that
    - [inter None None = None]
    - [inter (Some a) None = None]
    - [inter None (Some b) = None]
    - [inter (Some a) (Some b) = Some (f a b)]
      @since Frama-C+dev *)
val inter: ('a -> 'b -> 'c) -> 'a option -> 'b option -> 'c option

(** Same as {!Stdlib.Option.map} but avoid creating a copy of the option if the
    mapped function returns its argument (tested through physical equality).
    @since Frama-C+dev *)
val map_no_copy: ('a -> 'a) -> 'a option -> 'a option

(** [filter f (Some a)] applies [f] to [a] and returns [Some a] if [f a] is true
    or [None] if [f a] is false. [filter f None] always returns [None].
    @since Frama-C+dev *)
val filter: ('a -> bool) -> 'a option -> 'a option
