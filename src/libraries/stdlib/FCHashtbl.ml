(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

module type S = sig
  include Hashtbl.S
  val iter_sorted:
    ?cmp:(key -> key -> int) -> (key -> 'a -> unit) -> 'a t -> unit
  val fold_sorted:
    ?cmp:(key -> key -> int) -> (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b

  val iter_sorted_by_entry:
    cmp:((key * 'a) -> (key * 'a) -> int) -> (key -> 'a -> unit) -> 'a t -> unit
  val fold_sorted_by_entry:
    cmp:((key * 'a) -> (key * 'a) -> int) -> (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b

  val iter_sorted_by_value:
    cmp:('a -> 'a -> int) -> (key -> 'a -> unit) -> 'a t -> unit
  val fold_sorted_by_value:
    cmp:('a -> 'a -> int) -> (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
  val find_opt: 'a t -> key -> 'a option
  val find_def: 'a t -> key -> 'a  -> 'a

  val memo: 'a t -> key -> (key -> 'a) -> 'a

end

let hash = Hashtbl.hash
let hash_param = Hashtbl.hash_param

module Make(H: Hashtbl.HashedType) : S with type key = H.t  = struct

  include Hashtbl.Make(H)

  let bindings_sorted ?(cmp=Stdlib.compare) h =
    to_seq h |> List.of_seq |> List.fast_sort (fun (k1,_) (k2,_) -> cmp k1 k2)

  let fold_sorted ?(cmp=Stdlib.compare) f h acc =
    let l = bindings_sorted ~cmp h in
    List.fold_left (fun acc (k,v) -> f k v acc) acc l

  let iter_sorted ?cmp f h =
    fold_sorted ?cmp (fun k v () -> f k v) h ()

  let fold_sorted_by_entry ~cmp f h acc =
    let l = to_seq h |> List.of_seq |> List.fast_sort cmp in
    List.fold_left (fun acc (k,v) -> f k v acc) acc l

  let iter_sorted_by_entry ~cmp f h =
    fold_sorted_by_entry ~cmp (fun k v () -> f k v) h  ()

  let fold_sorted_by_value ~cmp f h acc =
    fold_sorted_by_entry ~cmp:(fun (_ka,va) (_kb,vb) -> cmp va vb) f h acc

  let iter_sorted_by_value ~cmp f h =
    iter_sorted_by_entry ~cmp:(fun (_ka,va) (_kb,vb) -> cmp va vb) f h

  let find_opt h k =
    match find h k with
    | exception Not_found -> None
    | v -> Some v

  let find_def h k v =
    match find h k with
    | exception Not_found -> v
    | v -> v

  let memo tbl k f =
    try find tbl k
    with Not_found ->
      let v = f k in
      add tbl k v;
      v

end


(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
