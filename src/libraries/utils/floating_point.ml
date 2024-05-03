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

(* -------------------------------------------------------------------------- *)
(* --- Rounding Modes                                                     --- *)
(* -------------------------------------------------------------------------- *)

type c_rounding_mode =
    FE_ToNearest | FE_Upward | FE_Downward | FE_TowardZero

let string_of_c_rounding_mode = function
  | FE_ToNearest -> "FE_NEAREST"
  | FE_Upward -> "FE_UPWARD"
  | FE_Downward -> "FE_DOWNWARD"
  | FE_TowardZero -> "FE_TOWARDZERO"

external set_round_downward: unit -> unit = "set_round_downward" [@@noalloc]
external set_round_upward: unit -> unit = "set_round_upward" [@@noalloc]
external set_round_nearest_even: unit -> unit = "set_round_nearest_even" [@@noalloc]
external set_round_toward_zero : unit -> unit = "set_round_toward_zero" [@@noalloc]
external get_rounding_mode: unit -> c_rounding_mode = "get_rounding_mode" [@@noalloc]
external set_rounding_mode: c_rounding_mode -> unit = "set_rounding_mode" [@@noalloc]
external round_to_single_precision_float: float -> float = "round_to_float"
external sys_single_precision_of_string: string -> float = "single_precision_of_string"
(* TODO two functions above: declare "float",
   must have separate version for bytecode, see OCaml manual *)

(* -------------------------------------------------------------------------- *)
(* --- Constructors                                                       --- *)
(* -------------------------------------------------------------------------- *)

let max_single_precision_float = Int32.float_of_bits 0x7f7fffffl
let most_negative_single_precision_float = -. max_single_precision_float

type parsed_float = { f_nearest : float ; f_lower : float ; f_upper : float }

let zero = { f_lower = 0.0 ; f_nearest = 0.0 ; f_upper = 0.0 }

let inf ~man_size ~max_exp =
  let f_lower = ldexp (2.0 -. ldexp 1.0 (~- man_size)) max_exp in
  { f_lower ; f_nearest = infinity ; f_upper = infinity }

let neg f =
  let f_lower   = -. f.f_upper   in
  let f_nearest = -. f.f_nearest in
  let f_upper   = -. f.f_lower   in
  { f_lower ; f_nearest ; f_upper }

(* [s = num * 2^exp / den] hold *)
let make_float ~num ~den ~exp ~man_size ~min_exp ~max_exp =
  assert Integer.(ge num zero && gt den zero) ;
  if not (Integer.is_zero num) then
    let size_bi = Integer.of_int man_size in
    let ssize_bi = Integer.of_int (succ man_size) in
    let min_exp = min_exp - man_size in
    let num = ref num and den = ref den and exp = ref exp in
    while Integer.(ge !num (shift_left !den ssize_bi)) || !exp < min_exp do
      den := Integer.shift_left !den Integer.one ;
      incr exp
    done ;
    let shifted_den = Integer.shift_left !den size_bi in
    while Integer.lt !num shifted_den && !exp > min_exp do
      num := Integer.shift_left !num Integer.one ;
      decr exp
    done ;
    if !exp <= max_exp - man_size then
      let man, rem = Integer.e_div_rem !num !den in
      let rem2 = Integer.shift_left rem Integer.one in
      let man = Integer.to_int64_exn man in
      let lowb = ldexp Int64.(to_float man) !exp in
      let upb = ldexp Int64.(to_float (succ man)) !exp in
      let rem2_zero = Integer.is_zero rem2 in
      let rem2_lt_den = Integer.lt rem2 !den in
      let rem2_is_den = Integer.equal rem2 !den in
      let last_zero = Int64.(logand man one) = 0L in
      let near_down = rem2_zero || rem2_lt_den || (rem2_is_den && last_zero) in
      let f_lower = lowb in
      let f_upper = if rem2_zero then lowb else upb in
      let f_nearest = if near_down then lowb else upb in
      { f_lower ; f_nearest ; f_upper }
    else inf ~man_size ~max_exp
  else zero

(* -------------------------------------------------------------------------- *)
(* --- Parser Engine                                                      --- *)
(* -------------------------------------------------------------------------- *)

let reg_exp = "[eE][+]?\\(-?[0-9]+\\)"
let reg_dot = "[.]"
let reg_numopt = "\\([0-9]*\\)"
let reg_num = "\\([0-9]+\\)"

let num_dot_frac = Str.regexp (reg_numopt ^ reg_dot ^ reg_numopt)
let num_dot_frac_exp = Str.regexp (reg_numopt ^ reg_dot ^ reg_numopt ^ reg_exp)
let num_exp = Str.regexp (reg_num ^ reg_exp)

