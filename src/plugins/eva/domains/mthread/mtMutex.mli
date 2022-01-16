open MtUtils

type name = Name.t
type value = Value.t
type mutex

val create : name -> mutex
val id : mutex -> value
val of_cvalue : value -> mutex Result.t
val to_cvalue : mutex -> value

module Register : sig
  include Datatype.S_with_collections
  val id : t -> int
  val empty : t
  val top : t
  val is_included : t -> t -> bool
  val join : t -> t -> t
  val narrow : t -> t -> t

  val register : mutex -> t -> (t * value) Result.t
  val lock     : mutex -> t -> (t * value) Result.t
  val unlock   : mutex -> t -> (t * value) Result.t
end
