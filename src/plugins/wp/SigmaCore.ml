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

module F = Lang.F

(* -------------------------------------------------------------------------- *)
(* --- Generic Sigma Factory                                              --- *)
(* -------------------------------------------------------------------------- *)

type mu = ..

module type Tag =
sig
  val tag : int
  include Sigs.Chunk with type t := mu
end

(* memory chunks *)
type chunk = { tag : (module Tag) ; mu : mu }
let mu c = c.mu

module Chunk : Sigs.Chunk with type t = chunk =
struct
  type t = chunk
  let self = "Core"
  let hash c =
    let module T = (val c.tag) in Qed.Hcons.hash_pair T.tag @@ T.hash c.mu
  let equal a b =
    let module A = (val a.tag) in
    let module B = (val b.tag) in
    A.tag = B.tag && A.equal a.mu b.mu
  let compare a b =
    let module A = (val a.tag) in
    let module B = (val b.tag) in
    let cmp = Int.compare A.tag B.tag in
    if cmp <> 0 then cmp else A.compare a.mu b.mu
  let pretty fmt c =
    let module T = (val c.tag) in T.pretty fmt c.mu
  let tau_of_chunk c =
    let module T = (val c.tag) in T.tau_of_chunk c.mu
  let basename_of_chunk c =
    let module T = (val c.tag) in T.basename_of_chunk c.mu
  let is_framed c =
    let module T = (val c.tag) in T.is_framed c.mu
end

module Heap = Qed.Collection.Make(Chunk)

(* -------------------------------------------------------------------------- *)
(* --- Domain                                                             --- *)
(* -------------------------------------------------------------------------- *)

type domain = Heap.Set.t
let empty = Heap.Set.empty
let union = Heap.Set.union

(* -------------------------------------------------------------------------- *)
(* --- State                                                              --- *)
(* -------------------------------------------------------------------------- *)

type state = chunk F.Tmap.t

let apply f (s:state) : state =
  F.Tmap.fold (fun t c s -> F.Tmap.add (f t) c s) s F.Tmap.empty

(* -------------------------------------------------------------------------- *)
(* --- Sigma                                                              --- *)
(* -------------------------------------------------------------------------- *)

type sigma = F.var Heap.Map.t ref

let create () = ref Heap.Map.empty
let copy sigma = ref !sigma
let newchunk c =
  let module T = (val c.tag) in
  let basename = T.basename_of_chunk c.mu in
  let tau = T.tau_of_chunk c.mu in
  Lang.freshvar ~basename tau

let mem (sigma : sigma) c = Heap.Map.mem c !sigma
let domain (sigma : sigma) : domain = Heap.Map.domain !sigma
let state (sigma : sigma) : state =
  let s = ref F.Tmap.empty in
  Heap.Map.iter (fun c x -> s := F.Tmap.add (F.e_var x) c !s) !sigma ; !s

let get sigma c =
  let s = !sigma in
  try Heap.Map.find c s
  with Not_found ->
    let x = newchunk c in
    sigma := Heap.Map.add c x s ; x

let value sigma c = F.e_var @@ get sigma c

let merge a b =
  let pa = ref Passive.empty in
  let pb = ref Passive.empty in
  let merge_chunk c x y =
    if F.Var.equal x y then x else
      let z = newchunk c in
      pa := Passive.bind ~fresh:z ~bound:x !pa ;
      pb := Passive.bind ~fresh:z ~bound:y !pb ;
      z in
  let merged = Heap.Map.union merge_chunk !a !b in
  ref merged , !pa, !pb

let choose a b =
  let merge_chunck _ x y = if F.Var.compare x y <= 0 then x else y in
  ref @@ Heap.Map.union merge_chunck !a !b

let join a b =
  if a == b then Passive.empty else
    let p = ref Passive.empty in
    Heap.Map.iter2
      (fun chunk x y ->
         match x,y with
         | Some x , Some y -> p := Passive.join x y !p
         | Some x , None -> b := Heap.Map.add chunk x !b
         | None , Some y -> a := Heap.Map.add chunk y !a
         | None , None -> ())
      !a !b ; !p

let havoc sigma domain =
  let ys = Heap.Set.mapping newchunk domain in
  ref @@ Heap.Map.union (fun _v _old y -> y) !sigma ys

let remove_chunks sigma domain =
  ref @@ Heap.Map.filter (fun c _ -> not @@ Heap.Set.mem c domain) !sigma

let havoc_chunk sigma c =
  let x = newchunk c in
  ref @@ Heap.Map.add c x !sigma

