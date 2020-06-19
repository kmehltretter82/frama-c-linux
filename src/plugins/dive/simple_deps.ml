(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2018                                                    *)
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

class find_write target_vi = object (self)
  inherit Visitor.frama_c_inplace

  val mutable res = ([] : stmt list)

  method add_current_stmt () =
    res <-  Extlib.the self#current_stmt :: res

  method! vinst i =
    begin match i with
      | Call (None,_,_,_) | Asm _ | Skip _ | Code_annot _ -> () (* No effect *)
      | Local_init(vi,_,_) ->
        if Cil_datatype.Varinfo.equal vi target_vi then
          self#add_current_stmt ()
      | Call (Some dest,_,_,_)
      | Set (dest,_,_) ->
        match dest with
        | Var vi, _ when vi = target_vi -> self#add_current_stmt ()
        | _ -> ()
    end;
    Cil.SkipChildren

  method result = res
end

let find_assignments kf vi =
  let fundec = Kernel_function.get_definition kf
  and vis = new find_write vi in
  ignore (Visitor.visitFramacFunction (vis :> Visitor.frama_c_visitor) fundec);
  vis#result

let compute lval =
  match lval with
  | Var vi, NoOffset when not vi.vaddrof ->
    Self.feedback "%a %B" Cil_printer.pp_varinfo vi vi.vaddrof;
    begin try
        let kf = Kernel_function.find_defining_kf vi in
        Extlib.opt_map (fun kf -> find_assignments kf vi) kf
      with Not_found -> None
    end
  | _ -> None
