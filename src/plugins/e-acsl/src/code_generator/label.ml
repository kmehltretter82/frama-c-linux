(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

(* The keys are the stmts which were previously labeled, whereas the associated
   values are the new stmts containing the same labels. *)
module Labeled_stmts =
  Cil_state_builder.Stmt_hashtbl
    (Cil_datatype.Stmt)
    (struct
      let size = 7
      let dependencies = [] (* delayed *)
      let name = "E-ACSL.Labels"
    end)

let self = Labeled_stmts.self

let move kf ~old new_stmt =
  let labels = old.labels in
  match labels with
  | [] -> ()
  | _ :: _ ->
    old.labels <- [];
    new_stmt.labels <- labels @ new_stmt.labels;
    Labeled_stmts.add old new_stmt;
    (* move annotations from the old labeled stmt to the new one *)
    let l = Annotations.fold_code_annot (fun e ca l -> (e, ca) :: l) old [] in
    List.iter
      (fun (e, ca) ->
         Annotations.remove_code_annot ~kf e old ca;
         Annotations.add_code_annot ~keep_empty:false ~kf e new_stmt ca)
      l;
    (* update the gotos of the function jumping to one of the labels *)
    let f =
      try Kernel_function.get_definition kf
      with Kernel_function.No_Definition -> assert false
    in
    let mv_label s = match s.skind with
      | Goto(s_ref, _) when Cil_datatype.Stmt.equal !s_ref old ->
        s_ref := new_stmt
      | _ -> ()
    in
    List.iter mv_label f.sallstmts

let get_stmt kf llabel =
  let stmt = match llabel with
    | StmtLabel { contents = stmt } -> stmt
    | BuiltinLabel Here -> Error.not_yet "Label 'Here'"
    | BuiltinLabel(Old | Pre) ->
      (try Kernel_function.find_first_stmt kf
       with Kernel_function.No_Statement -> assert false)
    | BuiltinLabel(Post) ->
      (try Kernel_function.find_return kf
       with Kernel_function.No_Statement -> assert false)
    | BuiltinLabel _ | FormalLabel _ -> assert false
  in
  (* the pointed statement has been visited and modified by the injector:
     get its new version. *)
  try Labeled_stmts.find stmt with Not_found -> stmt

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
