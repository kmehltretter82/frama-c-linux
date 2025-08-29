(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of OCaml's [Hashtbl] module.

    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf>
*)

(* No need to expand OCaml's [Hashtbl.S] here: we do not provide an alternative
   implementation of [Hashtbl]. Hence, we will always be compatible with the
   stdlib. *)

module type S = sig

  include Hashtbl.S

  val iter_sorted:
    ?cmp:(key -> key -> int) -> (key -> 'a -> unit) -> 'a t -> unit
  (** Iter on the hashtbl, but respecting the order on keys induced
      by [cmp]. Use [Stdlib.compare] if [cmp] not given.

      If the table contains several bindings for the same key, they
      are passed to [f] in reverse order of introduction, that is,
      the most recent binding is passed first. *)

  val fold_sorted:
    ?cmp:(key -> key -> int) -> (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
  (** Fold on the hashtbl, but respecting the order on keys induced
      by [cmp]. Use [Stdlib.compare] if [cmp] not given.

      If the table contains several bindings for the same key, they
      are passed to [f] in reverse order of introduction, that is,
      the most recent binding is passed first. *)

  val iter_sorted_by_entry:
    cmp:((key * 'a) -> (key * 'a) -> int) -> (key -> 'a -> unit) -> 'a t -> unit
  val fold_sorted_by_entry:
    cmp:((key * 'a) -> (key * 'a) -> int) -> (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
  (** Iter or fold on the hashtable, respecting the order on entries
      given by [cmp]. The table may contains several bindings for the
      same key. *)

  val iter_sorted_by_value:
    cmp:('a -> 'a -> int) -> (key -> 'a -> unit) -> 'a t -> unit
  val fold_sorted_by_value:
    cmp:('a -> 'a -> int) -> (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
  (** Iter or fold on the hashtable, respecting the order on entries
      given by [cmp]. The relative order for entries whose values is
      equal according to cmp, is not specified. *)

  val find_opt: 'a t -> key -> 'a option
  val find_def: 'a t -> key -> 'a  -> 'a

  val memo: 'a t -> key -> (key -> 'a) -> 'a
  (** [memo tbl k f] returns the binding of [k] in [tbl]. If there is
      no binding, add the binding [f k] associated to [k] in [tbl] and return
      it.
      @since Chlorine-20180501
  *)

end

module Make(H: Hashtbl.HashedType) : S with type key = H.t

val hash : 'a -> int
val hash_param : int -> int -> 'a -> int
