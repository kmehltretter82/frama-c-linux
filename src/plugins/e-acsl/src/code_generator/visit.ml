(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2019                                               *)
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

(* ************************************************************************** *)
(* Visitor *)
(* ************************************************************************** *)

(* the main visitor performing e-acsl checking and C code generator *)
class e_acsl_visitor prj generate = object (self)

  inherit Visitor.generic_frama_c_visitor
    (if generate then Visitor_behavior.copy prj else Visitor_behavior.inplace ())

  (* Add mappings from global variables to their initializers in [global_vars].
     Note that the below function captures only [SingleInit]s. All compound
     initializers containing SingleInits (except for empty compound
     initializers) are unrapped and thrown away. *)
  method !vinit vi off _ =
    if generate then
      if Mmodel_analysis.must_model_vi vi then begin
        is_initializer <- vi.vglob;
        Cil.DoChildrenPost
          (fun i ->
            (match is_initializer with
            | true ->
              (match i with
              | CompoundInit(_,[]) ->
                (* Case of an empty CompoundInit, treat it as if there were
                   no initializer at all *)
                ()
              | CompoundInit(_,_) | SingleInit _ ->
                (* TODO: [off] should be the one of the new project while it is
                   from the old project *)
                Global_observer.add_initializer vi off i)
            | false-> ());
            is_initializer <- false;
          i)
      end else
        Cil.JustCopy
    else
      Cil.SkipChildren

end

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
