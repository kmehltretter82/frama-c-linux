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

exception Bad_typing of string

module type Builtin = sig
  val function_name: string
  val replace_call: (varinfo * exp list) -> (varinfo * exp list)
  val get_globals: location -> global list
  val mark_as_computed: ?project:Project.t -> unit -> unit
end

let base : (string, (module Builtin)) Hashtbl.t = Hashtbl.create 17

let register ((module M: Builtin) as m) =
  Hashtbl.add base M.function_name m

let mark_as_computed () =
  let mark _ m = let module M = (val m: Builtin) in M.mark_as_computed () in
  Hashtbl.iter mark base

let get_globals loc =
  let get_globals m =
    let module M = (val m: Builtin) in
    M.get_globals loc
  in
  Hashtbl.fold (fun _ v l -> (get_globals v) @ l) base []

let find_stdlib_attr fct =
  if not (Cil.hasAttribute "fc_stdlib" fct.vattr) then raise Not_found

let replace_call (fct, args) =
  try
    find_stdlib_attr fct ;
    let m = Hashtbl.find base fct.vname in
    let module M = (val m: Builtin) in
    M.replace_call (fct, args)
  with
  | Not_found -> (fct, args)
  | Bad_typing s ->
    Options.warning ~current:true "Ignored: %s" s ;
    (fct, args)

class visitor = object(_)
  inherit Visitor.frama_c_inplace

  method! vfile _ =
    let after f =
      let loc = Cil.CurrentLoc.get() in
      let globals = get_globals loc in
      f.globals <- globals @ f.globals ;
      mark_as_computed () ;
      Ast.mark_as_changed () ;
      Ast.mark_as_grown () ;
      File.reorder_ast () ;
      f
    in
    Cil.DoChildrenPost after

  method! vinst = function
    | Call(_) | Local_init(_, ConsInit(_, _, Plain_func), _) ->
      let change = function
        | [ Call(r, ({ enode = Lval((Var fct), NoOffset) } as e), args, loc) ] ->
          let fct, args = replace_call (fct, args) in
          [ Call(r, { e with enode = Lval((Var fct), NoOffset) }, args, loc) ]
        | [ Local_init(r, ConsInit(fct, args, Plain_func), loc) ] ->
          let fct, args = replace_call (fct, args) in
          [ Local_init(r, ConsInit(fct, args, Plain_func), loc) ]
        | _ -> assert false
      in
      Cil.DoChildrenPost change
    | _ -> Cil.DoChildren
end

let transform file =
  Visitor.visitFramacFile (new visitor) file
