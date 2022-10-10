open Cil_types

module Z : sig
  val create:
    loc:location -> ?name:string -> term option ->  Env.t -> kernel_function ->
    exp -> exp * Env.t
    (** Create an integer *)
end


module Q : sig
  val create:
    loc:location -> ?name:string -> term option ->  Env.t -> kernel_function ->
    exp -> exp * Env.t
    (** Create a real *)
end
