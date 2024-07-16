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

open Either
open Sigs

type ('a, 'b) product = {
  left: 'a;
  right: 'b;
}

module Product =
struct

  let map_either f_left f_right p = function
    | Left  l -> { p with left  = f_left  p.left  l }
    | Right r -> { p with right = f_right p.right r }
  let map2 f_left f_right p = {
    left  = f_left  p.left  ;
    right = f_right p.right ;
  }
  let map22 f_left f_right p q = {
    left  = f_left  p.left  q.left  ;
    right = f_right p.right q.right ;
  }

  let iter f_left f_right p =
    f_left  p.left;
    f_right p.right

  let iter2 f_left f_right p q =
    f_left  p.left  q.left;
    f_right p.right q.right

  let sequence_left (s: (('a, 'b) product) sequence) : 'a sequence = {
    pre  = s.pre.left  ;
    post = s.post.left ;
  }
  let sequence_right (s: (('a, 'b) product) sequence) : 'b sequence = {
    pre  = s.pre.right  ;
    post = s.post.right ;
  }

end
