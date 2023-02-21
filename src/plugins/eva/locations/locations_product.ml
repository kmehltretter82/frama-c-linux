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



module Make
    (Value: Abstract_value.S)
    (Left: Abstract.Location.Internal with type value = Value.t)
    (Right: Abstract.Location.Internal with type value = Value.t)
= struct
  type value = Value.t
  let structure = Abstract.Location.Node (Left.structure, Right.structure)

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

  (* Intersects the truth values [t1] and [t2] coming from [assume_] functions
     from both abstract values. [v1] and [v2] are the initial values leading to
     these truth values, that may be reduced by the assumption. [combine]
     combines values from both abstract values into values of the product. *)
  let narrow_any_truth combine (v1, t1) (v2, t2) = match t1, t2 with
    | `Unreachable, _ | _, `Unreachable
    | (`True | `TrueReduced _), `False
    | `False, (`True | `TrueReduced _) -> `Unreachable
    | `False, _ | _, `False -> `False
    | `Unknown v1, `Unknown v2 -> `Unknown (combine v1 v2)
    | (`Unknown v1 | `TrueReduced v1), `True -> `TrueReduced (combine v1 v2)
    | `True, (`Unknown v2 | `TrueReduced v2) -> `TrueReduced (combine v1 v2)
    | (`Unknown v1 | `TrueReduced v1),
      (`Unknown v2 | `TrueReduced v2) -> `TrueReduced (combine v1 v2)
    | `True, `True -> `True

  let narrow_truth = narrow_any_truth (fun left right -> left, right)

  let assume_no_overlap ~partial (l1, r1) (l2, r2) =
    let l_truth = Left.assume_no_overlap  ~partial l1 l2 in
    let r_truth = Right.assume_no_overlap ~partial r1 r2 in
    let combine (l1, l2) (r1, r2) = (l1, r1), (l2, r2) in
    narrow_any_truth combine ((l1, l2), l_truth) ((r1, r2), r_truth)

  let assume_valid_location ~for_writing ~bitfield (l, r) =
    let l_truth = Left.assume_valid_location  ~for_writing ~bitfield l in
    let r_truth = Right.assume_valid_location ~for_writing ~bitfield r in
    narrow_truth (l, l_truth) (r, r_truth)

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