let sys_single_precision_of_string_opt s =
  try Some (sys_single_precision_of_string s)
  with Failure _ -> None

let is_hexadecimal s =
  String.length s >= 2 && s.[0] = '0' && (Char.uppercase_ascii s.[1] = 'X')

exception Shortcut of parsed_float

let match_exp ~man_size ~min_exp ~max_exp group s =
  let s = Str.matched_group group s in
  match int_of_string_opt s with
  | Some n -> n
  | None when s.[0] = '-' ->
    let f_upper = ldexp 1.0 (min_exp - man_size) in
    raise (Shortcut { f_lower = 0.0 ; f_nearest = 0.0 ; f_upper })
  | None -> raise (Shortcut (inf ~man_size ~max_exp))

(* [man_size] is the size of the mantissa, [min_exp] the frontier exponent
   between normalized and denormalized numbers *)
let parse_positive_float_with_shortcut ~man_size ~min_exp ~max_exp s =
  let open Option.Operators in
  let match_exp group = match_exp ~man_size ~min_exp ~max_exp group s in
  let return = make_float ~man_size ~min_exp ~max_exp in
  (* At the end of the function, [s = num * 2^exp / den] *)
  if Str.string_match num_dot_frac_exp s 0 then
    let n = Str.matched_group 1 s in
    let frac = Str.matched_group 2 s in
    let len_frac = String.length frac in
    let num = Integer.of_string (n ^ frac) in
    let* den = Integer.power_int_positive_int_opt 5 len_frac in
    if Integer.is_zero num then raise (Shortcut zero) ;
    let exp10 = match_exp 3 in
    let+ pow5 = Integer.power_int_positive_int_opt 5 (abs exp10) in
    let num = if exp10 >= 0 then Integer.mul num pow5 else num in
    let den = if exp10 >= 0 then den else Integer.mul den pow5 in
    let exp = exp10 - len_frac in
    return ~num ~den ~exp
  else if Str.string_match num_dot_frac s 0 then
    let n = Str.matched_group 1 s in
    let frac = Str.matched_group 2 s in
    let len_frac = String.length frac in
    let num = Integer.of_string (n ^ frac) in
    let+ den = Integer.power_int_positive_int_opt 5 len_frac in
    return ~num ~den ~exp:(~- len_frac)
  else if Str.string_match num_exp s 0 then
    let n = Str.matched_group 1 s in
    let num = Integer.of_string n in
    if Integer.is_zero num then raise (Shortcut zero) ;
    let exp10 = match_exp 2 in
    let+ pow5 = Integer.power_int_positive_int_opt 5 (abs exp10) in
    let num = if exp10 >= 0 then Integer.mul num pow5 else num in
    let den = if exp10 >= 0 then Integer.one else pow5 in
    return ~num ~den ~exp:exp10
  else None

let parse_positive_float ~man_size ~min_exp ~max_exp s =
  try parse_positive_float_with_shortcut ~man_size ~min_exp ~max_exp s
  with Shortcut r -> Some r

(* -------------------------------------------------------------------------- *)
(* --- Float & Double Parsers                                             --- *)
(* -------------------------------------------------------------------------- *)

let rec single_precision_of_string s =
  let open Option.Operators in
  if s.[0] = '-' then
    let s = String.(sub s 1 (length s - 1)) in
    let+ f = single_precision_of_string s in
    neg f
  else if is_hexadecimal s then
    let+ f = sys_single_precision_of_string_opt s in
    { f_lower = f ; f_nearest = f ; f_upper = f }
  else parse_positive_float ~man_size:23 ~min_exp:(-126) ~max_exp:127 s

let rec double_precision_of_string s =
  let open Option.Operators in
  if s.[0] = '-' then
    let s = String.(sub s 1 (length s - 1)) in
    let+ f = double_precision_of_string s in
    neg f
  else if is_hexadecimal s then
    let+ f = float_of_string_opt s in
    { f_lower = f ; f_nearest = f ; f_upper = f }
  else parse_positive_float ~man_size:52 ~min_exp:(-1022) ~max_exp:1023 s

(* -------------------------------------------------------------------------- *)
(* --- Qualified C-float literals                                         --- *)
(* -------------------------------------------------------------------------- *)

let parse_fkind string = function
  | Cil_types.FFloat -> single_precision_of_string string
  | Cil_types.(FDouble | FLongDouble) -> double_precision_of_string string

let fkind_of_char = function
  | 'F' -> Cil_types.FFloat, true
  | 'D' -> Cil_types.FDouble, true
  | 'L' -> Cil_types.FLongDouble, true
  | _ -> Cil_types.FDouble, false

