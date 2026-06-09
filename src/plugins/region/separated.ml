(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module N = Memory.Nmap
module L = Datatype.String.Map

type obj = { named : string ; flags : Attr.flags ; addr : Condition.addr }
type map = obj list L.t N.t ref

let create () = ref N.empty

let add (idx : map) ~node ~from obj =
  let lkey = Printf.sprintf "%s#%d" obj.named (Memory.id from) in
  let lbls = try N.find node !idx with Not_found -> L.empty in
  let objs = try L.find lkey lbls with Not_found -> [] in
  idx := N.add node (L.add lkey (obj::objs) lbls) !idx

let rec rev_iter f = function [] -> () | x::xs -> rev_iter f xs ; f x

let iter fn (idx : map) =
  N.iter (fun r lbls -> L.iter (fun _ -> rev_iter (fn r)) lbls) !idx

let iter2 fn (idx : map) =
  N.iter
    (fun r lbls ->
       L.iter
         (fun k1 obj1 ->
            L.iter
              (fun k2 obj2 ->
                 if k1 < k2 then
                   rev_iter (fun a -> rev_iter (fn r a) obj2) obj1
              ) lbls
         ) lbls
    ) !idx
