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

open Cil_datatype

(* -------------------------------------------------------------------------- *)
(* ---  Projectification                                                  --- *)
(* -------------------------------------------------------------------------- *)

module DOMAIN : Datatype.S with type t = Code.domain =
  Datatype.Make
    (struct
      type t = Code.domain
      include Datatype.Undefined
      let name = "Region.Analysis.MEMORY"
      let mem_project = Datatype.never_any_project
      let reprs =
        let m = Memory.create () in
        Code.[{ map = m; body = Stmt.Map.empty ; spec = Property.Map.empty }]
    end)

module STATE = State_builder.Hashtbl(Kernel_function.Hashtbl)(DOMAIN)
    (struct
      let size = 0
      let name = "Region.Analysis.STATE"
      let dependencies = [Ast.self]
    end)

(* -------------------------------------------------------------------------- *)
(* ---  Memoized Access                                                   --- *)
(* -------------------------------------------------------------------------- *)

let find = STATE.find

let get kf =
  try STATE.find kf with Not_found ->
    Options.feedback ~ontty:`Transient "Function %a…" Kernel_function.pretty kf ;
    let domain = Code.domain kf in
    STATE.add kf domain ;
    Options.result "@[<v 2>Function %a:%t@]@."
      Kernel_function.pretty kf
      begin fun fmt ->
        Memory.iter domain.map
          begin fun r ->
            Format.pp_print_newline fmt () ;
            Memory.pp_region fmt r ;
          end
      end ;
    domain

let compute kf = ignore @@ get kf

let add_hook f = STATE.add_hook_on_change (fun _ -> f())

(* -------------------------------------------------------------------------- *)
