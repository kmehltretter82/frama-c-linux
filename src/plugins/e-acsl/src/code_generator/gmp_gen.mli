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

  val cast_to_z: loc:location -> ?name:string -> Env.t -> exp -> exp * Env.t
  (** Assumes that the given exp is of real type and casts it into Z *)

  val add_cast:
    loc:location -> ?name:string -> Env.t -> kernel_function -> typ -> exp ->
    exp * Env.t
    (** Assumes that the given exp is of real type and casts it into
        the given typ *)

end
