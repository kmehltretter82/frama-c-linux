(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extend the [list] type to a full fleshed monad. This monad can be used
    to represent non-deterministic computations.
    @since 31.0-Gallium *)

(** {2 Monad } *)

include Monad.S_with_product with type 'a t = 'a list
include module type of Stdlib.List

(** {2 Datatype functions } *)

(** Compute a hash for the list given a hash for the elements.
    @since Frama-C+dev *)
val hash : ('a -> int) -> 'a t -> int

(** Pretty prints a set given a printer for the elements.
    @since Frama-C+dev *)
val pretty :
  (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a t -> unit

(** {2 Iterators } *)

(** Same as {!Stdlib.List.fold_left} but with the argument order reversed.
    @since Frama-C+dev *)
val fold : ('a -> 'acc -> 'acc) -> 'a t -> 'acc -> 'acc

(** Returns the index (starting at 0) of the first element verifying the
    condition.
    Appears in Ocaml 5.1.
    @since Frama-C+dev *)
val find_index: ('a -> bool) -> 'a list -> int option

(** Same as {!Stdlib.List.map2} but gives the index of the current element to
    [f]
    @since Frama-C+dev *)
val mapi2 : (int -> 'a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list

(** Same as {!Stdlib.List.map} but avoid creating a copy of the list's tail if
    the mapped function returns its argument (tested through physical equality).
    @since Frama-C+dev *)
val map_no_copy: ('a -> 'a) -> 'a list -> 'a list

(** Same as {!Stdlib.List.concat_map} but avoid creating a copy of the list's
    tail if the mapped function returns a singleton list with its argument
    (tested through physical equality).
    @since Frama-C+dev *)
val concat_map_no_copy: ('a -> 'a list) -> 'a list -> 'a list

(** {2 Accessors } *)

(** returns the unique element of a singleton list.
    @raise Invalid_argument on a non singleton list.
    @since Frama-C+dev *)
val as_singleton: 'a list -> 'a

(** returns the last element of a list.
    @raise Invalid_argument on an empty list
    @since Frama-C+dev *)
val last: 'a list -> 'a

(** [take n l] returns the first [n] elements of the list. Tail
    recursive.
    It returns an empty list if [n] is nonpositive and the whole list if [n] is
    greater than [List.length l].
    It is equivalent to [slice ~last:n l].
    @since Frama-C+dev *)
val take : int -> 'a list -> 'a list

(** [drop n l] returns the list without the first [n] elements.
    It returns the whole list if [n] is nonpositive and an empty list if [n] is
    greater than [List.length l].
    It is equivalent to [slice ~first:n l].
    @since Frama-C+dev *)
val drop : int -> 'a list -> 'a list

(** [break n l] returns a couple of the list of the first n elements and the
    list of the remaining elements. If n is smaller than 0 (resp. greater than
    the list length) then [([], l)] is returned (resp. [(l, [])]).
    It is equivalent to [(take n l, drop n l)]. *)
val break : int -> 'a list -> ('a list * 'a list)

(** [slice ?first ?last l] is equivalent to Python's slice operator
    (l[first:last]): returns the range of the list between [first] (inclusive)
    and [last] (exclusive), starting from 0.
    If omitted, [first] defaults to 0 and [last] to [List.length l].
    Negative indices are allowed, and count from the end of the list.
    [slice] never raises exceptions: out-of-bounds arguments are clipped,
    and inverted ranges result in empty lists.
    @since Frama-C+dev *)
val slice: ?first:int -> ?last:int -> 'a list -> 'a list

(** {2 Mutators } *)

(** [replace cmp x l] replaces the first element [y] of [l] such that
    [cmp x y] is true by [x]. If no such element exists, [x] is added
    at the tail of [l].
    @since Frama-C+dev *)
val replace: ('a -> 'a -> bool) -> 'a -> 'a list -> 'a list

(** {2 Product of lists } *)

(** [product_map f l1 l2] applies [f] to all the pairs of an elt of [l1] and
    an element of [l2].
    @since Frama-C+dev *)
val product_map: ('a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list

(** [product_fold f acc l1 l2] is similar to [fold_left f acc l12] with l12 the
    list of all pairs of an elt of [l1] and an elt of [l2]
    @since Frama-C+dev *)
val product_fold: ('a -> 'b -> 'c -> 'a) -> 'a -> 'b list -> 'c list -> 'a

(** {2 Conversion } *)

(** converts a list with 0 or 1 element into an option.
    @raise Invalid_argument on lists with more than one argument
    @since Frama-C+dev *)
val to_option: 'a list -> 'a option

(** {2 Combinations } *)

(** [combinations k l] computes the combinations of [k] elements from list [l].
    E.g. [combinations 2 [1;2;3;4] = [[1;2];[1;3];[1;4];[2;3];[2;4];[3;4]]].
    This function preserves the order of the elements in [l] when
    computing the sublists. [l] should not contain duplicates.
    @since Frama-C+dev *)
val combinations: int -> 'a list -> 'a list list