let suffix_of_fkind = function
  | Cil_types.FFloat -> 'F'
  | Cil_types.FDouble -> 'D'
  | Cil_types.FLongDouble -> 'L'

let pretty_fkind fmt = function
  | Cil_types.FFloat -> Format.fprintf fmt "single precision"
  | Cil_types.FDouble -> Format.fprintf fmt "double precision"
  | Cil_types.FLongDouble -> Format.fprintf fmt "long double precision"

let cannot_be_parsed string fkind =
  Kernel.abort ~current:true
    "The string %s cannot be parsed as a %a floating-point constant"
    string pretty_fkind fkind

let empty_string () =
  Kernel.abort ~current:true
    "Parsing an empty string as a floating-point constant."

(* -------------------------------------------------------------------------- *)
(* --- Full Parser                                                        --- *)
(* -------------------------------------------------------------------------- *)

let parse string =
  let l = String.length string - 1 in
  if l >= 0 then
    let last = Char.uppercase_ascii string.[l] in
    let fkind, suffix = fkind_of_char last in
    let baseint = if suffix then String.sub string 0 l else string in
    match parse_fkind baseint fkind with
    | Some result -> fkind, result
    | None -> cannot_be_parsed string fkind
  else empty_string ()

let has_suffix fk lit =
  let ln = String.length lit in
  let suffix = suffix_of_fkind fk in
  ln > 0 && Char.uppercase_ascii lit.[ln - 1] = suffix

(* -------------------------------------------------------------------------- *)
(* --- Classification                                                     --- *)
(* -------------------------------------------------------------------------- *)

let is_not_finite f =
  match classify_float f with
  | FP_normal | FP_subnormal | FP_zero -> false
  | FP_infinite | FP_nan -> true

let is_not_integer s =
  String.(contains s '.' || contains s 'e' || contains s 'E')

(* -------------------------------------------------------------------------- *)
(* --- Pretty Printing                                                    --- *)
(* -------------------------------------------------------------------------- *)

let pretty_normal ~use_hex fmt f =
  let double_norm = Int64.shift_left 1L 52 in
  let double_mask = Int64.pred double_norm in
  let i = Int64.bits_of_float f in
  let s = 0L <> (Int64.logand Int64.min_int i) in
  let i = Int64.logand Int64.max_int i in
  let exp = Int64.to_int (Int64.shift_right_logical i 52) in
  let man = Int64.logand i double_mask in
  let s = if s then "-" else "" in
  if exp = 2047 then
    Format.(if man = 0L then fprintf fmt "%sinf" s else fprintf fmt "NaN")
  else
    let firstdigit = if exp <> 0 then 1 else 0 in
    let exp = if exp <> 0 then exp - 1023 else if f = 0. then 0 else -1022 in
    if not use_hex then
      let in_bound = 0 < exp && exp <= 12 in
      let doubled_man = Int64.logor man double_norm in
      let shifted = Int64.shift_right_logical doubled_man (52 - exp) in
      let firstdigit = if in_bound then Int64.to_int shifted else firstdigit in
      let doubled = Int64.(logand (shift_left man exp) double_mask) in
      let man = if in_bound then doubled else man in
      let exp = if in_bound then 0 else exp in
      let d = Int64.(float_of_bits (logor 0x3ff0000000000000L man)) in
      let re = if d >= 1.5 then 5000000000000000L else 0L in
      let shift = if d >= 1.5 then 1.5 else 1.0 in
      let d = (d -. shift) *. 1e16 in
      let decdigits = Int64.add re (Int64.of_float d) in
      if exp = 0 || (firstdigit = 0 && decdigits = 0L && exp = -1022)
      then Format.fprintf fmt "%s%d.%016Ld" s firstdigit decdigits
      else Format.fprintf fmt "%s%d.%016Ld*2^%d" s firstdigit decdigits exp
    else Format.fprintf fmt "%s0x%d.%013Lxp%d" s firstdigit man exp

let ensure_round_nearest_even () =
  if get_rounding_mode () <> FE_ToNearest then
    let mode = string_of_c_rounding_mode (get_rounding_mode ()) in
    let () = Kernel.failure "pretty: rounding mode (%s) <> FE_TONEAREST" mode in
    set_round_nearest_even ()

let pretty fmt f =
  let use_hex = Kernel.FloatHex.get () in
  (* should always arrive here with nearest_even *)
  ensure_round_nearest_even () ;
  if not (use_hex || Kernel.FloatNormal.get ()) then
    let r = Format.sprintf "%.*g" 12 f in
    let dot = if is_not_integer r || is_not_finite f then "" else "." in
    Format.fprintf fmt "%s%s" r dot
  else pretty_normal ~use_hex fmt f

