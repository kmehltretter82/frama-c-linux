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

open MtUtils

type value = Cvalue.V.t
type thread = Thread.t


let return_lval thread =
  let kf = Thread.entry_point thread in
  Option.map Eva_ast.Build.var (Library_functions.get_retres_vi kf)

module Thread =
struct
  include Thread
  let name = "MtThread.Thread"
  let key_name = "thread"
  let of_value x =
    let open Result.Operators in
    let* l = Value.to_int_list x in
    let convert_one acc id =
      let* acc = acc in
      match find id with
      | None -> Result.error "Not a valid thread id '%d'." id
      | Some th -> Result.ok (th :: acc)
    in
    List.fold_left convert_one (Result.ok []) l
  let to_value th = Value.of_int (id th)
end



type status = { running : Trilean.t ; canceled : Trilean.t }
module Status = struct
  include Datatype.Make (struct
      type t = status
      let name = "Mthread.thread.status"
      let reprs = [ { running = False ; canceled = False } ]
      let copy = Datatype.identity
      let rehash = Datatype.identity
      let mem_project = Datatype.never_any_project

      let structural_descr =
        let running = Datatype.Bool.packed_descr in
        let canceled = Trilean.packed_descr in
        Structural_descr.t_record [| running ; canceled |]

      let pretty fmt { running ; canceled } =
        Format.fprintf fmt "Running : %a@.Canceled : %a@."
          Trilean.pretty running Trilean.pretty canceled

      let compare l r =
        Trilean.compare l.running r.running
        <?> lazy (Trilean.compare l.canceled r.canceled)

      let equal l r = compare l r = 0
      let hash t = Trilean.hash t.running + 3 * Trilean.hash t.canceled
    end)

  (* let top = { running = Unknown ; canceled = Unknown } *)

  let is_included l r =
    Trilean.is_included l.running r.running
    && Trilean.is_included l.canceled r.canceled

  let join l r =
    let running = Trilean.join l.running r.running in
    let canceled = Trilean.join l.canceled r.canceled in
    { running ; canceled }

  let default = { running = False ; canceled = False }
end



module Register = struct
  include MtRegister.Make (Thread) (Status)

  let change_running running msg =
    let new_status status = { status with running } in
    update new_status @@ fun { running=previous } ->
    if Trilean.intersects running previous
    then Invalid (msg, Trilean.equal running previous)
    else Ok

  let start = change_running True "running"
  let suspend = change_running False "suspended"
  let cancel = update (fun s -> { s with canceled = True }) (fun _ -> Ok)
end
