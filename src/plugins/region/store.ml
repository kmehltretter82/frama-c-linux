(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- UnionFind Store with explicit integer keys                         --- *)
(* -------------------------------------------------------------------------- *)

module Imap = Map.Make(Int)

module S = struct
  type 'a rref = int
  type 'a store = {
    mutable rid : int ;
    mutable map : 'a Imap.t ;
  }

  let new_store () = { rid = 0 ; map = Imap.empty  }
  let copy r = { rid = r.rid ; map = r.map }

  let make s v =
    let k = succ s.rid in
    s.rid <- k ; s.map <- Imap.add k v s.map ; k

  let get s k = Imap.find k s.map
  let set s k v = s.map <- Imap.add k v s.map

  let eq _s i j = (i == j)

  let id x = x
  let forge (x : 'a rref) : int = x
end

module Ufind = UnionFind.Make(S)

module type Element = sig
  type 'a t
  val get_id : 'a t -> int
  val set_id : 'a t -> int -> 'a t
end


module Make(E : Element) = struct
  type 'a store = {
    values : 'a E.t Ufind.store ;
    mutable refs : int Imap.t ;
  }

  type 'a t = {
    nnode : 'a E.t Ufind.rref ;
    nmap : 'a store ref ;
  }

  let check_nmap2 m1 m2 =
    if !(m1.nmap) != !(m2.nmap) then failwith "Region maps are not equal."

  let new_store () = {
    values = Ufind.new_store () ;
    refs = Imap.empty ;
  }

  let copy s = {
    values = Ufind.copy s.values ;
    refs = s.refs ;
  }

  let key n = S.id n.nnode

  let get_store n = (!(n.nmap)).values

  let id n = E.get_id @@ Ufind.get (get_store n) n.nnode

  let forge m id = {
    nnode = S.forge (Imap.find id m.refs) ;
    nmap = ref m ;
  }

  let normalize n = {
    nnode = (try Ufind.find (get_store n) n.nnode with Not_found -> n.nnode) ;
    nmap = n.nmap ;
  }

  let get n = Ufind.get (get_store n) n.nnode

  let get_map n = !(n.nmap)

  let set n v = Ufind.set (get_store n) n.nnode v

  let set_id n nid =
    let m = n.nmap in
    let nval = Ufind.get (get_store n) n.nnode in
    Ufind.set (get_store n) n.nnode (E.set_id nval nid) ;
    !m.refs <- Imap.add nid (key n) !m.refs

  let new_value m v = {
    nnode = Ufind.make m.values v ;
    nmap = ref m ;
  }

  let eq n1 n2 =
    check_nmap2 n1 n2 ;
    S.eq (get_store n1) n1.nnode n2.nnode

  let compare n1 n2 = check_nmap2 n1 n2 ; Int.compare (key n1) (key n2)

  let list l = List.sort_uniq compare l

  let rec bag l1 l2 = match l1, l2 with
    | [], c | c, [] -> c
    | a :: l1, b :: l2 -> a :: b :: bag l1 l2

  let union n1 n2 =
    check_nmap2 n1 n2 ;
    let nmap = n1.nmap in
    let nnode = Ufind.union (get_store n1) n1.nnode n2.nnode in
    { nnode ; nmap }

end
