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
module Fmap = Fieldinfo.Map

type 'a t =
  | Pure
  | Ptr    of 'a
  | Array  of 'a t (* no pure *)
  | Record of 'a t Fmap.t (* not all pure *)
  | Logic  of logic_type_info * 'a t list (* not all pure *)

(* -------------------------------------------------------------------------- *)
(* ---  Printer                                                           --- *)
(* -------------------------------------------------------------------------- *)

let rec pretty pp fmt = function
  | Pure -> Format.pp_print_string fmt "_"
  | Ptr r -> pp fmt r
  | Array d -> pretty pp fmt d ; Format.pp_print_string fmt "[]"
  | Record m ->
    Format.fprintf fmt "@[<hov 0>@[<hov 2>{" ;
    Fmap.iter
      (fun fd d ->
         Format.fprintf fmt "@ %a: %a;" Fieldinfo.pretty fd (pretty pp) d
      ) m ;
    Format.fprintf fmt "@]@ }@]"
  | Logic(a,[]) -> Logic_type_info.pretty fmt a
  | Logic(a,d::ds) ->
    Format.fprintf fmt "@[<hov 2>%a<%a" Logic_type_info.pretty a (pretty pp) d ;
    List.iter (Format.fprintf fmt ",@,%a" (pretty pp)) ds ;
    Format.fprintf fmt ">@]"

(* -------------------------------------------------------------------------- *)
(* ---  Smart constructors                                                --- *)
(* -------------------------------------------------------------------------- *)

let is_pure d = (d == Pure)
let pure = Pure
let ptr r = Ptr r
let scalar = function None -> Pure | Some r -> Ptr r
let array d = if d == Pure then Pure else Array d
let field fd d = if d == Pure then Pure else Record (Fmap.singleton fd d)

let logic s l =
  if Logic_const.is_unrollable_ltdef s then invalid_arg "Region.LDomain.logic"
  else if List.for_all is_pure l then Pure
  else Logic (s,l)

(* -------------------------------------------------------------------------- *)
(* ---  Merge                                                             --- *)
(* -------------------------------------------------------------------------- *)

let rec collect f w = function
  | Pure -> w
  | Ptr r -> Some (match w with None -> r | Some r0 -> f r0 r)
  | Array d -> collect f w d
  | Record m -> Fmap.fold (fun _ d w -> collect f w d) m w
  | Logic(_,ds) -> List.fold_left (collect f) w ds

let pointed f d = collect f None d

let rec merge f d1 d2 =
  match d1, d2 with
  | Pure, d | d, Pure -> d
  | Ptr r1, Ptr r2 -> Ptr (f r1 r2)
  | Record m1, Record m2 ->
    Record (Fmap.union (fun _ d1 d2 -> Some (merge f d1 d2)) m1 m2)
  | Array d1, Array d2 -> Array (merge f d1 d2)
  | Logic (a1, ds1), Logic (a2, ds2) when Logic_type_info.equal a1 a2 ->
    Logic (a1, List.map2 (merge f) ds1 ds2)
  | _ -> scalar @@ collect f (collect f None d1) d2

(* -------------------------------------------------------------------------- *)
(* ---  Getters                                                           --- *)
(* -------------------------------------------------------------------------- *)

let get f = function Pure | Ptr _ as d -> d | d -> scalar @@ pointed f d

let get_index f = function Array d -> d | d -> get f d

let get_field f d fd =
  match d with
  | Record mf -> (try Fmap.find fd mf with Not_found -> Pure)
  | _ -> get f d

let of_ltype _create _lty = assert false

(* -------------------------------------------------------------------------- *)
