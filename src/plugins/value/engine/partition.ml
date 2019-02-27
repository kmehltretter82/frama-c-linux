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

(* --- Keys --- *)

module ExpMap = Cil_datatype.ExpStructEq.Map
module IntPair = Datatype.Pair (Datatype.Int) (Datatype.Int)
module LoopList = Datatype.List (IntPair)
module BranchList = Datatype.List (Datatype.Int)

type branch = int

type key = {
  ration_stamp : (int * int) option;
  branches : branch list;
  loops : (int * int) list;
  static_split : Integer.t ExpMap.t;
  dynamic_split : Integer.t ExpMap.t;
}

module Key =
struct
  type t = key

  (* Initial key, before any partitioning *)
  let zero = {
    ration_stamp = None;
    branches = [];
    loops = [];
    static_split = ExpMap.empty;
    dynamic_split = ExpMap.empty;
  }

  let compare k1 k2 =
    let (<?>) c (cmp,x,y) =
      if c = 0 then cmp x y else c
    in
    Extlib.opt_compare IntPair.compare k1.ration_stamp k2.ration_stamp
    <?> (LoopList.compare, k1.loops, k2.loops)
    <?> (ExpMap.compare Integer.compare, k1.static_split, k2.static_split)
    <?> (ExpMap.compare Integer.compare, k1.dynamic_split, k2.dynamic_split)
    <?> (BranchList.compare, k1.branches, k2.branches)

  let pretty fmt key =
    begin match key.ration_stamp with
      | Some (n,_) -> Format.fprintf fmt "#%d" n
      | None -> ()
    end;
    Pretty_utils.pp_list ~pre:"[@[" ~sep:" ;@ " ~suf:"@]]"
      Format.pp_print_int
      fmt
      key.branches;
    Pretty_utils.pp_list ~pre:"(@[" ~sep:" ;@ " ~suf:"@])"
      (fun fmt (i,_j) -> Format.pp_print_int fmt i)
      fmt
      key.loops;
    Pretty_utils.pp_list ~pre:"{@[" ~sep:" ;@ " ~suf:"@]}"
      (fun fmt (e,i) -> Format.fprintf fmt "%a:%a"
          Cil_printer.pp_exp e
          (Integer.pretty ~hexa:false) i)
      fmt
      (ExpMap.bindings key.static_split @ ExpMap.bindings key.dynamic_split)
end


(* --- Partitions --- *)

module KMap = Map.Make (Key)

type 'a partition = 'a KMap.t

let empty = KMap.empty
let find = KMap.find
let replace = KMap.add
let is_empty = KMap.is_empty
let size = KMap.cardinal
let iter = KMap.iter
let map = KMap.map
let filter = KMap.filter
let merge = KMap.merge

