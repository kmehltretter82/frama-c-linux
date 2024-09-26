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

type single = Format_Single
type double = Format_Double
type long   = Format_Long

type rounding =
  | Nearest_even
  | Upward
  | Downward
  | Toward_zero

type 'f format =
  | Single : single format
  | Double : double format
  | Long   : long   format

type 'f t =
  | Float : float * 'f format -> 'f t



external change_format : 'f format -> float -> float = "frama_c_change_format"
external single_of_string : string -> float = "single_precision_of_string"
external set_rounding_mode : rounding -> unit = "frama_c_set_round_mode" [@@noalloc]
external get_rounding_mode : unit -> rounding = "frama_c_get_round_mode" [@@noalloc]

external round : 'f format -> float -> float = "frama_c_round"
external trunc : 'f format -> float -> float = "frama_c_trunc"
external exp   : 'f format -> float -> float = "frama_c_exp"
external log   : 'f format -> float -> float = "frama_c_log"
external log10 : 'f format -> float -> float = "frama_c_log10"
external cos   : 'f format -> float -> float = "frama_c_cos"
external sin   : 'f format -> float -> float = "frama_c_sin"
external tan   : 'f format -> float -> float = "frama_c_tan"
external acos  : 'f format -> float -> float = "frama_c_acos"
external asin  : 'f format -> float -> float = "frama_c_asin"
external atan  : 'f format -> float -> float = "frama_c_atan"
external atan2 : 'f format -> float -> float -> float = "frama_c_atan2"
external pow   : 'f format -> float -> float -> float = "frama_c_pow"
external fmod  : 'f format -> float -> float -> float = "frama_c_fmod"



type resulting_format = Format : 'f format -> resulting_format

let format_of_fkind = function
  | Cil_types.FFloat      -> Format Single
  | Cil_types.FDouble     -> Format Double
  | Cil_types.FLongDouble -> Format Long

let fkind_of_format : type f. f format -> Cil_types.fkind = function
  | Single -> Cil_types.FFloat
  | Double -> Cil_types.FDouble
  | Long   -> Cil_types.FLongDouble

let format_of_string = function
  | "L" | "l" -> Format Long
  | "F" | "f" -> Format Single
  | _         -> Format Double

let format_of_char = function
  | 'L' | 'l' -> Format Long  , true
  | 'D' | 'd' -> Format Double, true
  | 'F' | 'f' -> Format Single, true
  | _         -> Format Double, false



let single f = Float (change_format Single f, Single)
let double f = Float (f, Double)
let long   f = Float (f, Long)

let represents : type f. float:float -> in_format:f format -> f t =
  fun ~float ~in_format ->
  match in_format with
  | Single -> single float
  | Double -> double float
  | Long   -> long   float

let to_float (Float (n, _)) = n
let format   (Float (_, f)) = f

let round_to_single_precision_float f =
  single f |> to_float

let is_finite (Float (n, _)) =
  match classify_float n with
  | FP_infinite | FP_nan -> false
  | _ -> true

let is_infinite (Float (n, _)) =
  match classify_float n with
  | FP_infinite -> true
  | _ -> false

let is_nan (Float (n, _)) =
  match classify_float n with
  | FP_nan -> true
  | _ -> false

let suffix_of_fkind = function
  | Cil_types.FFloat -> 'F'
  | Cil_types.FDouble -> 'D'
  | Cil_types.FLongDouble -> 'L'

let has_suffix fkind literal =
  let ln = String.length literal in
  let suffix = suffix_of_fkind fkind in
  ln > 0 && Char.uppercase_ascii literal.[ln - 1] = suffix



type compute_float = { run : 'f. 'f format -> float }
let cache_floats : type f. compute_float -> f format -> f t = fun { run } ->
  let s = run Single and d = run Double and l = run Long in
  function Single -> single s | Double -> double d | Long -> long l

type compute_integer = { run : 'f. 'f format -> Z.t }
let cache_integers : type f. compute_integer -> f format -> Z.t = fun { run } ->
  let single = run Single and double = run Double and long = run Long in
  function Single -> single | Double -> double | Long -> long

let sig_size : type f. f format -> int =
  function Single -> 24 | Double -> 53 | Long -> 53

let exp_size : type f. f format -> int =
  function Single ->  8 | Double -> 11 | Long -> 11

