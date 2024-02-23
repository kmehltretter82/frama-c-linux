(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

module type Value = sig
  include Abstract.Value.External

  (** Inter-reduction of values. Useful when the value module is a reduced
      product of several abstraction.
      The value computed by the forward evaluation for each sub-expression or
      lvalue is reduced by this function. *)
  val reduce : t -> t
end

module type Queries = sig
  include Abstract_domain.Queries
  include Datatype.S with type t = state
end

(** Generic functor. *)
module Make
    (Context : Abstract_context.S)
    (Value : Value with type context = Context.t)
    (Loc : Abstract_location.S with type value = Value.t)
    (Domain : Queries with type context = Context.t
                       and type value = Value.t
                       and type location = Loc.location)
  : Evaluation_sig.S with type state = Domain.state
                      and type context = Context.t
                      and type value = Value.t
                      and type origin = Domain.origin
                      and type loc = Loc.location

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
