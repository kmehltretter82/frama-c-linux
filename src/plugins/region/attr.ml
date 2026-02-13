(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type attr = [ `Nullable | `Dynamic | `Garbage | `Readonly ]
type flags = A of int [@@ unboxed]

let flag = function
  | `Nullable -> 0b0001
  | `Dynamic  -> 0b0010
  | `Garbage  -> 0b0100
  | `Readonly -> 0b1000

let empty = A 0
let add a (A w) = A (flag a lor w)
let mem a (A w) = flag a land w <> 0
let union (A x) (A y) = A (x lor y)
let subset (A x) (A y) = (x lor y) = y

let iter f w =
  List.iter
    (fun a -> if mem a w then f a)
    [ `Nullable ; `Dynamic ; `Garbage ]

let pp_attr fmt = function
  | `Nullable -> Format.pp_print_string fmt "nullable"
  | `Dynamic  -> Format.pp_print_string fmt "dynamic"
  | `Garbage  -> Format.pp_print_string fmt "garbage"
  | `Readonly -> Format.pp_print_string fmt "readonly"

let reversed = flag `Readonly
(* flags that shall be merged with land instead of lor *)

let bottom = A reversed
let merge (A x) (A y) =
  let flip w = reversed lxor w in
  A (flip (flip x lor flip y))

let pretty fmt w =
  begin
    Format.fprintf fmt "@[<hov 2>" ;
    let sep = ref false in
    let next a =
      if !sep then Format.fprintf fmt ",@," else sep := true ;
      pp_attr fmt a in
    iter next w ;
    Format.fprintf fmt "@]" ;
  end

open Cil_types

let addrof ~loc lv =
  let ptr = Cil_const.mk_tptr @@ Cil.typeOfLval lv in
  let lv = Logic_utils.lval_to_term_lval lv in
  Logic_const.term ~loc (TAddrOf lv) (Ctype ptr)

let cvar v =
  if v.vformal then empty else
  if v.vglob then
    if Ast_types.is_const v.vtype then add `Readonly empty else empty
  else
    let temp = add `Dynamic empty in
    if v.vdefined then temp else add `Garbage temp

let null_or_valid ~loc ~from addr =
  if mem `Nullable from then
    let null = Logic_const.term ~loc Tnull addr.term_type in
    Logic_const.prel ~loc (Rneq,null,addr)
  else
    Logic_const.ptrue

let readable ~loc ?(label=Logic_const.here_label) ~from addr =
  if mem `Dynamic from then
    Logic_const.pvalid_read ~loc (label, addr)
  else
    null_or_valid ~loc ~from addr

let writable ~loc ?(label=Logic_const.here_label) ~from addr =
  if mem `Readonly from then
    Logic_const.pfalse
  else
  if mem `Dynamic from then
    Logic_const.pvalid ~loc (label, addr)
  else
    null_or_valid ~loc ~from addr

let requires ~loc ?(label=Logic_const.here_label) ?(readonly=false) ~from ~target addr =
  let valid =
    if readonly || mem `Readonly target then
      readable ~loc ~label ~from addr
    else
      writable ~loc ~label ~from addr in
  let init =
    if mem `Garbage target || not @@ mem `Garbage from then
      Logic_const.ptrue
    else
      Logic_const.pinitialized ~loc (label,addr) in
  let allocated =
    if mem `Dynamic target then
      Logic_const.pimplies ~loc (valid,init)
    else
      Logic_const.pand ~loc (valid,init) in
  let nullable =
    if mem `Nullable target then
      let null = Logic_const.term ~loc Tnull addr.term_type in
      Logic_const.prel ~loc (Req,null,addr)
    else
      Logic_const.pfalse in
  Logic_const.por ~loc (nullable,allocated)
