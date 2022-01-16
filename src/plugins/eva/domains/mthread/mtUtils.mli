type pointer = Cil_types.varinfo * int

val (<?>) : int -> int lazy_t -> int



module Result : sig
  type 'a t

  val ok : 'a -> 'a t
  val warning : 'a -> ('r, Format.formatter, unit, 'a t) format4 -> 'r
  val error : ('r, Format.formatter, unit, 'a t) format4 -> 'r

  val map : ('a -> 'b) -> ('a t -> 'b t)
  val bind : 'a t -> ('a -> 'b t) -> 'b t
  val join : 'a t t -> 'a t

  val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int
  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool
  val log : error : 'a -> 'a t -> 'a

  val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
  val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
end



type trilean = True | False | Unknown

module Trilean : sig
  include Datatype.S_with_collections with type t = trilean
  val top : t
  val is_included : t -> t -> bool
  val join : t -> t -> t
  val narrow : t -> t -> t
  val maybe_true  : t -> bool
  val maybe_false : t -> bool
  val of_bool : bool -> t
  val ( && ) : t -> t -> t
  val ( || ) : t -> t -> t
  val not : t -> t
end



module Name : sig
  include Datatype.S_with_collections
  val of_string : string -> t
  val extract_of_cvalue : Cvalue.V.t -> t Result.t
end



module Value : sig
  include module type of (Cvalue.V)
  val zero : t
  val of_int : int -> t
  val extract_singleton : t -> int option
  val extract_fun : t -> Cil_types.kernel_function Result.t
end



type update_check = Ok | Invalid of (string * bool)

module type Key_sig = sig
  include Hptmap.Id_Datatype
  val key_name : string
  val key_id : t -> Value.t
  val pretty_msg : Format.formatter -> t -> unit
end

module type Status_sig = sig
  include Lattice_type.Join_Semi_Lattice
  val default : t
end

module Register (Key : Key_sig) (Status : Status_sig) : sig
  include Datatype.S_with_collections
  type status = Status.t
  type key = Key.t

  val empty : t
  val id : t -> int

  val mem : key -> t -> bool
  val find : key -> t -> status option
  val add : key -> status -> t -> t

  val register : key -> t -> (t * Value.t) Result.t
  val update : (status -> status) -> (status -> update_check) ->
    key -> t -> (t * Value.t) Result.t

  val top : t
  val is_included : t -> t -> bool
  val narrow : t -> t -> t
  val join : t -> t -> t
end
