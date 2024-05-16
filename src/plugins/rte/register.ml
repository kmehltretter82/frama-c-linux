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

let _ignore =
  Dynamic.register
    ~comment:"Generate all RTE annotations in the given function."
    ~plugin:"RteGen"
    "do_all_rte"
    (Datatype.func Kernel_function.ty Datatype.unit)
    Api.do_all_rte

let _ignore =
  Dynamic.register
    ~comment:"The emitter used for generating RTE annotations"
    ~plugin:"RteGen"
    "emitter"
    Emitter.ty
    Generator.emitter

(* retrieve list of generated rte annotations for a given stmt *)
let _ignore =
  Dynamic.register
    ~comment:"Get the list of annotations previously emitted by RTE for the \
              given statement."
    ~plugin:"RteGen"
    "get_rte_annotations"
    (Datatype.func
       Cil_datatype.Stmt.ty
       (let module L = Datatype.List(Cil_datatype.Code_annotation) in L.ty))
    Generator.get_registered_annotations

let _ignore =
  Dynamic.register
    ~comment:"Generate RTE annotations corresponding to the given stmt of \
              the given function."
    ~plugin:"RteGen"
    "stmt_annotations"
    (Datatype.func2 Kernel_function.ty Cil_datatype.Stmt.ty
       (let module L = Datatype.List(Cil_datatype.Code_annotation) in L.ty))
    Visit.get_annotations_stmt

let _ignore =
  Dynamic.register
    ~comment:"Generate RTE annotations corresponding to the given exp \
              of the given stmt in the given function."
    ~plugin:"RteGen"
    "exp_annotations"
    (Datatype.func3 Kernel_function.ty Cil_datatype.Stmt.ty Cil_datatype.Exp.ty
       (let module L = Datatype.List(Cil_datatype.Code_annotation) in L.ty))
    Visit.get_annotations_exp

let _ignore =
  let kf = Kernel_function.ty in
  Dynamic.register
    ~plugin:"RteGen"
    "all_statuses"
    Datatype.(list (triple string (func2 kf bool unit) (func kf bool)))
    Generator.all_statuses

let main () =
  (* reset "rte generated" properties for all functions *)
  if Options.Enabled.get () then begin
    Options.feedback ~dkey:Options.dkey_annot ~level:2
      "generating annotations";
    Api.compute ();
    Options.feedback ~dkey:Options.dkey_annot ~level:2
      "annotations computed"
  end

let () = Boot.Main.extend main

(*
  Local Variables:
  compile-command: "make -C ../../.."
  End:
 *)