let to_list (p : 'a partition) : 'a list =
  KMap.fold (fun _k x l -> x :: l) p []

let map_filter (f : key -> 'a -> 'b option) (p : 'a partition) : 'b partition =
  let opt_flatten (type a) (o : a option option) : a option =
    Extlib.opt_conv None o
  in
  KMap.merge (fun k o _ -> opt_flatten (Extlib.opt_map (f k) o)) p KMap.empty


(* --- Partitioning actions --- *)

type 'a transfer_function = (key * 'a) list -> (key * 'a) list

type unroll_limit =
  | ExpLimit of Cil_types.exp
  | IntLimit of int

type action =
  | Enter_loop of unroll_limit
  | Leave_loop
  | Incr_loop
  | Branch of branch * int
  | Ration of int
  | Ration_merge of (int*int) option
  | Static_split of Cil_types.exp
  | Dynamic_split of Cil_types.exp
  | Static_merge of Cil_types.exp
  | Dynamic_merge of Cil_types.exp
  | Update_dynamic_splits

exception InvalidAction


(* --- Flows --- *)

module type InputDomain =
sig
  type t

  exception Operation_failed

  val join : t -> t -> t
  val split : t -> Cil_types.exp -> (Integer.t * t) list
  val eval_exp_to_int : t -> Cil_types.exp -> int
end

module MakeFlow (Domain : InputDomain) =
struct
  type state = Domain.t
  type t =  (key * state) list

  let empty = []

  let initial (p : 'a list) : t =
    List.map (fun state -> Key.zero, state) p

  let to_list (f : t) : state list =
    List.map snd f

  let of_partition (p : state partition) : t =
    KMap.fold (fun k x l -> (k,x) :: l) p []

  let to_partition (p : t) : state partition =
    let add p (k,x) =
      (* Join states with the same key *)
      let x' =
        try
          Domain.join (KMap.find k p) x
        with Not_found -> x
      in
      KMap.add k x' p
    in
    List.fold_left add KMap.empty p

  let is_empty (p : t) =
    p = []

  let size (p : t) =
    List.length p

  let union (p1 : t) (p2 : t) : t =
    p1 @ p2

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
    with Domain.Operation_failed ->
      [(key,state)]

  let split ~(static : bool) (p : t) (exp : Cil_types.exp) =
    let add_split acc (key,state) =
      split_state ~static exp key state @ acc
    in
    List.fold_left add_split [] p

  let update_dynamic_splits p =
    (* Update one state *)
    let update_state acc (key,state) =
      (* Split the states in the list l for the given exp *)
      let update_exp exp _ l =
        let static = false in
        List.fold_left (fun l (k,x) -> split_state ~static exp k x @ l) [] l
      in
      (* Foreach exp in original state: split *)
      ExpMap.fold update_exp key.dynamic_split [(key,state)] @ acc
    in
    List.fold_left update_state [] p

  let map_keys (f : key -> state -> key) (p : t) : t =
    List.map (fun (k,x) -> f k x, x) p

  let transfer (f : state transfer_function)  (p : t) : t =
    f p

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

        | Enter_loop limit_kind -> fun k x ->
          let limit = try match limit_kind with
            | ExpLimit exp -> Domain.eval_exp_to_int x exp
            | IntLimit i -> i
            with
            | Domain.Operation_failed -> 0
          in
          { k with loops = (0,limit) :: k.loops }

        | Leave_loop -> fun k _x ->
          begin match k.loops with
            | [] -> raise InvalidAction
            | _ :: tl -> { k with loops = tl }
          end

        | Incr_loop -> fun k _x ->
          begin match k.loops with
            | [] -> raise InvalidAction
            | (h, limit) :: tl ->
              if h >= limit then
                k
              else
                { k with loops = (h + 1, limit) :: tl }
          end

        | Branch (b,max) -> fun k _x ->
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
          fun k _x ->
            let ration_stamp = Some (!r, 0) in
            incr r;
            { k with ration_stamp }

        | Ration_merge ration_stamp  -> fun k _x ->
          { k with ration_stamp }

        | Static_merge exp -> fun k _x ->
          { k with static_split = ExpMap.remove exp k.static_split }

        | Dynamic_merge exp -> fun k _x ->
          { k with dynamic_split = ExpMap.remove exp k.dynamic_split }
      in
      map_keys transfer p

  let transfer_states (f : state -> state list) (p : t) : t =
    let n = ref 0 in
    let transfer acc (k,x) =
      let add =
        match k.ration_stamp with
        (* No ration stamp, just add the state to the list *)
        | None -> fun l y -> (k,y) :: l
        (* There is a ration stamp, set the second part of the stamp to a unique transfer number *)
        | Some (s,_) -> fun l y ->
          let k' = { k with ration_stamp = Some (s, !n) } in
          incr n;
          (k',y) :: l
      in
      List.fold_left add acc (f x)
    in
    List.fold_left transfer [] p

  let legacy_transfer_states (f : state list -> state list) (p : t) : t =
    (* Group the states in buckets, where each bucket is a list of states
       with the same key except for the ration stamp *)
    let fill_buckets buckets (k,x)  =
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
    let buckets = List.fold_left fill_buckets KMap.empty p in
    (* Apply the transfer function to each bucket *)
    let result = KMap.map f buckets in
    (* Rebuild the flow *)
    let add_bucket k bucket acc =
      List.map (fun x -> k,x) bucket @ acc
    in
    KMap.fold add_bucket result []

  let iter (f : state -> unit) (p : t) : unit =
    List.iter (fun (_k,x) -> f x) p
end
