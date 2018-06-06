(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

(* Utility function on options *)
let opt_flatten (type a) (o : a option option) : a option =
  Extlib.opt_conv None o

module ExpMap = Cil_datatype.ExpStructEq.Map
module IList = Datatype.List (Datatype.Int)

type branch = int

type key = {
  ration_stamp : int option;
  transfer_stamp : int option;
  branches : branch list;
  loops : int list;
  static_split : Integer.t ExpMap.t;
  dynamic_split : Integer.t ExpMap.t;
}

module Key =
struct
  type t = key

  let compare k1 k2 =
    let (<?>) c (cmp,x,y) =
      if c = 0 then cmp x y else c
    in
    Extlib.opt_compare (-) k1.ration_stamp k2.ration_stamp
    <?> (Extlib.opt_compare (-), k1.transfer_stamp, k2.transfer_stamp)
    <?> (IList.compare, k1.loops, k2.loops)
    <?> (ExpMap.compare Integer.compare, k1.static_split, k2.static_split)
    <?> (ExpMap.compare Integer.compare, k1.dynamic_split, k2.dynamic_split)
    <?> (IList.compare, k1.branches, k2.branches)
end

module KMap = Map.Make (Key)


type 'a partition = 'a KMap.t

type action =
  | Enter_loop
  | Leave_loop
  | Incr_loop of int
  | Branch of branch * int
  | Ration of int
  | Ration_merge of int option
  | Transfer_merge
  | Static_split of Cil_types.exp
  | Dynamic_split of Cil_types.exp
  | Static_merge of Cil_types.exp
  | Dynamic_merge of Cil_types.exp
  | Update_dynamic_splits

exception InvalidAction


module type InputDomain =
sig
  type t

  exception Cant_split

  val join : t -> t -> t
  val split : t -> Cil_types.exp -> (Integer.t * t) list
end


module Make (Domain : InputDomain) =
struct
  type t = Domain.t partition
  type state = Domain.t

  let empty : 'a partition =
    KMap.empty

  let empty_key : key = {
    ration_stamp = None;
    transfer_stamp = None;
    branches = [];
    loops = [];
    static_split = ExpMap.empty;
    dynamic_split = ExpMap.empty;
  }

  let is_empty (p : 'a partition) : bool =
    KMap.is_empty p

  let initial (l : 'a list) : 'a partition =
    let stamp = ref 0 in
    let add p state =
      let k = { empty_key with ration_stamp = Some !stamp } in
      incr stamp;
      KMap.add k state p
    in
    List.fold_left add KMap.empty l

  let add (p : t) (k : key) (x : state) : t =
    (* Join states with the same key *)
    let x =
      try
        Domain.join (KMap.find k p) x
      with Not_found -> x
    in
    KMap.add k x p

  let add_list (p : t) (l : (key * state) list) : t =
    List.fold_left (fun p (k,x) -> add p k x) p l

  let split_state ~(static : bool) (exp : Cil_types.exp)
      (key : key) (state : state) : (key * state) list =
    try
      let update_key (v,x) =
        let k =
          if static then
            { key with static_split = ExpMap.add exp v key.static_split }
          else
            { key with dynamic_split = ExpMap.add exp v key.dynamic_split }
        in
        (k,x)
      in
      List.map update_key (Domain.split state exp)
    with Domain.Cant_split ->
      [(key,state)]

  let split ~(static : bool) (p : t) (exp : Cil_types.exp) =
    let add_split key state p =
      add_list p (split_state ~static exp key state)
    in
    KMap.fold add_split p KMap.empty

  let update_dynamic_splits p =
    (* Update one state *)
    let update_state key state p =
      (* Split the states in the list l for the given exp *)
      let update_exp exp _ l =
        let static = false in
        List.fold_left (fun l (k,s) -> split_state ~static exp k s @ l) [] l
      in
      (* Foreach exp in original state: split *)
      let l = ExpMap.fold update_exp key.dynamic_split [(key,state)] in
      add_list p l
    in
    KMap.fold update_state p KMap.empty

  let map_keys (f : key -> key) (p : t) =
    KMap.fold (fun k x acc -> add acc (f k) x) p empty

  let transfer_keys p = function
    | Static_split exp ->
      split ~static:true p exp

    | Dynamic_split exp ->
      split ~static:false p exp

    | Update_dynamic_splits ->
      update_dynamic_splits p

    | action -> (* Simple map transfer functions *)
      let transfer = match action with
        | Static_split _ | Dynamic_split _ | Update_dynamic_splits ->
          assert false (* Handled above *)

        | Enter_loop -> fun k ->
          { k with loops = 0 :: k.loops }

        | Leave_loop -> fun k ->
          begin match k.loops with
          | [] -> raise InvalidAction
          | _ :: tl -> { k with loops = tl }
          end

        | Incr_loop limit -> fun k ->
          begin match k.loops with
          | [] -> raise InvalidAction
          | h :: tl ->
            if h >= limit then
              k
            else
              { k with loops = h + 1 :: tl }
          end

        | Branch (b,max) -> fun k ->
          let list_start l i =
            let rec aux acc i = function
              | [] -> acc
              | _ when i <= 0 -> List.rev acc
              | x :: l -> aux (x :: acc) (i - 1) l
            in
            aux [] i l
          in
          if max > 0 then
            { k with branches = b :: list_start k.branches (max - 1) }
          else if k.branches <> [] then
            { k with branches = [] }
          else
            k

        | Ration (min) ->
          let r = ref min in
          fun k ->
            let ration_stamp = Some !r in
            incr r;
            { k with ration_stamp }

        | Ration_merge ration_stamp -> fun k ->
          { k with ration_stamp }

        | Transfer_merge -> fun k ->
          { k with transfer_stamp = None }

        | Static_merge exp -> fun k ->
          { k with static_split = ExpMap.remove exp k.static_split }

        | Dynamic_merge exp -> fun k ->
          { k with dynamic_split = ExpMap.remove exp k.dynamic_split }
      in
      map_keys transfer p

  let map_states (f : 'a -> 'a) (p : 'a partition) : 'a partition =
    KMap.map f p

  let transfer_states (f : 'a -> 'a list) (p : 'a partition) : 'a partition =
    let transfer_one k x p =
      let t = ref 0 in
      let add p y =
        let k' = { k with transfer_stamp = Some !t } in
        incr t;
        assert (not (KMap.mem k' p));
        KMap.add k' y p
      in
      match f x with
      | [y] -> KMap.add k y p
      | l -> List.fold_left add p l
    in
    KMap.fold transfer_one p KMap.empty

        (*
  let legacy_transfer_states (f : 'a list -> 'a list) (p : 'a partition)
    : 'a partition =
    (* Group the states in buckets, where each bucket is a list of states
       with the same key except for the ration stamp *)
    let fill_buckets k x buckets =
      (* Ignore the ration stamp *)
      let k = { k with ration_stamp = None } in
      (* Find the bucket *)
      let contents =
        try KMap.find k buckets
        with Not_found -> []
      in
      (* Add the state to the bucket *)
      KMap.add k (x :: contents) buckets
    in
    let buckets = KMap.fold fill_buckets p KMap.empty in
    (* Apply the transfer function to each bucket *)
    let result = KMap.map f buckets in
    (* Rebuild a partition by rationing out all the states *)
    let r = ref 0 in
    let ration_bucket k bucket acc =
      let ration_one acc x =
        let k' = { k with ration_stamp = Some !r } in
        incr r;
        KMap.add k' x acc
      in
      List.fold_left ration_one acc bucket
    in
    KMap.fold ration_bucket result KMap.empty *)

  let find = KMap.find
  let replace = KMap.add

  let to_list (p : 'a partition) : 'a list =
    KMap.fold (fun _k x l -> x :: l) p []

  let size (p : 'a partition) : int =
    KMap.fold (fun _k _x n -> n + 1) p 0


  let merge (f : 'a option -> 'b option -> 'c option) (p1 : 'a partition)
      (p2 : 'b partition) : 'c partition =
    KMap.merge (fun _k o1 o2 -> f o1 o2) p1 p2

  (* Almost like Map.union of Ocaml 4.03.0 *)
  let union (f : 'a -> 'a -> 'a) (p1 : 'a partition)
      (p2 : 'a partition) : 'a partition =
    let g _k o1 o2 =
      match o1 with
      | None -> o2
      | Some x1 ->
        match o2 with
        | None -> o1
        | Some x2 -> Some (f x1 x2)
    in
    KMap.merge g p1 p2

  let iter (f : 'a -> unit) (p : 'a partition) : unit =
    KMap.iter (fun _k x -> f x) p

  let filter_keys (f : key -> bool) (p : 'a partition) : 'a partition =
    KMap.filter (fun k _x -> f k) p

  let map_filter (f : key -> 'a -> 'b option) (p : 'a partition)
      : 'b partition =
    KMap.merge (fun k o _ -> opt_flatten (Extlib.opt_map (f k) o)) p KMap.empty
end
