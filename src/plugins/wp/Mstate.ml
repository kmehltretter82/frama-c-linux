(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

open Memory

(* -------------------------------------------------------------------------- *)
(* --- L-Val Utility                                                      --- *)
(* -------------------------------------------------------------------------- *)

let index (host,ofs) k = host , ofs @ [Mindex k]
let field (host,ofs) f = host , ofs @ [Mfield f]

let host_eq a b = match a,b with
  | Mvar x , Mvar y -> Cil_datatype.Varinfo.equal x y
  | Mmem a , Mmem b -> a == b
  | _ -> false

let ofs_eq a b = match a,b with
  | Mindex i , Mindex j -> i = j
  | Mfield f , Mfield g -> Cil_datatype.Fieldinfo.equal f g
  | _ -> false

let rec offset_eq p q = match p,q with
  | [],[] -> true
  | a :: p , b :: q -> ofs_eq a b && offset_eq p q
  | _ -> false

let equal a b = a == b || (host_eq (fst a) (fst b) && offset_eq (snd a) (snd b))

(* -------------------------------------------------------------------------- *)
(* --- Memory State Pretty Printing Information                           --- *)
(* -------------------------------------------------------------------------- *)

type state = STATE of {
    model : (module Memory.Model) ;
    state : Sigma.state ;
  }

let create (module M: Memory.Model) sigma =
  STATE { model = (module M) ; state = Sigma.state sigma }

let apply f = function STATE { model ; state } ->
  let module M = (val model) in
  let state = Sigma.apply f state in
  STATE { model ; state }

let lookup s e =
  match s with STATE { model ; state } ->
    let module M = (val model) in
    try M.lookup state e
    with Not_found ->
      Mchunk (Lang.F.Tmap.find e state)

let updates seq vars =
  match seq.pre, seq.post with
    STATE { model ; state = pre },
    STATE { state = post } ->
    let module M = (val model) in
    M.updates { pre ; post } vars

let iter f s =
  match s with STATE { model ; state } ->
    let module M = (val model) in
    Lang.F.Tmap.iter
      (fun value chunk ->
         match M.lookup state value with
         | exception Not_found -> f (Mchunk chunk) value
         | mval -> f mval value
      ) state

(* -------------------------------------------------------------------------- *)
