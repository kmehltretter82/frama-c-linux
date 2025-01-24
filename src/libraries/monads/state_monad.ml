(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

module Make (Env : Datatype.S_with_collections) = struct

  module Cache = Env.Hashtbl
  type 'a cache = 'a Cache.t
  type env = Env.t

  module Minimal = struct

    type 'a t = ('a * env) cache option * (env -> 'a * env)
    let return (x : 'a) : 'a t = (None, fun env -> x, env)

    let compute ((cache, make) : 'a t) (env : env) : 'a * env =
      match cache with
      | None -> make env
      | Some cache when Cache.mem cache env -> Cache.find cache env
      | Some cache -> let r = make env in Cache.add cache env r ; r

    let bind (f : 'a -> 'b t) (m : 'a t) : 'b t =
      let make env = let a, env = compute m env in compute (f a) env in
      (Some (Cache.create 13), make)

  end

  include Monad.Make_based_on_bind (Minimal)
  let get_environment : env t = None, fun env -> env, env
  let set_environment (env : env) : unit t = None, fun _ -> (), env
  let resolve (m : 'a t) (env : env) : 'a * env = Minimal.compute m env

end
