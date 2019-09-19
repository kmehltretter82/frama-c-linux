(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

open Cil_types

module type Override = sig
  val function_name: string
  val replace_call: instr -> instr
  val get_globals: location -> global list
  val reset: unit -> unit
end

let base : (string, (module Override)) Hashtbl.t = Hashtbl.create 17

let register ((module M: Override) as m) =
  Hashtbl.add base M.function_name m

let reset_tables () =
  let reset _ m = let module M = (val m: Override) in M.reset () in
  Hashtbl.iter reset base

let get_globals loc =
  let get_globals m =
    let module M = (val m: Override) in
    M.get_globals loc
  in
  Hashtbl.fold (fun _ v l -> (get_globals v) @ l) base []

let called_function = function
  | Call(_, { enode = Lval((Var fct), NoOffset) }, _, _)
  | Local_init(_, ConsInit(fct, _, Plain_func), _) -> fct
  | _ -> assert false

let called_function_name inst =
  let fct = called_function inst in fct.vname

let find_stdlib_attr_in_call inst =
  let fct = called_function inst in
  if not (Cil.hasAttribute "fc_stdlib" fct.vattr) then raise Not_found

let replace_call inst =
  try
    find_stdlib_attr_in_call inst ;
    let name = called_function_name inst in
    let m = Hashtbl.find base name in
    let module M = (val m: Override) in
    M.replace_call inst
  with Not_found -> inst

class visitor = object(_)
  inherit Visitor.frama_c_inplace

  method! vfile _ =
    let after f =
      let loc = Cil.CurrentLoc.get() in
      let globals = get_globals loc in
      f.globals <- globals @ f.globals ;
      reset_tables () ;
      Ast.mark_as_changed () ;
      f
    in
    Cil.DoChildrenPost after

  method! vinst = function
    | Call(_) | Local_init(_, ConsInit(_, _, Plain_func), _) ->
      let change = function
        | [i] -> [ replace_call i ]
        | _ -> assert false
      in
      Cil.DoChildrenPost change
    | _ -> Cil.DoChildren
end

let transform file =
  Visitor.visitFramacFile (new visitor) file