let largest_finite_float_of : type f. format:f format -> f t =
  let exponent fmt = Int.shift_left 1 (exp_size fmt - 1) - 1 in
  let base fmt = 2.0 -. ldexp 1.0 (1 - sig_size fmt) in
  let run fmt = ldexp (base fmt) (exponent fmt) |> change_format fmt in
  fun ~format -> cache_floats { run } format

let smallest_normal_float_of : type f. format:f format -> f t =
  let exponent fmt = 2 - Int.shift_left 1 (exp_size fmt - 1) in
  let run fmt = ldexp 1.0 (exponent fmt) |> change_format fmt in
  fun ~format -> cache_floats { run } format

let smallest_denormal_float_of : type f. format:f format -> f t =
  let s () = Int32.float_of_bits 1l and d () = Int64.float_of_bits 1L in
  let run : type k. k format -> float = function Single -> s () | _ -> d () in
  fun ~format -> cache_floats { run } format

let unit_in_the_last_place_of : type f. format:f format -> f t =
  let run fmt = ldexp 1.0 (- sig_size fmt) in
  fun ~format -> cache_floats { run } format

let minimal_exponent_of : type f. format:f format -> Z.t =
  let run fmt = Z.(of_int 2 - pow (of_int 2) Stdlib.(exp_size fmt - 1)) in
  fun ~format -> cache_integers { run } format

let maximal_exponent_of : type f. format:f format -> Z.t =
  let run fmt = Z.(pow (of_int 2) Stdlib.(exp_size fmt - 1) - one) in
  fun ~format -> cache_integers { run } format



let ( = )  : type f. f t -> f t -> bool =
  fun l r -> to_float l = to_float r

let ( <> ) : type f. f t -> f t -> bool =
  fun l r -> not (l = r)

let ( < )  : type f. f t -> f t -> bool =
  fun l r -> to_float l < to_float r

let ( <= )  : type f. f t -> f t -> bool =
  fun l r -> to_float l <= to_float r

let ( > )  : type f. f t -> f t -> bool =
  fun l r -> to_float l > to_float r

let ( >= )  : type f. f t -> f t -> bool =
  fun l r -> to_float l >= to_float r



let unary op n =
  let Float (n, fmt) = n in Float (op fmt n, fmt)

let binary (type f) op (l : f t) (r : f t) =
  let Float (l, fmt) = l and Float (r, _) = r in Float (op fmt l r, fmt)

let neg  n = unary (fun _ -> Float.neg ) n
let sqrt n = unary (fun fmt x -> change_format fmt (Float.sqrt x)) n
let ( + ) l r = binary (fun fmt l r -> change_format fmt (l +. r)) l r
let ( - ) l r = binary (fun fmt l r -> change_format fmt (l -. r)) l r
let ( * ) l r = binary (fun fmt l r -> change_format fmt (l *. r)) l r
let ( / ) l r = binary (fun fmt l r -> change_format fmt (l /. r)) l r
let ( mod ) l r = binary (fun fmt l r -> change_format fmt (mod_float l r)) l r

let round n = unary round n
let trunc n = unary trunc n
let exp   n = unary exp   n
let log   n = unary log   n
let log10 n = unary log10 n
let cos   n = unary cos   n
let sin   n = unary sin   n
let tan   n = unary tan   n
let acos  n = unary acos  n
let asin  n = unary asin  n
let atan  n = unary atan  n
let atan2 l r = binary atan2 l r
let pow  base e = binary pow  base e
let fmod base m = binary fmod base m

let change_format : type a f. a t -> f format -> f t = fun number format ->
  match number, format with
  | Float (n, _), Single -> single n
  | Float (n, _), Double -> double n
  | Float (n, _),   Long -> long   n

let finite_range_of : type f. format:f format -> f t * f t = fun ~format ->
  let upper = largest_finite_float_of ~format in neg upper, upper



type truncated_to_integer =
  | Integer of Z.t
  | Underflow
  | Overflow

let min_64_float = -9.22337203685477581e+18
let max_64_float = +9.22337203685477478e+18

(* If the argument [x] is not in the range [min_64_float, 2*max_64_float],
   raise Float_Non_representable_as_Int64. This is the most reasonable as
   a floating-point number may represent an exponentially large integer. *)
let truncate_to_integer (Float (x, _)) =
  let convert x = Integer.of_int64 (Int64.of_float x) in
  let shift n = Integer.(add (two_power_of_int 63)) n in
  let unsigned x = convert (x +. min_64_float) |> shift in
  if Stdlib.(min_64_float <= x) then
    if Stdlib.(x <= max_64_float) then Integer (convert x)
    else if Stdlib.(x <= 2. *. max_64_float) then Integer (unsigned x)
    else Overflow
  else Underflow

