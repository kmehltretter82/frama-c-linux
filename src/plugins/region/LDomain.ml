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
open Cil_datatype


type 'a t =
  | Pure
  | Ptr    of 'a
  | Record of 'a t Fieldinfo.Map.t
  | Array  of 'a t
  | Logic  of logic_type_info (* uniquement abstrait *) * 'a t list

(* -------------------------------------------------------------------------- *)
(* ---  Smart constructors                                                --- *)
(* -------------------------------------------------------------------------- *)

let pure = Pure

let field fd = function
  | Pure -> Pure
  | d -> Record (Fieldinfo.Map.singleton fd d)

let array = function
  | Pure -> Pure
  | d -> Array d
let ptr r = Ptr r

let logic s l =
  if Logic_const.is_unrollable_ltdef s then invalid_arg "Region.LDomain.logic"
  else if List.for_all (fun d -> d = Pure) l then Pure
  else Logic (s,l)

let rec iter f = function
  | Pure -> ()
  | Ptr r -> f r
  | Record mf -> Fieldinfo.Map.iter (fun _ -> iter f) mf
  | Array d -> iter f d
  | Logic (_, ds) -> List.iter (iter f) ds

(* -------------------------------------------------------------------------- *)
(* ---  Merge                                                             --- *)
(* -------------------------------------------------------------------------- *)

let rec merge f d1 d2 =
  match d1, d2 with
  | Pure, d | d, Pure -> d
  | Ptr r1, Ptr r2 -> Ptr (f r1 r2)
  | Record mf1, Record mf2 ->
    let merge_field_maps _ dom1 dom2 = Some (merge f dom1 dom2)
    in Record (Fieldinfo.Map.union merge_field_maps mf1 mf2)
  | Array d1, Array d2 -> Array (merge f d1 d2)
  | Logic (s1, args1), Logic (s2, args2)
    when Logic_type_info.equal s1 s2 ->
    Logic (s1, List.map2 (merge f) args1 args2)
  (* default case: incompatible domains raise an exception *)
  | Ptr _, (Record _| Array _ | Logic _) | (Record _| Array _ | Logic _), Ptr _
  | Record _, (Array _| Logic _) | (Array _| Logic _), Record _
  | Array _, Logic _ | Logic _, Array _
  | Logic _, Logic _ ->
    let ret = ref Pure in
    let add = iter (fun r -> ret := merge f (Ptr r) (!ret)) in
    add d1 ; add d2 ; !ret

let scratch f d =
  let ret = ref Pure in
  let add = iter (fun r -> ret := merge f (Ptr r) (! ret)) in
  add d ; ! ret

(* -------------------------------------------------------------------------- *)
(* ---  Getters                                                           --- *)
(* -------------------------------------------------------------------------- *)

let get_field f d fd = match d with
  | Record mf when Fieldinfo.Map.mem fd mf -> Fieldinfo.Map.find fd mf
  | d -> scratch f d

let get_index f = function
  | Array d -> d
  | d -> scratch f d
