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
  val default_id : int
  val get_id : 'a t -> int
  val set_id : 'a t -> int -> unit
end


module Make(E : Element) = struct
  type 'a store = {
    values : 'a E.t Ufind.store ;
    mutable refs : int Imap.t ;
  }

  type 'a t = {
    nnode : 'a E.t Ufind.rref ;
    mutable nmap : 'a store ref ;
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

  let normalize ?store n =
    begin match store with
      | Some s -> if !s != !(n.nmap) then failwith "Region maps are not equal."
      | None -> ()
    end; {
      nnode = (try Ufind.find ((!(n.nmap)).values) n.nnode with Not_found -> n.nnode) ;
      nmap = n.nmap ;
    }

  let id n =
    let n = normalize n in
    E.get_id @@ Ufind.get ((!(n.nmap)).values) n.nnode

  let forge_id m id = normalize {
      nnode = S.forge (Imap.find id !m.refs) ;
      nmap = m ;
    }

  let forge_key m key = normalize {
      nnode = S.forge key ;
      nmap = m ;
    }

  let min n1 n2 =
    check_nmap2 n1 n2 ;
    forge_key n1.nmap @@ Int.min (key n1) (key n2)

  let pp_all fmt m =
    let print_id fmt id r =
      Format.fprintf fmt "; id=%x:key=%x ;" id r (*E.pp_elt @@ Ufind.get (!m.values) (S.forge r) *);
    in
    Format.fprintf fmt "(%i)=" @@ Imap.cardinal !m.refs ;
    Imap.iter (print_id fmt) !m.refs

  let get n =
    let n = normalize n in
    let value = Ufind.get ((!(n.nmap)).values) n.nnode in
    let id = E.get_id value in
    if not @@ Int.equal E.default_id id && not @@ Imap.mem id (!(n.nmap)).refs
    then Format.eprintf "+_+_+ %a@." pp_all n.nmap ;
    value

  let get_map n = n.nmap

  let set_map m n = n.nmap <- m

  let set n v =
    let n = normalize n in
    Ufind.set ((!(n.nmap)).values) n.nnode v

  let set_id n nid =
    let n = normalize n in
    let m = n.nmap in
    let nval = Ufind.get ((!(n.nmap)).values) n.nnode in
    E.set_id nval nid ;
    !m.refs <- Imap.add nid (key n) !m.refs

  let new_value m v = {
    nnode = Ufind.make !m.values v ;
    nmap = m ;
  }

  let eq n1 n2 =
    check_nmap2 n1 n2 ;
    S.eq ((!(n1.nmap)).values) n1.nnode n2.nnode

  let compare n1 n2 = check_nmap2 n1 n2 ; Int.compare (key n1) (key n2)

  let list l = List.sort_uniq compare l

  let rec bag l1 l2 = match l1, l2 with
    | [], c | c, [] -> c
    | a :: l1, b :: l2 -> a :: b :: bag l1 l2

  let union n1 n2 =
    check_nmap2 n1 n2 ;
    let nmap = n1.nmap in
    let nnode = Ufind.union ((!(n1.nmap)).values) n1.nnode n2.nnode in
    { nnode ; nmap }

end
