(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

open Either
open Lang.F
open Ctypes
open Cil_types
open Interpreted_automata
open Sigs


let rec partition_terminal_recursive f accl accr = function
  | [] -> (accl, accr)
  | c :: rest -> match f c with
    | Left  _ -> partition_terminal_recursive f (c::accl) accr rest
    | Right _ -> partition_terminal_recursive f accl (c::accr) rest

let partition (f: 'c -> ('a,'b) Either.t) (l:'c list) : 'c list * 'c list =
  partition_terminal_recursive f [] [] l

let rec split_terminal_recursive (accl : 'a list) (accr : 'b list) = function
  | [] -> (accl, accr)
  | (Left  l) :: rest -> split_terminal_recursive (l::accl) accr rest
  | (Right r) :: rest -> split_terminal_recursive accl (r::accr) rest

let split l = split_terminal_recursive [] [] l


module type Dispatcher =
sig

  type loc_left
  type loc_right

  module ML : Sigs.Model with type loc = loc_left
  module MR : Sigs.Model with type loc = loc_right

  type loc = (loc_left, loc_right) Either.t

  val null : loc
  val is_null : loc -> pred
  val cvar : varinfo -> loc
  val pointer_loc : QED.term -> loc
  val loc_of_int : c_object -> QED.term -> loc

  val deref_left  : loc_left  -> loc_left  -> loc
  val deref_right : loc_right -> loc_right -> loc
  val literal : eid:int -> Cstring.cst -> loc


  (* utilities *)
  val hypotheses : MemoryContext.partition -> MemoryContext.partition
  val configure_ia: automaton -> vertex binder

end


module CollectionCObject = Qed.Collection.Make(struct
    type t      = Ctypes.c_object
    let compare = Ctypes.compare
    let hash    = Ctypes.hash
    let equal   = Ctypes.equal
  end)


module TySet = CollectionCObject.Set

module RegionAssociator = struct
  (* Data : WpContext.Data with type key = Key.t *)
  type model = Typed | Bytes
  type key = Region.node
  type data = model
  let name = "WP.Dispatcher.RegionDispatch"
  let rec compile (region:Region.node) : model =
    let kf =
      match snd @@ WpContext.get_context () with
      | Global -> raise Not_found
      | Kf f -> f
    in
    let map = Region.get_map kf in
    (* a. if access types are different (c_object), then memBytes *)
    let add_type set ty = TySet.add (Ctypes.object_of ty) set in
    let types = TySet.empty in
    let types = List.fold_left add_type types @@ Region.reads map region in
    let types = List.fold_left add_type types @@ Region.writes map region in
    let types = List.fold_left add_type types @@ Region.shifts map region in
    if List.length @@ TySet.elements types > 1 then Bytes else
      (* b. if access type is aggregate with a union inside, then memBytes *)
      let rec is_aggregate_with_union (ty:c_object) : bool =
        match ty with
        | C_int _ | C_float _ | C_pointer _ -> false
        | C_comp compinfo ->
          if compinfo.cstruct then true
          else begin match compinfo.cfields with
            | None -> false
            | Some l -> List.exists (fun field -> is_aggregate_with_union @@ C_comp field.fcomp) l
          end
        | C_array arrayinfo -> is_aggregate_with_union (object_of arrayinfo.arr_element)
      in
      if TySet.exists is_aggregate_with_union types then Bytes else
        (* c. if at least one of the pointed_by regions is memBytes, then memBytes *)
        let pointed_by = Region.pointed_by map region in
        let model_is_memBytes r = Bytes == compile r in
        if List.exists model_is_memBytes pointed_by then Bytes else
          (* d. otherwise if none of the above, then memTyped *)
          Typed
end


module Make (ML: Sigs.Model) (MR: Sigs.Model) : Dispatcher =
struct
  type loc_left  = ML.loc
  type loc_right = MR.loc

  module ML = ML (* intended to be MemTyped *)
  module MR = MR (* intended to be MemBytes *)

  type loc = (loc_left, loc_right) Either.t

  (** Internal handling of regions *)
  (* Keeping track of the decision to apply which memory model to each region *)
  module RegionDispatch = WpContext.Generator
      (struct
        (* Key : WPContext.Key *)
        type t = Region.node
        let compare a b = Int.compare (Region.get_id a) (Region.get_id b)
        let pretty fmt r = Format.fprintf fmt "R%03d" (Region.get_id r)
      end)
      (RegionAssociator)


  (** Public API of Dispatch *)

  let null = Left ML.null
  let is_null = function
    | Left  ll -> ML.is_null ll
    | Right lr -> MR.is_null lr

  let cvar (var:varinfo) : loc = (* TODO *)
    let f : kernel_function =
      match snd @@ WpContext.get_context () with
      | Global -> raise Not_found
      | Kf f -> f
    in
    let map_regions = Region.get_map f in
    let region = Region.cvar map_regions var in
    match RegionDispatch.get region with
    | RegionAssociator.Typed -> Left  (ML.cvar var)
    | RegionAssociator.Bytes -> Right (MR.cvar var)


  let pointer_loc term =
    let region = assert false in
    match RegionDispatch.get region with
    | RegionAssociator.Typed -> Left  (ML.pointer_loc term)
    | RegionAssociator.Bytes -> Right (MR.pointer_loc term)

  let loc_of_int _ty _term = (* TODO *) null

  let literal ~eid:_eid _const = (* TODO *) null

  let deref_left  _ll1 ll2 = (* TODO *) Left  ll2
  let deref_right _lr1 lr2 = (* TODO *) Right lr2


  let hypotheses partition = partition
  let configure_ia automata = (* TODO *)
    ML.configure_ia automata

end


(*
module MultiModuleDispatcher = struct

  module Models = struct
    (** Encoding indexes as types (not as integers) *)
    type    z = Z       (** Zero *)
    type 'a s = S of 'a (** Successor function *)

    (** Elements from the list,
        a  [n multiloc] corresponds to the type [loc] of the module at index [n] *)
    type _ multiloc = ..


    (** Index aware module type *)
    module type IndexAware_SigsModel = sig
      include Sigs.Model
      type pos
      val to_multiloc : loc -> pos multiloc
      val of_multiloc : pos multiloc -> loc
    end

    (** Index aware list type *)
    type 'pos indexAware_list =
      | Nil: z indexAware_list
      | Cons:
          'pos indexAware_list * (module IndexAware_SigsModel with type pos = 'pos) ->
          'pos s indexAware_list

    (** Wrapper for the list with its size *)
    module type SizeAware_List = sig
      type size
      val model_list : size indexAware_list
      val get : int -> (module Sigs.Model)
    end

    (** The list is stored as a mutable reference *)
    let model_list = ref (module struct
      type size = z
      let model_list = Nil
      let get _ = raise Not_found
    end:SizeAware_List)

    (** Add a module to the list *)
    let add_model (module Model : Sigs.Model) =
      let module L = (val !model_list) in
      model_list := (module struct
        (* Create a new constructor for model at position size *)
        type _ multiloc += Loc : Model.loc -> L.size multiloc
        type size = L.size s (* New size of list *)

        let model_list = Cons(L.model_list,
          (module struct
            include Model
            type pos = L.size
            let to_multiloc x = Loc x
            let of_multiloc = function
              | Loc x -> x
              | _ -> raise (Invalid_argument "Dispatcher.MultiDispatcher.Models: Dynamic typing error")
          end))
        let get = function
        | 0 -> (module Model:Sigs.Model)
        | n when n < 0 -> raise Not_found
        | n -> L.get (n-1)
      end)

      type 'a index =
      | Zero of z
      | Succ of 'a index s

      (* (* the following is not typing... even though it would be more efficient *)
      let rec get (index: _ index) (models: 'c indexAware_list) : (module Sigs.Model) =
        begin match (index, models) with
         | (Zero Z, Cons ((_rest : _ indexAware_list), model)) -> model
         | (Succ (S index'), Cons ((rest : _ indexAware_list), (module _model : IndexAware_SigsModel))) ->
          get index' rest
        end
        *)

    (*
      (* make type elt private here *)

      let () = add_model (module Int)
      let () = add_model (module Bool)
      let () = add_model (module Char)
    *)
  end
end
*)
