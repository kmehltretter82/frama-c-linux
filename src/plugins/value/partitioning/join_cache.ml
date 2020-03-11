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

module type Domain =
sig
  type t
  val join : t -> t -> t
end

module type Tag =
sig
  type t
  val equal : t -> t -> bool
end

module Make (Domain : Domain) (Tag : Tag) =
struct
  type state = Domain.t
  type tag = Tag.t

  type partial_join = {
    last_tag: tag;
    last_state: state;
    last_join: state;
  }

  type t = {
    mutable joined: partial_join list;
    mutable unjoined: (tag * state) list;
  }

  let create () = {
    joined = [];
    unjoined = []
  }

  let add tag state cache =
    cache.unjoined <- (tag, state) :: cache.unjoined

  let remove tag cache =
    (* Find the elements with tag in the joined list *)
    (* At all times, collect left right acc l satisfies
       - acc @ l is the original list with some of the filtered elements removed
       - acc have all the filtered elements removed
       - l does not
       - left, right is a snapshot of acc, l, the last time a filtered element
         have been encountered, the begining of the iteration if none *)
    let rec collect left right acc = function
      | [] -> left, right
      | pj :: t when Tag.equal pj.last_tag tag -> collect acc t acc t
      | pj :: t -> collect left right (pj :: acc) t
    in
    (* Split the list in two part: at the left and at the righ of the element *)
    let left, right = collect [] cache.joined [] cache.joined in
    (* Update the cache *)
    cache.joined <- right;
    cache.unjoined <-
      List.filter (fun (tag',_state) -> Tag.equal tag' tag) cache.unjoined @
      List.map (fun pj -> pj.last_tag, pj.last_state) left

  let join cache =
    let append (last_tag,last_state) =
      let new_element = match cache.joined with
        | [] ->
          { last_tag ; last_state ; last_join=last_state }
        | { last_join } :: _ ->
          { last_tag ; last_state ; last_join=Domain.join last_join last_state }
      in
      cache.joined <- new_element :: cache.joined
    in
    List.iter append (List.rev cache.unjoined);
    cache.unjoined <- [];
    match cache.joined with
    | [] -> `Bottom
    | { last_join } :: _ -> `Value last_join
end
