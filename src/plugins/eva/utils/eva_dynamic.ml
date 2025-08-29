(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let get ~plugin name typ ~fallback =
  try Dynamic.get ~plugin name typ
  with Failure _ | Dynamic.(Unbound_value _ | Incompatible_type _) -> fallback

module Inout = struct
  let plugin = "inout"

  let register_call_hook f =
    let fallback _ = () in
    let typ = Datatype.(func (func Inout_type.ty unit) unit) in
    get ~plugin "register_call_hook" typ ~fallback f

  let fallback _ = Locations.Zone.top
  let typ arg = Datatype.func arg Locations.Zone.ty

  let kf_inputs kf =
    get ~plugin "kf_inputs" (typ Kernel_function.ty) ~fallback kf

  let kf_outputs kf =
    get ~plugin "kf_outputs" (typ Kernel_function.ty) ~fallback kf

  let stmt_outputs stmt =
    get ~plugin "stmt_outputs" (typ Cil_datatype.Stmt.ty) ~fallback stmt
end

module Callgraph = struct
  let plugin = "callgraph"

  let iter_in_rev_order f =
    let fallback = Globals.Functions.iter in
    (* callgraph is too slow on programs with too many callsites. *)
    if Function_calls.nb_callsites () > 20000
    then fallback f
    else
      let typ = Datatype.(func (func Kernel_function.ty unit) unit) in
      get ~plugin "iter_in_rev_order" typ ~fallback f
end

module Scope = struct
  let plugin = "scope"

  let rm_asserts () =
    let fallback () =
      Self.warning
        "The scope plugin is missing: cannot remove redundant alarms."
    in
    let typ = Datatype.(func unit unit) in
    get ~plugin "rm_asserts" typ ~fallback ()
end

module RteGen = struct
  let plugin = "RteGen"

  let all_statuses () =
    let kf = Kernel_function.ty in
    let typ =
      Datatype.(list (triple string (func2 kf bool unit) (func kf bool)))
    in
    get ~plugin "all_statuses" typ ~fallback:[]

  let mark_generated_rte () =
    let list = all_statuses () in
    let mark kf = List.iter (fun (_kind, set, _get) -> set kf true) list in
    Globals.Functions.iter
      (fun kf -> if Function_calls.is_called kf then mark kf)
end
