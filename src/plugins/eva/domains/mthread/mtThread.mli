open MtUtils
open Cil_types

type name = Name.t
type value = Value.t
type thread
include Datatype.S_with_collections with type t = thread

val dummy : thread
val main : unit -> thread
val create : name -> stmt -> kernel_function -> (varinfo * value) list -> thread

val id : thread -> value
val of_cvalue : value -> thread Result.t
val to_cvalue : thread -> value
val return_lval : thread -> Eva_ast.lval option

module Register : sig
  include Datatype.S_with_collections
  val id : t -> int
  val empty : t
  val top : t
  val is_included : t -> t -> bool
  val join : t -> t -> t
  val narrow : t -> t -> t

  val register : thread -> t -> (t * value) Result.t
  val start    : thread -> t -> (t * value) Result.t
  val suspend  : thread -> t -> (t * value) Result.t
  val cancel   : thread -> t -> (t * value) Result.t
end
