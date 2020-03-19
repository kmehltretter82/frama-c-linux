(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
(*    CEA   (Commissariat à l'énergie atomique et aux énergies            *)
(*           alternatives)                                                *)
(*    INRIA (Institut National de Recherche en Informatique et en         *)
(*           Automatique)                                                 *)
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
(**************************************************************************)

open Cil_types

let rec ghost_status fmt lval =
  let t = Cil.unrollType (Cil.typeOfLval lval) in
  let ghost = Cil.isGhostType t in

  Format.fprintf fmt "%s" (if ghost then "ghost" else "normal") ;
  match t with
  | TPtr(_) ->
    Format.fprintf fmt " -> %a" pointed_ghost_status lval
  | TArray(_) ->
    Format.fprintf fmt " -> %a" in_array_ghost_status lval
  | TComp(_) ->
    Format.fprintf fmt " -> %a" comp_ghost_status lval
  | _ -> ()
and pointed_ghost_status fmt lval =
  let loc = Cil.CurrentLoc.get() in
  let exp = Cil.new_exp (Lval lval) ~loc in
  let lval = Mem(exp), NoOffset in
  Format.fprintf fmt "%a" ghost_status lval
and in_array_ghost_status fmt lval =
  let loc = Cil.CurrentLoc.get() in
  let lval = Cil.addOffsetLval (Index((Cil.zero ~loc), NoOffset)) lval in
  Format.fprintf fmt "%a" ghost_status lval
and comp_ghost_status fmt lval =
  match Cil.typeOfLval lval with
  | TComp({ cfields }, _, _) ->
    Format.fprintf fmt "{ " ;
    List.iter (field_ghost_status fmt lval) cfields ;
    Format.fprintf fmt " }"
  | _ -> assert false
and field_ghost_status fmt lval f =
  let lval = Cil.addOffsetLval (Field(f, NoOffset)) lval in
  Format.fprintf fmt "%s: %a" f.fname ghost_status lval

class visitor = object(_)
  inherit Visitor.frama_c_inplace

  method! vvdec v =
    Kernel.feedback "%a@. %a: %a"
      Cil_datatype.Location.pretty (Cil.CurrentLoc.get())
      Cil_datatype.Varinfo.pretty v
      ghost_status (Cil.var v) ;
    Cil.DoChildren
end

let () =
  Db.Main.extend (fun () -> Visitor.visitFramacFileSameGlobals (new visitor) (Ast.get ()))
