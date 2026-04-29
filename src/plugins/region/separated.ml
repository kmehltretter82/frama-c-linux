(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module N = Memory.Nmap
module L = Datatype.String.Map

type objmap = (string * Condition.addr) list L.t N.t ref

let create () = ref N.empty

let add (idx : objmap) ~node ~from named addr =
  let lkey = Printf.sprintf "%s#%d" named (Memory.id from) in
  let lbls = try N.find node !idx with Not_found -> L.empty in
  let objs = try L.find lkey lbls with Not_found -> [] in
  idx := N.add node (L.add lkey ((named,addr) :: objs) lbls) !idx

let rec rev_iter f = function
  | [] -> ()
  | x::xs -> rev_iter f xs ; f x

let iter f (idx : objmap) =
  N.iter
    (fun r lbls ->
       L.iter (fun _ objs -> rev_iter (fun (a,p) -> f r a p) objs) lbls
    ) !idx

let iter2 f (idx : objmap) =
  N.iter
    (fun r lbls ->
       L.iter
         (fun k1 objs1 ->
            L.iter
              (fun k2 objs ->
                 if k1 < k2 then
                   rev_iter
                     (fun (a,p) ->
                        rev_iter
                          (fun (b,q) ->
                             f r a p b q
                          ) objs
                     ) objs1
              ) lbls
         ) lbls
    ) !idx
