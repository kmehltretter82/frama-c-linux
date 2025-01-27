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

type errors =
  | AlreadyRegistered
  | NotRegistered
  | MayBeInState of (string * bool)

type update_check = Ok | Invalid of (string * bool)


module type Key_sig = sig
  include Hptmap.Id_Datatype
  val key_name : string
  val of_value : Value.t -> t list Result.t
  val to_value : t -> Value.t
end


module type Status_sig = sig
  include Lattice_type.Join_Semi_Lattice
  val default : t
end


module Make (Key : Key_sig) (Status : Status_sig) = struct
  open Result

  module Info = struct
    let initial_values = [ ]
    let dependencies = [ Ast.self ]
  end
  include Hptmap.Make (Key) (Status) (Info)
  let cache_name s = Hptmap_sig.PersistentCache (name ^ "." ^ s)
  let find key map = try Some (find key map) with Not_found -> None

  type status = Status.t
  type key = Key.t

  let warning key register = function
    | AlreadyRegistered ->
      Result.warning (register, Key.to_value key)
        "The %s %a is already registered."
        Key.key_name Key.pretty key
    | NotRegistered ->
      (* Temporary: do not emit warning when a key has not been registered.
         As Mthread does not inject the initial domain state at the start
         of a thread analysis, this is bound to happen (for now). *)
      if true
      then Result.ok (register, Value.of_int 1)
      else
        Result.warning (register, Value.of_int 1)
          "The %s %a is not registered."
          Key.key_name Key.pretty key
    | MayBeInState (state, sure) ->
      Result.warning (register, Value.of_int 2)
        "The %s %a %s already %s."
        Key.key_name Key.pretty key
        (if sure then "is" else "may be") state

  let fold_keys f keys register =
    let f' acc key =
      let open Result in
      let* (register, result) = acc in
      let+ register, result' = f key register in
      register, Value.join result' result
    in
    List.fold_left f' (Result.ok (register, Value.bottom)) keys

  let register keys register =
    let register_one key register =
      if not (mem key register)
      then Result.ok (add key Status.default register, Key.to_value key)
      else warning key register AlreadyRegistered
    in
    fold_keys register_one keys register

  let update new_status check keys_value register =
    let update_one key register =
      match find key register with
      | None ->
        let+ (register, result) = warning key register NotRegistered in
        let register = add key (new_status Status.default) register in
        register, result
      | Some status ->
        let register = add key (new_status status) register in
        match check status with
        | Ok -> Result.ok (register, Value.zero)
        | Invalid reason -> warning key register (MayBeInState reason)
    in
    let open Result in
    let* keys = Key.of_value keys_value in
    fold_keys update_one keys register

  (* If a key is not in the register, we consider that it may be unregistered
     from the point of view of the partial order. It means that the empty map is
     the top element. *)
  let top = empty

  let is_included =
    let cache = cache_name "is_included" in
    let decide_fst _b _l = true  (* r is top *) in
    let decide_snd _b _r = false (* l is top *) in
    let decide_both _ l r = Status.is_included l r in
    let decide_fast s t = if s == t then PTrue else PUnknown in
    binary_predicate cache UniversalPredicate
      ~decide_fast ~decide_fst ~decide_snd ~decide_both

  (* Over-approximation of the narrow of two registers. Keys registered on
     each sides are all kept. However, we are conservative on their status. *)
  let narrow =
    let cache = cache_name "narrow" in
    let decide _ x y = Status.join x y in
    join ~cache ~symmetric:true ~idempotent:true ~decide

  (* Join of two registers. It only keeps keys registered on both sides and
     their statuses are joined. *)
  let join =
    let cache = cache_name "join" in
    let decide _ x y = Some (Status.join x y) in
    inter ~cache ~symmetric:true ~idempotent:true ~decide
end
