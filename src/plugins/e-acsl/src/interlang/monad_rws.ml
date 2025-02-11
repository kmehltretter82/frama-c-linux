(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2025                                               *)
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

module type Conf = sig
  type env (* Reader *)
  type out (* Writer *)
  type state (* State *)

  val empty_out : unit -> out
  val merge_out : out -> out -> out
end

module type S = sig
  type env (* Reader *)
  type out (* Writer *)
  type state (* State *)

  include Monad.S

  val run : env:env -> state:state -> 'a t -> 'a * out * state

  (* Reader *)
  val read : env t
  val with_env : (env -> env) -> 'a t -> 'a t

  (* Writer *)
  val write : out -> unit t

  (* State *)
  val get : state t
  val set : state -> unit t
  val modify : (state -> state) -> unit t

  module Bool : sig
    val only_if : bool -> unit t -> unit t
  end

  module Option : sig
    val iter : ('a -> unit t) -> 'a option -> unit t
  end
end

module Make (C : Conf)
  : S with type env = C.env
       and type state = C.state
       and type out = C.out
= struct
  type env = C.env
  type state = C.state
  type out = C.out

  include Monad.Make_based_on_bind (struct
      type 'a t = C.env -> C.state -> 'a * C.out * C.state
      let return x = fun _env state -> x, C.empty_out (), state
      let bind f m =
        fun env state ->
        let x, m_out, state = m env state in
        let y, f_out, state = f x env state in
        y, C.merge_out m_out f_out, state
    end)

  let run ~env ~state f = f env state

  (* reader *)
  let read = fun env state -> env, C.empty_out (), state
  let with_env f m = fun env state -> m (f env) state

  (* writer *)
  let write out = fun _env state -> (), out, state

  (* state *)
  let get = fun _env state -> state, C.empty_out (), state
  let set state = fun _env _state -> (), C.empty_out (), state
  let modify f = fun _env state -> (), C.empty_out (), f state

  module Bool = struct
    let only_if b m = if b then m else return ()
  end

  module Option = struct
    let iter f = function
      | None -> return ()
      | Some x -> f x
  end
end