let bits_encoding : type f. f t -> Z.t = function
  | Float (x, Single) -> Z.of_int32 (Int32.bits_of_float x)
  | Float (x, Double) -> Z.of_int64 (Int64.bits_of_float x)
  | Float (x,   Long) -> Z.of_int64 (Int64.bits_of_float x)



let pretty_normal ~use_hex fmt (Float (f, _)) =
  let open Stdlib in
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

let string_of_rounding_mode = function
  | Nearest_even -> "FE_TONEAREST"
  | Upward -> "FE_UPWARD"
  | Downward -> "FE_DOWNWARD"
  | Toward_zero -> "FE_TOWARDZERO"

let ensure_round_nearest_even () =
  if Stdlib.(get_rounding_mode () <> Nearest_even) then
    let mode = string_of_rounding_mode (get_rounding_mode ()) in
    let () = Kernel.failure "pretty: rounding mode (%s) <> FE_TONEAREST" mode in
    set_rounding_mode Nearest_even

let pretty fmt (Float (f, _) as float) =
  let use_hex = Kernel.FloatHex.get () in
  (* should always arrive here with nearest_even *)
  ensure_round_nearest_even () ;
  if not (use_hex || Kernel.FloatNormal.get ()) then
    let r = Format.sprintf "%.*g" 12 f in
    let contains = String.contains r in
    let is_not_integer = contains '.' || contains 'e' || contains 'E' in
    let dot = if is_not_integer || not (is_finite float) then "" else "." in
    Format.fprintf fmt "%s%s" r dot
  else pretty_normal ~use_hex fmt float



type 'f parsed_float =
  { lower   : 'f t
  ; nearest : 'f t
  ; upper   : 'f t
  ; format  : 'f format
  }

type parsed_result =
  | Parsed : 'f parsed_float -> parsed_result

type ('a, 'f) normalizing =
  | Normalized : 'a -> ('a, 'f) normalizing
  | Shortcut : 'f parsed_float -> ('a, 'f) normalizing

let ( let* ) normalizing f =
  match normalizing with
  | Shortcut parsed -> Shortcut parsed
  | Normalized v -> f v

let parsed sign = function
  | Shortcut r | Normalized r ->
    if Stdlib.(sign = "-") then
      let upper   = neg r.lower   in
      let lower   = neg r.upper   in
      let nearest = neg r.nearest in
      Parsed { lower ; nearest ; upper ; format = r.format }
    else Parsed r

let pos_inf_shortcut ~format =
  let inf = represents ~float:Float.infinity ~in_format:format in
  let max = largest_finite_float_of ~format in
  Shortcut { lower = max ; nearest = inf ; upper = inf ; format }



let normalize_exponent_of_string ~format e =
  let exponent = Z.of_string e in
  if Z.Compare.(exponent > Z.of_int max_int) then
    pos_inf_shortcut ~format
  else if Z.Compare.(exponent < Z.of_int min_int) then
    let zero = represents ~float:0.0 ~in_format:format in
    let min  = smallest_denormal_float_of ~format in
    Shortcut { lower = zero ; nearest = zero ; upper = min ; format }
  else Normalized (Z.to_int exponent)

let normalize_zero_in_numerator ~format numerator =
  if Z.(equal numerator zero) then
    let zero = represents ~float:0.0 ~in_format:format in
    let lower = zero and nearest = zero and upper = zero in
    Shortcut { lower ; nearest ; upper ; format }
  else Normalized numerator

let normalize_exponent_on_format ~format exponent =
  let exponent = Z.of_int exponent in
  let significant_size = Stdlib.(sig_size format - 1) |> Z.of_int in
  let maximal_exponent = maximal_exponent_of ~format in
  let shifted_maximal = Z.(maximal_exponent - significant_size) in
  if Z.Compare.(exponent > shifted_maximal)
  then pos_inf_shortcut ~format
  else Normalized Z.(to_int exponent)

