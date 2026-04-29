(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module N = Memory.Nmap
module L = Datatype.String.Map

type objmap = Condition.addr list L.t N.t ref

let create () = ref N.empty

let add (idx : objmap) node name addr =
  let lbls = try N.find node !idx with Not_found -> L.empty in
  let objs = try L.find name lbls with Not_found -> [] in
  idx := N.add node (L.add name (addr :: objs) lbls) !idx

let rec rev_iter f = function
  | [] -> ()
  | x::xs -> rev_iter f xs ; f x

let iter f idx =
  N.iter
    (fun _r lbls ->
       L.iter
         (fun a la ->
            L.iter
              (fun b lb ->
                 if a < b then
                   rev_iter
                     (fun x ->
                        rev_iter
                          (fun y ->
                             f a x b y
                          ) lb
                     ) la
              ) lbls
         ) lbls
    ) !idx
