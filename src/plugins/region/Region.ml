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

(* -------------------------------------------------------------------------- *)
(* --- Region Analysis API                                                --- *)
(* -------------------------------------------------------------------------- *)


open Cil_types

type region = Memory.region

module R : Qed.Collection.S with type t = region =
  Qed.Collection.Make(struct
    type t = region
    let hash r = Memory.id r.Memory.node
    let equal r1 r2 = (hash r1 == hash r2)
    let compare r1 r2 = (hash r1) - (hash r2)
  end)


type map = Code.domain
let get_map (f:kernel_function) : map = Code.domain f

(** @raise Not_found *)
let cvar (map:map) (var:varinfo) : region =
  Memory.region map.map (Memory.lval map.map ((Var var), NoOffset))

let field (map:map) (region:region) (field:fieldinfo) : region =
  Memory.region map.map (Memory.offset map.map region.node (Field (field, NoOffset)))

let index (_:map) (_:region) (_:typ) : region = (* TODO *) raise Not_found

(*
let region_of_ptr_term (map:map) (ptr:term) : region =
  match ptr.term_node with
  (* same constructs as exp *)
  | TConst _ | TLval _| TSizeOf _| TSizeOfE _ | TSizeOfStr _ | TAlignOf _
  | TAlignOfE _ | TUnOp _ | TBinOp _ | TCast _ ->
    begin match Memory.exp map.map @@ Logic_to_c.term_to_exp ptr with
      | None -> raise Not_found
      | Some node -> Memory.region map.map node
    end
  | TAddrOf term_lval ->
    Memory.region map.map @@ Memory.lval map.map @@ Logic_to_c.term_lval_to_lval term_lval
  | TStartOf term_lval ->
    Memory.region map.map @@ Memory.lval map.map @@ Logic_to_c.term_lval_to_lval term_lval
  (* additional constructs *)
  | Tapp _            -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tapp")
  | Tlambda _         -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tlambda")
  | TDataCons _       -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: TDataCons")
  | Tif _             -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tif")
  | Tat _             -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tat")
  (* logic_label * term  *)
  | Tbase_addr _      -> (* TODO *) raise Not_found
  | Toffset _         -> (* TODO *) raise Not_found
  | Tblock_length _   -> (* TODO *) raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tblock_length")
  | Tnull             -> (* TODO *) raise Not_found
  | TUpdate _         -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: TUpdate")
  | Ttypeof _         -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Ttypeof")
  | Ttype _           -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Ttype")
  | Tempty_set        -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tempty_set")
  | Tunion _          -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tunion")
  | Tinter _          -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tinter")
  | Tcomprehension _  -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tcomprehension")
  | Trange _          -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Trange")
  | Tlet _            -> raise (Invalid_argument "Region:Region.ml:region_of_ptr_term: Tlet")
*)

let points_to (map:map) (region:region) : region option =
  Option.map (Memory.region map.map) @@ Memory.cpointed map.map region.Memory.node

let pointed_by (map:map) (region:region) : region list =
  List.map (Memory.region map.map) @@ Memory.cpointed_by map.map region.Memory.node


let iter (map:map) (f:region -> unit) : unit =
  Memory.iter map.map f


let pp_region fmt region : unit = Memory.pp_region fmt region




type acs = {
  acs_read  : typ list;
  acs_write : typ list;
  acs_shift : typ list;
}
let empty_acs = {
  acs_read  = [];
  acs_write = [];
  acs_shift = [];
}

let accesses (region:region) : acs =
  {
    acs_read  = List.map Access.typeof region.Memory.reads ;
    acs_write = List.map Access.typeof region.Memory.writes ;
    acs_shift = List.map Access.typeof region.Memory.shifts ;
  }