let normalize integral fractional exponent format =
  (* Concats the integral and fractional parts to produce [ i x 10 ^ l + f ]
     with i (reps. f) the integral (resp. fractional) part and l the length
     of the fractional part. This number is the numerator. To compensate,
     a denominator is added, which should be equal to [ 10 ^ l ]. However, as
     we want to express the number to be normalized as a power of two, we only
     keep [ 5 ^ l ] as the denominator. The missing [ 2 ^ l ] will be added to
     the exponent later. *)
  let fractional_length = String.length fractional in
  let concat = Z.of_string (integral ^ fractional) in
  let* initial_numerator   = normalize_zero_in_numerator ~format concat in
  let  initial_denominator = Z.(pow (of_int 5) fractional_length) in
  let* initial_exponent    = normalize_exponent_of_string ~format exponent in
  (* For now, the exponent is a power of ten. We split it in a power of five
     and a power of two, the one we want to keep. The power of five part is
     multiplied with the numerator or the denominator depending on the sign
     of the exponent. The missing [ 2 ^ l ] from the denominator is taken
     into account by substracting [l] to the exponent. *)
  let shift_power_two = Z.(pow (of_int 5)) (abs initial_exponent) in
  let is_positive_exponent = Stdlib.(initial_exponent >= 0) in
  let num_factor = if is_positive_exponent then shift_power_two else Z.one in
  let den_factor = if is_positive_exponent then Z.one else shift_power_two in
  let numerator   = ref Z.(initial_numerator   * num_factor) in
  let denominator = ref Z.(initial_denominator * den_factor) in
  let exponent    = ref Stdlib.(initial_exponent - fractional_length) in
  (* We denote [m] the significant size and [emin] the minimal exponent.
     Be wary that here, the minimal exponent *TAKES INTO ACCOUNT* the
     significant size, i.e it's the minimal exponent of the last bit of
     the significant. *)
  let sig_size = sig_size format in
  let minimal_exponent = minimal_exponent_of ~format in
  let minimal_exponent = Stdlib.(Z.to_int minimal_exponent - sig_size + 1) in
  (* Morally, the next step would be to find δ ∈ ℤ such as we have :
     [ emin ≤ e - δ + m ≤ emax ] and [ 2 ^ (m - 1) ≤ (n / d) * 2 ^ δ ≤ 2 ^ m ],
     with the idea to shift the numerator or the denominator such as their
     ratio can be decomposed into a quotient that fits into a m-bit integer
     (i.e the significant) and a remainder corresponding to the rounding error.
     However, find such a δ requires to compute ⌈log d - log n⌉, which cannot
     be exactly done. Thus we rely on disgusting stateful loops to perform
     the computations instead. At the end of those two loops, [n] and [d] are
     such that [ 2 ^ (m - 1) ≤ n / d ≤ 2 ^ m ] and [e] has been updated to
     guarantee that the number we want to normalize is still equal to the
     number [ (n / d) * 2 ^ e ]. However, the [log] approach can still be
     useful as an underapproximation of the resulting exponent. If that
     number is larger than the largest exponent in the format, we can already
     take a shortcut, the result will be infinity. This fix an old issue where
     the parser were stuck for a long time on numbers like 1e99999. *)
  let delta = Stdlib.(sig_size - Z.log2 !numerator + Z.log2 !denominator + 1) in
  let max_exponent_in_format = maximal_exponent_of ~format |> Z.to_int in
  let exponent_underapprox = Stdlib.(!exponent - delta) in
  let is_infinity = Stdlib.(max_exponent_in_format < exponent_underapprox) in
  let* () = if is_infinity then pos_inf_shortcut ~format else Normalized () in
  let shifted_denom () = Z.shift_left !denominator sig_size in
  let denom_can_grow () = Z.Compare.(!numerator >= shifted_denom ()) in
  let exponent_too_small () = Stdlib.(!exponent < minimal_exponent) in
  while denom_can_grow () || exponent_too_small () do
    denominator := Z.shift_left !denominator 1 ;
    exponent := Stdlib.(!exponent + 1)
  done ;
  let shifted_denom = Z.shift_left !denominator Stdlib.(sig_size - 1) in
  let num_can_grow () = Z.Compare.(!numerator < shifted_denom) in
  let exponent_can_shrink () = Stdlib.(!exponent > minimal_exponent) in
  while num_can_grow () && exponent_can_shrink () do
    numerator := Z.shift_left !numerator 1 ;
    exponent := Stdlib.(!exponent - 1)
  done ;
  (* Now we can compute the three resulting floating-point numbers, a lower
     approximation, the nearest one, and an over approximation. *)
  let numerator = !numerator and denominator = !denominator in
  let* exponent = normalize_exponent_on_format ~format !exponent in
  let significant, reminder = Integer.e_div_rem numerator denominator in
  let lower_bound = Float.ldexp Integer.(to_float significant) exponent in
  let upper_bound = Float.ldexp Integer.(succ significant |> to_float) exponent in
  (* Determining if the rounding to nearest comes down to round down. *)
  let double_reminder = Z.shift_left reminder 1 in
  let is_zero = Z.(equal double_reminder zero) in
  let is_half_denominator = Z.(equal double_reminder denominator) in
  let less_than_half_denominator = Z.Compare.(double_reminder < denominator) in
  let is_last_bit_zero = Integer.(equal (logand significant one) zero) in
  let tie_to_even = is_half_denominator && is_last_bit_zero in
  let nearest_is_down = is_zero || less_than_half_denominator || tie_to_even in
  (* Assigning each floating-point number to one of the computed bound. *)
  let lower = Float (lower_bound, format) in
  let upper = if is_zero then lower else Float (upper_bound, format) in
  let nearest = if nearest_is_down then lower else upper in
  Normalized { lower ; nearest ; upper ; format }



