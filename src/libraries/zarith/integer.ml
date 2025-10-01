(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Z

type 'a formatter = Format.formatter -> 'a -> unit

(* ----------- *)
(* Conversions *)
(* ----------- *)

(* These functions can raise Z.Overflow, so we make it explicit. *)
let to_int_exn = to_int
let to_int64_exn = to_int64
let to_int32_exn = to_int32

let wrap to_int i = try Some (to_int i) with Z.Overflow -> None
let to_int_opt = wrap to_int
let to_int64_opt = wrap to_int64
let to_int32_opt = wrap to_int32

(* ------------------------- *)
(* Basic functions and utils *)
(* ------------------------- *)

let two_power_of_int k =
  shift_left one k

let two_power n =
  let k = to_int n in
  if k > 1024 then
    raise Overflow
  else
    two_power_of_int k

let power_int_positive_int_opt n e =
  try Some (Big_int_Z.power_int_positive_int n e)
  with Invalid_argument _ -> None

(* We redefine shifts to operate on t instead of int. *)
let shift_left_z x y = shift_left x (to_int y)
let shift_right_z x y = shift_right x (to_int y)
let shift_right_logical x y = (* no meaning for negative value of x *)
  if (lt x zero)
  then raise (Invalid_argument "Integer.shift_right_logical")
  else shift_right_z x y

let is_zero v = equal v zero
let is_one  v = equal v one

let is_even v = is_zero (logand one v)

let length u v = succ (sub v u)

let round_down_to_zero v modu =
  mul (ediv v modu) modu

let round_up_to_r ~min:m ~r ~modu =
  add (add (round_down_to_zero (pred (sub m r)) modu) r) modu

let round_down_to_r ~max:m ~r ~modu =
  add (round_down_to_zero (sub m r) modu) r

(* -------- *)
(* Printers *)
(* -------- *)

let bdigits = [|
  "0000" ; (* 0 *)
  "0001" ; (* 1 *)
  "0010" ; (* 2 *)
  "0011" ; (* 3 *)
  "0100" ; (* 4 *)
  "0101" ; (* 5 *)
  "0110" ; (* 6 *)
  "0111" ; (* 7 *)
  "1000" ; (* 8 *)
  "1001" ; (* 9 *)
  "1010" ; (* 10 *)
  "1011" ; (* 11 *)
  "1100" ; (* 12 *)
  "1101" ; (* 13 *)
  "1110" ; (* 14 *)
  "1111" ; (* 15 *)
|]

let pp_bin_pos fmt r = Format.pp_print_string fmt bdigits.(r)
let pp_bin_neg fmt r = Format.pp_print_string fmt Stdlib.(bdigits.(15-r))

let pp_hex_pos fmt r = Format.fprintf fmt "%04X" r
let pp_hex_neg fmt r = Format.fprintf fmt "%04X" Stdlib.(0xFFFF-r)

let bmask_bin = 0xFz    (* 4 bits mask *)
let bmask_hex = 0xFFFFz (* 64 bits mask *)

type digits = {
  nbits : int ; (* max number of bits *)
  bsize : int ; (* bits in each bloc *)
  bmask : t ; (* block mask, must be (1 << bsize) - 1 *)
  sep : string ;
  pp : int formatter ; (* print one block *)
}

let rec pp_digits d fmt n v =
  if gt v zero || n < d.nbits then
    begin
      let r = to_int_exn (logand v d.bmask) in
      let k = d.bsize in
      pp_digits d fmt Stdlib.(n + k) (shift_right_trunc v k) ;
      if gt v d.bmask || Stdlib.(n + k) < d.nbits
      then Format.pp_print_string fmt d.sep ;
      d.pp fmt r ;
    end

let pp_bin ?(nbits=1) ?(sep="") fmt v =
  let nbits = if nbits <= 0 then 1 else nbits in
  if leq zero v then
    ( Format.pp_print_string fmt "0b" ;
      pp_digits { nbits ; sep ; bsize=4 ;
                  bmask = bmask_bin ; pp = pp_bin_pos } fmt 0 v )
  else
    ( Format.pp_print_string fmt "1b" ;
      pp_digits { nbits ; sep ; bsize=4 ;
                  bmask = bmask_bin ; pp = pp_bin_neg } fmt 0 (lognot v) )

let pp_hex ?(nbits=1) ?(sep="") fmt v =
  let nbits = if nbits <= 0 then 1 else nbits in
  if leq zero v then
    ( Format.pp_print_string fmt "0x" ;
      pp_digits { nbits ; sep ; bsize=16 ;
                  bmask = bmask_hex ; pp = pp_hex_pos } fmt 0 v )

  else
    ( Format.pp_print_string fmt "1x" ;
      pp_digits { nbits ; sep ; bsize=16 ;
                  bmask = bmask_hex ; pp = pp_hex_neg } fmt 0 (lognot v) )
let pretty fmt v =
  Format.pp_print_string fmt (to_string v)

let pretty_hex fmt v =
  let two_power_60 = two_power_of_int 60 in
  let rec aux v =
    if gt v two_power_60 then
      let quo, rem = ediv_rem v two_power_60 in
      aux quo;
      Format.fprintf fmt "%015LX" (to_int64_exn rem)
    else
      Format.fprintf fmt "%LX" (to_int64_exn v)
  in
  if equal v zero then Format.pp_print_string fmt "0"
  else if gt v zero then (Format.pp_print_string fmt "0x"; aux v)
  else (Format.pp_print_string fmt "-0x"; aux (neg v))

(* ------------- *)
(* Miscellaneous *)
(* ------------- *)

let cast ~size ~signed ~value =
  if (not signed) then
    let factor = two_power size in
    logand value (pred factor)
  else
    let mask = two_power (sub size one) in
    let p_mask = pred mask in
    if equal (logand mask value) zero then
      logand value p_mask
    else
      logor (lognot p_mask) value

let extract_bits ~start ~stop v =
  assert (geq start zero && geq stop start);
  (*Format.printf "%a[%a..%a]@\n" pretty v pretty start pretty stop;*)
  let r = extract v (to_int_exn start) (to_int_exn (length start stop)) in
  (*Format.printf "%a[%a..%a]=%a@\n" pretty v pretty start pretty stop pretty r;*)
  r

(* --------- *)
(* Operators *)
(* --------- *)

(* Operators are at toplevel but we want to be able to have them without
   openning everything, so we create an additionnal module. *)
module Operators = struct
  include Compare
  let ( ~- ) = ( ~- )
  let ( + ) = ( + )
  let ( - ) = ( - )
  let ( * ) = ( * )
  let ( / ) = ( / )
  let ( mod )  = ( mod )
  let ( land ) = ( land )
  let ( lor )  = ( lor )
  let ( lxor ) = ( lxor )
  let ( ~! )  = ( ~! )
  let ( lsl ) = ( lsl )
  let ( asr ) = ( asr )
  let ( ~$ ) = ( ~$ )
  let ( ** ) = ( ** )
end

(* We also want relationnal operators at top level. *)
include Compare

(* Deprecated *)

let two = 2z
let four = 4z
let eight = 8z
let sixteen = 16z
let thirtytwo = 32z
let onethousand = 1000z
let billion_one = 1_000_000_001_z
let two_power_32 = two_power_of_int 32
let two_power_64 = two_power_of_int 64

let max_int64 = of_int64 Int64.max_int
let min_int64 = of_int64 Int64.min_int

let le = leq
let ge = geq

let e_div = ediv
let e_rem = erem
let e_div_rem = ediv_rem
let c_div = div
let c_rem = rem
let c_div_rem = div_rem

let pgcd = gcd
let ppcm = lcm