let is_framed c =
  let module T = (val c.tag) in T.is_framed c.mu

let havoc_any ~call sigma =
  let framer c x = if call && is_framed c then x else newchunk c in
  ref @@ Heap.Map.mapi framer !sigma

(* Merge All *)

type usage = Used of F.var | Unused

let merge_list (ls : sigma list) : sigma * Passive.t list =
  (* Get a map of the chunks (the data is not important) *)
  let domain =
    Heap.Map.map (fun _ -> []) @@
    let dunion _ c _ = c in
    List.fold_left
      (fun acc s -> Heap.Map.merge dunion acc !s)
      Heap.Map.empty ls in
  (* Accumulate usage for each c, preserving the order of the list *)
  let usage =
    let umerge _ c e =
      match c, e with
      | Some c, Some x -> Some (Used x :: c)
      | Some c, None -> Some (Unused :: c)
      | None, _ -> assert false in
    List.fold_left
      (fun acc s -> Heap.Map.merge umerge acc !s)
      domain (List.rev ls) in
  (* Build the passive for each sigma of the list, and the final sigma *)
  let passives = ref @@ List.map (fun _ -> Passive.empty) ls in
  let choose c uses =
    let used = function Used _ -> true | Unused -> false in
    let compatible x = function Used y -> F.Var.equal x y | Unused -> true in
    match List.filter used uses with
    | [] -> assert false
    | Used x :: others when List.for_all (compatible x) others -> x
    | _ ->
      let fresh = newchunk c in
      let join pa = function
        | Unused -> pa
        | Used bound -> Passive.bind ~fresh ~bound pa in
      passives := List.map2 join !passives uses ; fresh
  in ref @@ Heap.Map.mapi choose usage, !passives

(* Effects *)

let writes (seq : sigma Sigs.sequence) : domain =
  let domain = ref Heap.Set.empty in
  Heap.Map.iter2
    (fun c u v ->
       let written =
         match u,v with
         | Some x , Some y -> not @@ F.Var.equal x y
         | None , Some _ -> true
         | Some _ , None -> false (* no need to create a new *)
         | None, None -> assert false
       in if written then domain := Heap.Set.add c !domain
    ) !(seq.pre) !(seq.post) ;
  !domain

let assigned ~pre ~post written =
  let p = ref Bag.empty in
  Heap.Map.iter2
    (fun chunk x y ->
       if not (Heap.Set.mem chunk written) then
         match x,y with
         | Some x , Some y when x != y ->
           p := Bag.add (F.p_equal (F.e_var x) (F.e_var y)) !p
         | Some x , None -> post := Heap.Map.add chunk x !post
         | None , Some y -> pre := Heap.Map.add chunk y !pre
         | _ -> ())
    !pre !post ; !p

(* Sigma API *)

type t = sigma
let iter f s = Heap.Map.iter f !s
let iter2 f a b = Heap.Map.iter2 f !a !b

let pretty fmt sigma =
  begin
    Format.fprintf fmt "{@[<hov 2>" ;
    Heap.Map.iter
      (fun c x ->
         let module T = (val c.tag) in
         Format.fprintf fmt "@ %a:%a" T.pretty c.mu F.Var.pretty x)
      !sigma ;
    Format.fprintf fmt "@]}" ;
  end

(* -------------------------------------------------------------------------- *)
(* --- Chunks                                                             --- *)
(* -------------------------------------------------------------------------- *)

module Make(C : Sigs.Chunk) =
struct
  type mu += Mu of C.t
  module T =
  struct
    let self = C.self
    let tag = Obj.Extension_constructor.id [%extension_constructor Mu]
    let map f = function Mu m -> f m | _ -> assert false
    let map2 f a b =
      match a,b with Mu a, Mu b -> f a b | _ -> assert false
    let hash = map C.hash
    let equal = map2 C.equal
    let compare = map2 C.compare
    let is_framed = map C.is_framed
    let tau_of_chunk = map C.tau_of_chunk
    let basename_of_chunk = map C.basename_of_chunk
    let pretty fmt = map (C.pretty fmt)
  end
  let tag = (module T : Tag)
  let chunk c = { tag ; mu = Mu c }
  let mem sigma c = mem sigma @@ chunk c
  let get sigma c = get sigma @@ chunk c
  let value sigma c = value sigma @@ chunk c
  let singleton c = Heap.Set.singleton @@ chunk c
  let find state t =
    let c = F.Tmap.find t state in
    match c.mu with Mu chunk -> chunk | _ -> raise Not_found
end

(* -------------------------------------------------------------------------- *)
