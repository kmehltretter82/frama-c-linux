(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
open MtTypes
open MtIds
open MtThread
open MtCfgTypes
open MtMutexesTypes

(* -------------------------------------------------------------------------- *)
(* --- Checking that concurrent variables accesses are properly protected --- *)
(* -------------------------------------------------------------------------- *)


let mutexes_protecting_zones' accesses =
  let aux (z, set) =
    SetNodeIdAccess.fold
      (fun (rw, node, _id) acc ->
         let mutexes = node.cfgn_context.locked_mutexes in
         let mut = match rw with
           | Read -> { mutexes_for_write = Unaccessed;
                       mutexes_for_read = Mutexes mutexes }
           | Write _ -> { mutexes_for_read = Unaccessed;
                          mutexes_for_write = Mutexes mutexes }
         in
         MutexesByZone.add_binding ~exact:false acc z mut
      ) set MutexesByZone.empty
  in
  let r1 = List.map aux accesses in
  let z = List.fold_left
      (fun r r' -> MutexesByZone.join r r') MutexesByZone.empty r1
  in z


(* Pretty a value of type [MtSharedVars.Precise.list_accesses]
   with the mutex information at each node concatenated to the output *)
let pretty_with_mutexes =
  MtSharedVars.Precise.pretty_concurrent_accesses
    ~f:(fun fmt (_, node, _) ->
        let mutexes = node.cfgn_context.locked_mutexes in
        if Presence.is_empty mutexes then
          Format.fprintf fmt ",@ unprotected"
        else
          Format.fprintf fmt ",@ @[<hov>protected by %a@]"
            Presence.pretty mutexes ;
        if MtOptions.PrintCallstacks.get ()
        then Format.fprintf fmt ",@ // %a" Callstack.pretty node.cfgn_stack
      ) ();
;;

type protection = Unprotected | Priority | Protected of Id.Set.t

let pretty_protection fmt = function
  | Unprotected -> Format.fprintf fmt "unprotected"
  | Priority -> Format.fprintf fmt "protected by priorities"
  | Protected set ->
    Format.fprintf fmt "@[<hov 2>protected by %a@]"
      (Pretty_utils.pp_iter Id.Set.iter Id.pretty) set

let pretty_protection_per_thread fmt (th_read, th_write, protection) =
  Format.fprintf fmt "@[<hov 2>Read by %a,@ Write by %a:@ %a@]"
    Id.pretty th_read.th_id Id.pretty th_write.th_id
    pretty_protection protection

type zone_protection =
  (Locations.Zone.t * (MtThread.thread * MtThread.thread * protection) list) list

let pretty_zone_protection fmt (z, l) =
  Format.fprintf fmt "@[<hv 2>@[%a@]:@ %a@]"
    Locations.Zone.pretty z
    (Pretty_utils.pp_list ~pre:"" ~suf:"" pretty_protection_per_thread) l

let check_protection analysis (l: MtSharedVars.Precise.list_accesses) : zone_protection =
  let aux (z, s) =
    let m_read = ref Id.Map.empty in
    let m_write = ref Id.Map.empty in
    (* YYY: we disregard information about accesses that may not be possibly
       simultaneous *)
    let add id node map =
      let mutexes' = Presence.only_present node.cfgn_context.locked_mutexes in
      try
        let mutexes = Id.Map.find id map in
        let inter = Id.Set.inter mutexes mutexes' in
        Id.Map.add id inter map
      with Not_found -> Id.Map.add id mutexes' map
    in
    let aux_nodes (op, n, thid) =
      match op with
      | Read ->    m_read  := add thid n !m_read
      | Write _ -> m_write := add thid n !m_write
    in
    SetNodeIdAccess.iter aux_nodes s;
    let classify_access id_read read id_write write classified =
      if not (Id.equal id_read id_write) then begin
        let th_read = MtThread.thread_of_id analysis id_read in
        let th_write = MtThread.thread_of_id analysis id_write in
        let protection =
          match th_read.th_priority, th_write.th_priority with
          | PPriority p1, PPriority p2 when p1 > p2 ->
            (* Protection by mutexes not needed, th_read cannot be preempted *)
            Priority
          | _ ->
            let both_mutexes = Id.Set.inter read write in
            if Id.Set.is_empty both_mutexes
            then Unprotected
            else Protected both_mutexes
        in
        (th_read, th_write, protection) :: classified
      end
      else classified
    in
    let protections =
      Id.Map.fold (fun id_read read acc ->
          Id.Map.fold (fun id_write write acc ->
              classify_access id_read read id_write write acc
            ) !m_write acc
        ) !m_read []
    in
    (z, protections)
  in
  List.map aux l

let pretty_protections fmt l =
  Pretty_utils.pp_list
    ~pre:"@[<v>" ~suf:"@]" ~sep:"@ " pretty_zone_protection fmt l

let ill_protected (accesses: MtSharedVars.Precise.list_accesses) (protections: zone_protection) =
  let res = Cil_datatype.Stmt.Hashtbl.create 16 in
  let aux (z, nodes) (z', protections) =
    assert (z == z');
    let aux (th_read, _th_write, protect) =
      if protect = Unprotected then
        let aux (op, node, thid) =
          if Id.equal thid th_read.th_id && op = Read then begin
            let stmts = CfgNode.node_stmt node in
            let aux stmt =
              let prev =
                try Cil_datatype.Stmt.Hashtbl.find res stmt
                with Not_found -> Locations.Zone.bottom
              in
              let z = Locations.Zone.join prev z in
              Cil_datatype.Stmt.Hashtbl.replace res stmt z
            in
            List.iter aux stmts
          end
        in
        SetNodeIdAccess.iter aux nodes
    in
    List.iter aux protections
  in
  List.iter2 aux accesses protections;
  res

let need_sync stmtsh =
  let aux stmt z acc =
    (* YYY: detection should be improved to handle unspecified sequences. *)
    match stmt.preds with
    | [stmt] when MtCil.is_call_to_sync stmt -> acc
    | _ -> (stmt, z) :: acc
  in
  Cil_datatype.Stmt.Hashtbl.fold aux stmtsh []
