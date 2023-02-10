(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Eval


module Common (Left: Abstract_location.S) (Right: Abstract_location.S) = struct
  (* TODO: maybe wrong if left and right use the same offset *)
  type offset = Left.offset * Right.offset
  type location = Left.location * Right.location

  let top = Left.top, Right.top

  let equal_loc (l, r) (l', r') =
    Left.equal_loc l l' && Right.equal_loc r r'
  let pretty_loc fmt (l, r) =
    Format.fprintf fmt "(%a, %a)" Left.pretty_loc l Right.pretty_loc r

  let equal_offset (l, r) (l', r') =
    Left.equal_offset l l' && Right.equal_offset r r'
  let pretty_offset fmt (l, r) =
    Format.fprintf fmt "(%a, %a)" Left.pretty_offset l Right.pretty_offset r

  (* TODO: don't know what to do, used max by default *)
  let size (l, r) =
    let lsize = Left.size l and rsize = Right.size r in
    if Int_Base.compare lsize rsize <= 0 then lsize else rsize

  let replace_base subst (l, r) =
    Left.replace_base subst l, Right.replace_base subst r

  let assume_no_overlap ~partial (l, r) (l', r') =
    let left  = Left.assume_no_overlap  ~partial l l' in
    let right = Right.assume_no_overlap ~partial r r' in
    (* TODO: don't known how to combine *)
    assert false

  let assume_valid_location ~for_writing ~bitfield (l, r) =
    let left  = Left.assume_valid_location  ~for_writing ~bitfield l in
    let right = Right.assume_valid_location ~for_writing ~bitfield r in
    (* TODO: don't known how to combine *)
    assert false

  let no_offset = Left.no_offset, Right.no_offset

  let forward_field typ info (l, r) =
    Left.forward_field typ info l, Right.forward_field typ info r 

  let forward_variable typ varinfo (l, r) =
    let* l = Left.forward_variable  typ varinfo l in
    let* r = Right.forward_variable typ varinfo r in
    `Value (l, r)

  let eval_varinfo info = Left.eval_varinfo info, Right.eval_varinfo info

  let backward_variable varinfo (l, r) =
    let* l = Left.backward_variable  varinfo l in
    let* r = Right.backward_variable varinfo r in
    `Value (l, r)

  let backward_field typ info (lo, ro) =
    let* lo = Left.backward_field  typ info lo in
    let* ro = Right.backward_field typ info ro in
    `Value (lo, ro)
end



module Make (Left: Abstract_location.S) (Right: Abstract_location.S) = struct
  include Common (Left) (Right)
  type value = Left.value * Right.value

  let to_value (l, r) = Left.to_value l, Right.to_value r

  let forward_index typ (lv, rv) (l, r) =
    Left.forward_index typ lv l, Right.forward_index typ rv r 

  let forward_pointer typ (lv, rv) (lo, ro) =
    let* l = Left.forward_pointer  typ lv lo in
    let* r = Right.forward_pointer typ rv ro in
    `Value (l, r)

  let backward_pointer (lv, rv) (lo, ro) (l, r) =
    let* (lv, lo) = Left.backward_pointer  lv lo l in
    let* (rv, ro) = Right.backward_pointer rv ro r in
    `Value ((lv, rv), (lo, ro))

  let backward_index typ ~index:(li, ri) ~remaining:(lrem, rrem) (lo, ro) =
    let* (lv, lo) = Left.backward_index  typ ~index:li ~remaining:lrem lo in
    let* (rv, ro) = Right.backward_index typ ~index:ri ~remaining:rrem ro in
    `Value ((lv, rv), (lo, ro))
end



module Same_value
    (Value: Abstract_value.S)
    (Left: Abstract_location.S with type value = Value.t)
    (Right: Abstract_location.S with type value = Value.t)
= struct
  include Common (Left) (Right)
  type value = Value.t

  (* TODO: ??? *)
  let to_value (l, r) = Value.join (Left.to_value l) (Right.to_value r)

  let forward_index typ v (l, r) =
    Left.forward_index typ v l, Right.forward_index typ v r 

  let forward_pointer typ v (lo, ro) =
    let* l = Left.forward_pointer  typ v lo in
    let* r = Right.forward_pointer typ v ro in
    `Value (l, r)

  let backward_pointer v (lo, ro) (l, r) =
    let* (lv, lo) = Left.backward_pointer  v lo l in
    let* (rv, ro) = Right.backward_pointer v ro r in
    let* v = Value.narrow lv rv in
    `Value (v, (lo, ro))

  let backward_index typ ~index ~remaining:(lrem, rrem) (lo, ro) =
    let* (lv, lo) = Left.backward_index  typ ~index ~remaining:lrem lo in
    let* (rv, ro) = Right.backward_index typ ~index ~remaining:rrem ro in
    let* v = Value.narrow lv rv in
    `Value (v, (lo, ro))
end