(* -------------------------------------------------------------------------- *)
(* --- Conversions                                                        --- *)
(* -------------------------------------------------------------------------- *)

type sign = Neg | Pos

exception Float_Non_representable_as_Int64 of sign

let min_64_float = -9.22337203685477581e+18
let max_64_float = 9.22337203685477478e+18

(* If the argument [x] is not in the range [min_64_float, 2*max_64_float],
   raise Float_Non_representable_as_Int64. This is the most reasonable as
   a floating-point number may represent an exponentially large integer. *)
let truncate_to_integer x =
  if x < min_64_float then raise (Float_Non_representable_as_Int64 Neg) ;
  if x > 2. *. max_64_float then raise (Float_Non_representable_as_Int64 Pos) ;
  let convert x = Integer.of_int64 (Int64.of_float x) in
  let shift n = Integer.(add (two_power_of_int 63)) n in
  if x <= max_64_float then convert x else convert (x +. min_64_float) |> shift

let bits_of_max_double =
  Integer.of_int64 (Int64.bits_of_float max_float)

let bits_of_most_negative_double =
  Integer.of_int64 (Int64.bits_of_float (-. max_float))

(** See e.g. http://www.h-schmidt.net/FloatConverter/IEEE754.html *)
let bits_of_max_float = Integer.of_int64 0x7F7FFFFFL
let bits_of_most_negative_float =
  (* cast to int32 to get negative value *)
  let v = Int64.of_int32 0xFF7FFFFFl in
  Integer.of_int64 v

external fround: float -> float = "c_round"
external trunc: float -> float = "c_trunc"

(* -------------------------------------------------------------------------- *)
(* --- Single Precision Operations                                        --- *)
(* -------------------------------------------------------------------------- *)

(* We round the result float64 operators since float32 ones are less precise. *)

external expf: float -> float = "c_expf"
external logf: float -> float = "c_logf"
external log10f: float -> float = "c_log10f"
external powf: float -> float -> float = "c_powf"
external sqrtf: float -> float = "c_sqrtf"
external fmodf: float -> float -> float = "c_fmodf"
external cosf: float -> float = "c_cosf"
external sinf: float -> float = "c_sinf"
external acosf: float -> float = "c_acosf"
external asinf: float -> float = "c_asinf"
external atanf: float -> float = "c_atanf"
external atan2f: float -> float -> float = "c_atan2f"

(* -------------------------------------------------------------------------- *)
(* --- C-Math like functions                                              --- *)
(* -------------------------------------------------------------------------- *)

let isnan f =
  match classify_float f with
  | FP_nan -> true
  | _ -> false

let isfinite f =
  match classify_float f with
  | FP_nan | FP_infinite -> false
  | _ -> true

let min_denormal = Int64.float_of_bits 1L
let neg_min_denormal = -. min_denormal
let min_single_precision_denormal = Int32.float_of_bits 1l
let neg_min_single_precision_denormal = -. min_single_precision_denormal

(* auxiliary functions for nextafter/nextafterf *)
let min_denormal_float ~is_f32 =
  if is_f32 then min_single_precision_denormal else min_denormal

let nextafter_aux ~is_f32 fincr fdecr x y =
  let sign = if x < y then 1.0 else -.1.0 in
  if x = y then y
  else if isnan x || isnan y then nan
  else if x = 0.0 then sign *. min_denormal_float ~is_f32
  else if x = neg_infinity then fdecr x
  else if (x < y && x > 0.0) || (x > y && x < 0.0) then fincr x
  else fdecr x

let incr_f64 f =
  if f = neg_infinity then -. max_float
  else Int64.(float_of_bits (succ (bits_of_float f)))

let decr_f64 f =
  if f = infinity then max_float
  else Int64.(float_of_bits (pred (bits_of_float f)))

let incr_f32 f =
  if f = neg_infinity then most_negative_single_precision_float
  else Int32.(float_of_bits (succ (bits_of_float f)))

let decr_f32 f =
  if f = infinity then max_single_precision_float
  else Int32.(float_of_bits (pred (bits_of_float f)))

let nextafter x y =
  nextafter_aux ~is_f32:false incr_f64 decr_f64 x y

let nextafterf x y =
  nextafter_aux ~is_f32:true incr_f32 decr_f32 x y

(* -------------------------------------------------------------------------- *)

(*
Local Variables:
compile-command: "make -C ../../.. byte"
End:
*)
