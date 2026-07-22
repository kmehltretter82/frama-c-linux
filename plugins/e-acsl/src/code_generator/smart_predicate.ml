(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

let of_bool ?(loc = Options.gen_loc) ?(names = []) = function
  | true -> Logic_const.pred ~loc ~names Ptrue
  | false -> Logic_const.pred ~loc ~names Pfalse

let prel
    ?(loc = Options.gen_loc)
    ?(names = [])
    rel
    t1
    t2 =
  if Options.O.get () > 0 then try
      let z1 = Option.get @@ Terms.extract_integer t1 in
      let z2 = Option.get @@ Terms.extract_integer t2 in
      of_bool ~loc ~names @@
      match rel with
      | Req -> Z.equal z1 z2
      | Rneq -> not @@ Z.equal z1 z2
      | Rle -> Z.leq z1 z2
      | Rlt -> Z.lt z1 z2
      | Rge -> Z.geq z1 z2
      | Rgt -> Z.gt z1 z2
    with _ -> Logic_const.prel ~loc ~names (rel,t1,t2)
  else Logic_const.prel ~loc ~names (rel,t1,t2)

let pand ?(loc = Options.gen_loc) ?(names = []) p1 p2 =
  if Options.O.get () > 0
  then Logic_const.pand ~loc ~names (p1,p2)
  else Logic_const.pred ~loc ~names (Pand (p1,p2))