let is_hexadecimal s =
  Stdlib.(String.length s >= 2 && s.[0] = '0' && (s.[1] = 'X' || s.[1] = 'x'))

let parse_hexadecimal (type f) ~(format : f format) s : f parsed_float option =
  let open Option.Operators in
  let constant f = { lower = f ; nearest = f ; upper = f ; format } in
  let single s = single_of_string s |> single in
  match format with
  | Long   -> let+ n = float_of_string_opt s in constant (long n)
  | Double -> let+ n = float_of_string_opt s in constant (double n)
  | Single -> try Some (single s |> constant) with Failure _ -> None



let pretty_format (type f) fmt (format : f format) =
  match format with
  | Single -> Format.fprintf fmt "single precision"
  | Double -> Format.fprintf fmt "double precision"
  | Long   -> Format.fprintf fmt "long double precision"

let cannot_be_parsed string format =
  Kernel.abort ~current:true
    "The string %s cannot be parsed as a %a floating-point constant"
    string pretty_format format

let empty_string () =
  Kernel.abort ~current:true
    "Parsing an empty string as a floating-point constant."



module Regexp = struct
  let sign = "\\([+-]?\\)"
  let dot  = "[.]"
  let num  = "\\([0-9]*\\)"
  let exp  = "[eE]\\([+-]?[0-9]+\\)"
  let fmt  = "\\([FfDdLl]?\\)"
end

let num_dot_frac_exp = Str.regexp Regexp.(sign ^ num ^ dot ^ num ^ exp ^ fmt)
let num_dot_frac     = Str.regexp Regexp.(sign ^ num ^ dot ^ num ^ fmt)
let num_exp          = Str.regexp Regexp.(sign ^ num ^ exp ^ fmt)

let parse str =
  let length = Stdlib.(String.length str - 1) in
  if Stdlib.(length < 0) then
    empty_string ()
  else if is_hexadecimal str then
    let Format format, suffix = format_of_char str.[length] in
    let str = if suffix then String.sub str 0 length else str in
    match parse_hexadecimal ~format str with
    | None -> cannot_be_parsed str format
    | Some result -> Parsed result
  else if Str.string_match num_dot_frac_exp str 0 then
    let sign          = Str.matched_group 1 str in
    let integral      = Str.matched_group 2 str in
    let fractional    = Str.matched_group 3 str in
    let exponent      = Str.matched_group 4 str in
    let Format format = Str.matched_group 5 str |> format_of_string in
    normalize integral fractional exponent format |> parsed sign
  else if Str.string_match num_dot_frac str 0 then
    let sign          = Str.matched_group 1 str in
    let integral      = Str.matched_group 2 str in
    let fractional    = Str.matched_group 3 str in
    let exponent      = "0" in
    let Format format = Str.matched_group 4 str |> format_of_string in
    normalize integral fractional exponent format |> parsed sign
  else if Str.string_match num_exp str 0 then
    let sign          = Str.matched_group 1 str in
    let integral      = Str.matched_group 2 str in
    let fractional    = "" in
    let exponent      = Str.matched_group 3 str in
    let Format format = Str.matched_group 4 str |> format_of_string in
    normalize integral fractional exponent format |> parsed sign
  else
    let Format format = format_of_string (String.make 1 str.[length]) in
    cannot_be_parsed str format
