val set_current : MtThread.thread -> unit

module Cache : sig
  val reset : unit -> unit
end

val domain : Abstractions.Domain.registered
