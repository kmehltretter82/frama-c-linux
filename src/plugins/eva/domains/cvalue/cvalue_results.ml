(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Domain_store.Make (Cvalue.Model)

let is_reachable stmt =
  match get_stmt_state_by_callstack ~after:false stmt with
  | `Top -> true
  | `Bottom -> false
  | `Value h ->
    let exception Reachable in
    try
      let raise_if_reachable _cs state =
        if Cvalue.Model.is_reachable state then raise Reachable
      in
      Callstack.Hashtbl.iter raise_if_reachable h;
      false
    with Reachable -> true
