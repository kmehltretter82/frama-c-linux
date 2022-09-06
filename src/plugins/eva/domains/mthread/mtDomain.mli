open MtUtils
open Locations

val set_current : MtThread.thread -> unit

type memory = { read : Zone.t ; written : Zone.t }
type return = { standard : Value.t }

module State : sig
  include Datatype.S_with_collections
  val threads : t -> MtThread.Register.t
  val mutexes : t -> MtMutex.Register.t
  val memory  : t -> memory
  val return  : t -> return
end

module Cache : sig
  type 'a t = 'a Cil_datatype.Stmt.Hashtbl.t
  val copy : unit -> State.t t
  val reset : unit -> unit
end

val domain : Abstractions.Domain.registered
