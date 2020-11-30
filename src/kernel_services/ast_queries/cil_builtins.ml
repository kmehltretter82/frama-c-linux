(****************************************************************************)
(*                                                                          *)
(*  Copyright (C) 2001-2003                                                 *)
(*   George C. Necula    <necula@cs.berkeley.edu>                           *)
(*   Scott McPeak        <smcpeak@cs.berkeley.edu>                          *)
(*   Wes Weimer          <weimer@cs.berkeley.edu>                           *)
(*   Ben Liblit          <liblit@cs.berkeley.edu>                           *)
(*  All rights reserved.                                                    *)
(*                                                                          *)
(*  Redistribution and use in source and binary forms, with or without      *)
(*  modification, are permitted provided that the following conditions      *)
(*  are met:                                                                *)
(*                                                                          *)
(*  1. Redistributions of source code must retain the above copyright       *)
(*  notice, this list of conditions and the following disclaimer.           *)
(*                                                                          *)
(*  2. Redistributions in binary form must reproduce the above copyright    *)
(*  notice, this list of conditions and the following disclaimer in the     *)
(*  documentation and/or other materials provided with the distribution.    *)
(*                                                                          *)
(*  3. The names of the contributors may not be used to endorse or          *)
(*  promote products derived from this software without specific prior      *)
(*  written permission.                                                     *)
(*                                                                          *)
(*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS     *)
(*  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT       *)
(*  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS       *)
(*  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE          *)
(*  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,     *)
(*  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,    *)
(*  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;        *)
(*  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER        *)
(*  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT      *)
(*  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN       *)
(*  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         *)
(*  POSSIBILITY OF SUCH DAMAGE.                                             *)
(*                                                                          *)
(*  File modified by CEA (Commissariat à l'énergie atomique et aux          *)
(*                        énergies alternatives)                            *)
(*               and INRIA (Institut National de Recherche en Informatique  *)
(*                          et Automatique).                                *)
(****************************************************************************)

open Cil_datatype
open Cil_types

let typeAddVolatile typ = Cil.typeAddAttributes [Attr ("volatile", [])] typ

module Frama_c_builtins =
  State_builder.Hashtbl
    (Datatype.String.Hashtbl)
    (Cil_datatype.Varinfo)
    (struct
      let name = "Cil.Frama_c_Builtins"
      let dependencies = []
      let size = 3
    end)

let () = Cil.dependency_on_ast Frama_c_builtins.self

let is_builtin v = Cil.hasAttribute "FC_BUILTIN" v.vattr

let is_unused_builtin v = is_builtin v && not v.vreferenced


(* [VP] Should we projectify this ?*)
let special_builtins_table = ref Datatype.String.Set.empty
let special_builtins = Queue.create ()

let is_special_builtin s =
  Queue.fold (fun res f -> res || f s) false special_builtins

let add_special_builtin_family f = Queue.add f special_builtins

let add_special_builtin s =
  special_builtins_table := Datatype.String.Set.add s !special_builtins_table

let () = add_special_builtin_family
    (fun s -> Datatype.String.Set.mem s !special_builtins_table)

let () = List.iter add_special_builtin
    [ "__builtin_stdarg_start"; "__builtin_va_arg";
      "__builtin_va_start"; "__builtin_expect"; "__builtin_next_arg"; ]

module Builtin_functions =
  State_builder.Hashtbl
    (Datatype.String.Hashtbl)
    (Datatype.Triple(Typ)(Datatype.List(Typ))(Datatype.Bool))
    (struct
      let name = "Builtin_functions"
      let dependencies = [ Cil.selfMachine ]
      let size = 49
    end)

(* [add_builtin ?prefix s t l b] adds the function [prefix ^ s] to the list of
   built-ins. [t] is the return type and [l] is the list of parameter types.
   [b] is true if the built-in is variadic, false otherwise. *)
let add_builtin ?(prefix="__builtin_") s t l b =
  Builtin_functions.add (prefix ^ s) (t, l, b)

let () = Cil.registerAttribute "FC_BUILTIN" (AttrName true)

let intType = Cil.intType
let voidPtrType = Cil.voidPtrType
let charConstPtrType = Cil.charConstPtrType
let voidConstPtrType = Cil.voidConstPtrType
let charPtrType = Cil.charPtrType
let voidType = Cil.voidType
let floatType = Cil.floatType
let doubleType = Cil.doubleType
let longDoubleType = Cil.longDoubleType
let longType = Cil.longType
let longLongType = Cil.longLongType
let uintType = Cil.uintType
let ulongType = Cil.ulongType
let ulongLongType = Cil.ulongLongType
let intPtrType = Cil.intPtrType

(* Initialize the builtin functions after the machine has been initialized. *)
let initGccBuiltins () : unit =
  (* Complex types are unsupported so the following built-ins can't be added :
     - cabs, cabsf, cabsh
     - cacos, cacosf, cacosl, cacosh, cacoshf, cacoshl
     - carg, cargf, cargl
     - casin, casinf, casinl, casinh, casinhf, casinhl
     - catan, catanf, catanl, catanh, catanhf, catanhl
     - ccos, ccosf, ccosl, ccosh, ccoshf, ccoshl
     - cexp, cexpf, cexpl
     - cimag, cimagf, cimagl
     - clog, clogf, clogl
     - conj, conjf, conjl
     - cpow, cpowf, cpowl
     - cproj, cprojf, cprojl
     - creal, crealf, creall
     - csin, csinf, csinl, csinh, csinhf, csinhl
     - csqrt, csqrtf, csqrtl
     - ctan, ctanf, ctanl, ctanh, ctanhf, ctanhl
  *)

  (* [wint_t] isn't specified in [theMachine] so the following built-ins that
     use this type can't be added :
     - iswalnum
     - iswalpha
     - iswblank
     - iswcntrl
     - iswdigit
     - iswgraph
     - iswlower
     - iswprint
     - iswpunct
     - iswspace
     - iswupper
     - iswxdigit
     - towlower
     - towupper
  *)

  let sizeType = Cil.theMachine.upointType in
  let add = add_builtin in

  add "__fprintf_chk"
    intType
    (* first argument is really FILE*, not void*, but we don't want to build in
       the definition for FILE *)
    [ voidPtrType; intType; charConstPtrType ]
    true;
  add "__memcpy_chk"
    voidPtrType
    [ voidPtrType; voidConstPtrType; sizeType; sizeType ]
    false;
  add "__memmove_chk"
    voidPtrType [ voidPtrType; voidConstPtrType; sizeType; sizeType ] false;
  add "__mempcpy_chk"
    voidPtrType [ voidPtrType; voidConstPtrType; sizeType; sizeType ] false;
  add "__memset_chk"
    voidPtrType [ voidPtrType; intType; sizeType; sizeType ] false;
  add "__printf_chk" intType [ intType; charConstPtrType ] true;
  add "__snprintf_chk"
    intType [ charPtrType; sizeType; intType; sizeType; charConstPtrType ]
    true;
  add "__sprintf_chk"
    intType [ charPtrType; intType; sizeType; charConstPtrType ] true;
  add "__stpcpy_chk"
    charPtrType [ charPtrType; charConstPtrType; sizeType ] false;
  add "__strcat_chk"
    charPtrType [ charPtrType; charConstPtrType; sizeType ] false;
  add "__strcpy_chk"
    charPtrType [ charPtrType; charConstPtrType; sizeType ] false;
  add "__strncat_chk"
    charPtrType [ charPtrType; charConstPtrType; sizeType; sizeType ] false;
  add "__strncpy_chk"
    charPtrType [ charPtrType; charConstPtrType; sizeType; sizeType ] false;
  add "__vfprintf_chk"
    intType
    (* first argument is really FILE*, not void*, but we don't want to build in
       the definition for FILE *)
    [ voidPtrType; intType; charConstPtrType; TBuiltin_va_list [] ]
    false;
  add "__vprintf_chk"
    intType [ intType; charConstPtrType; TBuiltin_va_list [] ] false;
  add "__vsnprintf_chk"
    intType
    [ charPtrType; sizeType; intType; sizeType; charConstPtrType;
      TBuiltin_va_list [] ]
    false;
  add "__vsprintf_chk"
    intType
    [ charPtrType; intType; sizeType; charConstPtrType; TBuiltin_va_list [] ]
    false;

  add "_Exit" voidType [ intType ] false;
  add "exit" voidType [ intType ] false;

  add "alloca" voidPtrType [ sizeType ] false;

  add "malloc" voidPtrType [ sizeType ] false;
  add "calloc" voidPtrType [ sizeType; sizeType ] false;
  add "realloc" voidPtrType [ voidPtrType; sizeType ] false;
  add "free" voidType [ voidPtrType ] false;

  add "abs" intType [ intType ] false;
  add "labs" longType [ longType ] false;
  add "llabs" longLongType [ longLongType] false;
  (* Can't add imaxabs because it takes intmax_t as parameter *)

  add "acos" doubleType [ doubleType ] false;
  add "acosf" floatType [ floatType ] false;
  add "acosl" longDoubleType [ longDoubleType ] false;
  add "acosh" doubleType [ doubleType ] false;
  add "acoshf" floatType [ floatType ] false;
  add "acoshl" longDoubleType [ longDoubleType ] false;

  add "asin" doubleType [ doubleType ] false;
  add "asinf" floatType [ floatType ] false;
  add "asinl" longDoubleType [ longDoubleType ] false;
  add "asinh" doubleType [ doubleType ] false;
  add "asinhf" floatType [ floatType ] false;
  add "asinhl" longDoubleType [ longDoubleType ] false;

  add "atan" doubleType [ doubleType ] false;
  add "atanf" floatType [ floatType ] false;
  add "atanl" longDoubleType [ longDoubleType ] false;
  add "atanh" doubleType [ doubleType ] false;
  add "atanhf" floatType [ floatType ] false;
  add "atanhl" longDoubleType [ longDoubleType ] false;

  add "atan2" doubleType [ doubleType; doubleType ] false;
  add "atan2f" floatType [ floatType; floatType ] false;
  add "atan2l" longDoubleType [ longDoubleType;
                                longDoubleType ] false;

  let uint16t = Cil.uint16_t () in
  add "bswap16" uint16t [uint16t] false;

  let uint32t = Cil.uint32_t () in
  add "bswap32" uint32t [uint32t] false;

  let uint64t = Cil.uint64_t () in
  add "bswap64" uint64t [uint64t] false;

  add "cbrt" doubleType [ doubleType ] false;
  add "cbrtf" floatType [ floatType ] false;
  add "cbrtl" longDoubleType [ longDoubleType ] false;

  add "ceil" doubleType [ doubleType ] false;
  add "ceilf" floatType [ floatType ] false;
  add "ceill" longDoubleType [ longDoubleType ] false;

  add "cos" doubleType [ doubleType ] false;
  add "cosf" floatType [ floatType ] false;
  add "cosl" longDoubleType [ longDoubleType ] false;

  add "cosh" doubleType [ doubleType ] false;
  add "coshf" floatType [ floatType ] false;
  add "coshl" longDoubleType [ longDoubleType ] false;

  add "constant_p" intType [ intType ] false;

  add "copysign" doubleType [ doubleType; doubleType ] false;
  add "copysignf" floatType [ floatType; floatType ] false;
  add "copysignl" longDoubleType [ longDoubleType; longDoubleType ] false;

  add "erfc" doubleType [ doubleType ] false;
  add "erfcf" floatType [ floatType ] false;
  add "erfcl" longDoubleType [ longDoubleType ] false;

  add "erf" doubleType [ doubleType ] false;
  add "erff" floatType [ floatType ] false;
  add "erfl" longDoubleType [ longDoubleType ] false;

  add "exp" doubleType [ doubleType ] false;
  add "expf" floatType [ floatType ] false;
  add "expl" longDoubleType [ longDoubleType ] false;

  add "exp2" doubleType [ doubleType ] false;
  add "exp2f" floatType [ floatType ] false;
  add "exp2l" longDoubleType [ longDoubleType ] false;

  add "expm1" doubleType [ doubleType ] false;
  add "expm1f" floatType [ floatType ] false;
  add "expm1l" longDoubleType [ longDoubleType ] false;

  add "expect" longType [ longType; longType ] false;

  add "fabs" doubleType [ doubleType ] false;
  add "fabsf" floatType [ floatType ] false;
  add "fabsl" longDoubleType [ longDoubleType ] false;

  add "fdim" doubleType [ doubleType; doubleType ] false;
  add "fdimf" floatType [ floatType; floatType ] false;
  add "fdiml" longDoubleType [ longDoubleType; longDoubleType ] false;

  add "ffs" intType [ uintType ] false;
  add "ffsl" intType [ ulongType ] false;
  add "ffsll" intType [ ulongLongType ] false;
  add "frame_address" voidPtrType [ uintType ] false;

  add "floor" doubleType [ doubleType ] false;
  add "floorf" floatType [ floatType ] false;
  add "floorl" longDoubleType [ longDoubleType ] false;

  add "fma" doubleType [ doubleType; doubleType; doubleType ] false;
  add "fmaf" floatType [ floatType; floatType; floatType ] false;
  add "fmal"
    longDoubleType [ longDoubleType; longDoubleType; longDoubleType ] false;

  add "fmax" doubleType [ doubleType; doubleType ] false;
  add "fmaxf" floatType [ floatType; floatType ] false;
  add "fmaxl" longDoubleType [ longDoubleType; longDoubleType ] false;

  add "fmin" doubleType [ doubleType; doubleType ] false;
  add "fminf" floatType [ floatType; floatType ] false;
  add "fminl" longDoubleType [ longDoubleType; longDoubleType ] false;

  add "huge_val" doubleType [] false;
  add "huge_valf" floatType [] false;
  add "huge_vall" longDoubleType [] false;

  add "hypot" doubleType [ doubleType; doubleType ] false;
  add "hypotf" floatType [ floatType; floatType ] false;
  add "hypotl" longDoubleType [ longDoubleType; longDoubleType ] false;

  add "ia32_lfence" voidType [] false;
  add "ia32_mfence" voidType [] false;
  add "ia32_sfence" voidType [] false;

  add "ilogb" doubleType [ doubleType ] false;
  add "ilogbf" floatType [ floatType ] false;
  add "ilogbl" longDoubleType [ longDoubleType ] false;

  add "inf" doubleType [] false;
  add "inff" floatType [] false;
  add "infl" longDoubleType [] false;

  add "isblank" intType [ intType ] false;
  add "isalnum" intType [ intType ] false;
  add "isalpha" intType [ intType ] false;
  add "iscntrl" intType [ intType ] false;
  add "isdigit" intType [ intType ] false;
  add "isgraph" intType [ intType ] false;
  add "islower" intType [ intType ] false;
  add "isprint" intType [ intType ] false;
  add "ispunct" intType [ intType ] false;
  add "isspace" intType [ intType ] false;
  add "isupper" intType [ intType ] false;
  add "isxdigit" intType [ intType ] false;

  add "fmod" doubleType [ doubleType ] false;
  add "fmodf" floatType [ floatType ] false;
  add "fmodl" longDoubleType [ longDoubleType ] false;

  add "frexp" doubleType [ doubleType; intPtrType ] false;
  add "frexpf" floatType [ floatType; intPtrType  ] false;
  add "frexpl" longDoubleType [ longDoubleType; intPtrType  ] false;

  add "ldexp" doubleType [ doubleType; intType ] false;
  add "ldexpf" floatType [ floatType; intType  ] false;
  add "ldexpl" longDoubleType [ longDoubleType; intType  ] false;

  add "lgamma" doubleType [ doubleType ] false;
  add "lgammaf" floatType [ floatType ] false;
  add "lgammal" longDoubleType [ longDoubleType ] false;

  add "llrint" longLongType [ doubleType ] false;
  add "llrintf" longLongType [ floatType ] false;
  add "llrintl" longLongType [ longDoubleType ] false;

  add "llround" longLongType [ doubleType ] false;
  add "llroundf" longLongType [ floatType ] false;
  add "llroundl" longLongType [ longDoubleType ] false;

  add "log" doubleType [ doubleType ] false;
  add "logf" floatType [ floatType ] false;
  add "logl" longDoubleType [ longDoubleType ] false;

  add "log10" doubleType [ doubleType ] false;
  add "log10f" floatType [ floatType ] false;
  add "log10l" longDoubleType [ longDoubleType ] false;

  add "log1p" doubleType [ doubleType ] false;
  add "log1pf" floatType [ floatType ] false;
  add "log1pl" longDoubleType [ longDoubleType ] false;

  add "log2" doubleType [ doubleType ] false;
  add "log2f" floatType [ floatType ] false;
  add "log2l" longDoubleType [ longDoubleType ] false;

  add "logb" doubleType [ doubleType ] false;
  add "logbf" floatType [ floatType ] false;
  add "logbl" longDoubleType [ longDoubleType ] false;

  add "lrint" longType [ doubleType ] false;
  add "lrintf" longType [ floatType ] false;
  add "lrintl" longType [ longDoubleType ] false;

  add "lround" longType [ doubleType ] false;
  add "lroundf" longType [ floatType ] false;
  add "lroundl" longType [ longDoubleType ] false;

  add "memchr" voidPtrType [ voidConstPtrType; intType; sizeType ] false;
  add "memcmp" intType [ voidConstPtrType; voidConstPtrType; sizeType ] false;
  add "memcpy" voidPtrType [ voidPtrType; voidConstPtrType; sizeType ] false;
  add "mempcpy" voidPtrType [ voidPtrType; voidConstPtrType; sizeType ] false;
  add "memset" voidPtrType [ voidPtrType; intType; sizeType ] false;

  add "modf" doubleType [ doubleType; TPtr(doubleType,[]) ] false;
  add "modff" floatType [ floatType; TPtr(floatType,[]) ] false;
  add "modfl"
    longDoubleType [ longDoubleType; TPtr(longDoubleType, []) ] false;

  add "nan" doubleType [ charConstPtrType ] false;
  add "nanf" floatType [ charConstPtrType ] false;
  add "nanl" longDoubleType [ charConstPtrType ] false;
  add "nans" doubleType [ charConstPtrType ] false;
  add "nansf" floatType [ charConstPtrType ] false;
  add "nansl" longDoubleType [ charConstPtrType ] false;

  add "nearbyint" doubleType [ doubleType ] false;
  add "nearbyintf" floatType [ floatType ] false;
  add "nearbyintl" longDoubleType [ longDoubleType ] false;

  add "nextafter" doubleType [ doubleType; doubleType ] false;
  add "nextafterf" floatType [ floatType; floatType ] false;
  add "nextafterl" longDoubleType [ longDoubleType; longDoubleType ] false;

  add "nexttoward" doubleType [ doubleType; longDoubleType ] false;
  add "nexttowardf" floatType [ floatType; longDoubleType ] false;
  add "nexttowardl" longDoubleType [ longDoubleType; longDoubleType ] false;

  add "object_size" sizeType [ voidPtrType; intType ] false;

  add "parity" intType [ uintType ] false;
  add "parityl" intType [ ulongType ] false;
  add "parityll" intType [ ulongLongType ] false;

  add "pow" doubleType [ doubleType; doubleType ] false;
  add "powf" floatType [ floatType; floatType ] false;
  add "powl" longDoubleType [ longDoubleType; longDoubleType ] false;

  add "powi" doubleType [ doubleType; intType ] false;
  add "powif" floatType [ floatType; intType ] false;
  add "powil" longDoubleType [ longDoubleType; intType ] false;

  add "prefetch" voidType [ voidConstPtrType ] true;

  add "printf" intType [ charConstPtrType ] true;
  add "vprintf" intType [ charConstPtrType; TBuiltin_va_list [] ] false;
  (* For [fprintf] and [vfprintf] the first argument is really FILE*, not void*,
     but we don't want to build in the definition for FILE. *)
  add "fprintf" intType [ voidPtrType; charConstPtrType ] true;
  add "vfprintf"
    intType [ voidPtrType; charConstPtrType; TBuiltin_va_list [] ] false;
  add "sprintf" intType [ charPtrType; charConstPtrType ] true;
  add "vsprintf"
    intType [ charPtrType; charConstPtrType; TBuiltin_va_list [] ] false;
  add "snprintf" intType [ charPtrType; sizeType; charConstPtrType ] true;
  add "vsnprintf"
    intType
    [ charPtrType; sizeType; charConstPtrType; TBuiltin_va_list [] ]
    false;

  add "putchar" intType [ intType ] false;

  add "puts" intType [ charConstPtrType ] false;
  (* The second argument of [fputs] is really FILE*, not void*, but we
     don't want to build in the definition for FILE. *)
  add "fputs" intType [ charConstPtrType; voidPtrType ] false;

  add "remainder" doubleType [ doubleType; doubleType ] false;
  add "remainderf" floatType [ floatType; floatType ] false;
  add "remainderl" longDoubleType [ longDoubleType; longDoubleType ] false;

  add "remquo" doubleType [ doubleType; doubleType; intPtrType ] false;
  add "remquof" floatType [ floatType; floatType; intPtrType ] false;
  add "remquol"
    longDoubleType [ longDoubleType; longDoubleType; intPtrType ] false;

  add "return" voidType [ voidConstPtrType ] false;
  add "return_address" voidPtrType [ uintType ] false;

  add "rint" doubleType [ doubleType ] false;
  add "rintf" floatType [ floatType ] false;
  add "rintl" longDoubleType [ longDoubleType ] false;

  add "round" doubleType [ doubleType ] false;
  add "roundf" floatType [ floatType ] false;
  add "roundl" longDoubleType [ longDoubleType ] false;

  add "scalbln" doubleType [ doubleType; longType ] false;
  add "scalblnf" floatType [ floatType; longType ] false;
  add "scalblnl" longDoubleType [ longDoubleType; longType ] false;

  add "scalbn" doubleType [ doubleType; intType ] false;
  add "scalbnf" floatType [ floatType; intType ] false;
  add "scalbnl" longDoubleType [ longDoubleType; intType ] false;

  add "scanf" intType [ charConstPtrType ] true;
  add "vscanf" intType [ charConstPtrType; TBuiltin_va_list [] ] false;
  (* For [fscanf] and [vfscanf] the first argument is really FILE*, not void*,
     but we don't want to build in the definition for FILE. *)
  add "fscanf" intType [ voidPtrType; charConstPtrType ] true;
  add "vfscanf"
    intType [ voidPtrType; charConstPtrType; TBuiltin_va_list [] ] false;
  add "sscanf" intType [ charConstPtrType; charConstPtrType ] true;
  add "vsscanf"
    intType [ charConstPtrType; charConstPtrType; TBuiltin_va_list [] ] false;

  add "sin" doubleType [ doubleType ] false;
  add "sinf" floatType [ floatType ] false;
  add "sinl" longDoubleType [ longDoubleType ] false;

  add "sinh" doubleType [ doubleType ] false;
  add "sinhf" floatType [ floatType ] false;
  add "sinhl" longDoubleType [ longDoubleType ] false;

  add "sqrt" doubleType [ doubleType ] false;
  add "sqrtf" floatType [ floatType ] false;
  add "sqrtl" longDoubleType [ longDoubleType ] false;

  add "stpcpy" charPtrType [ charPtrType; charConstPtrType ] false;
  add "strcat" charPtrType [ charPtrType; charConstPtrType ] false;
  add "strchr" charPtrType [ charPtrType; intType ] false;
  add "strcmp" intType [ charConstPtrType; charConstPtrType ] false;
  add "strcpy" charPtrType [ charPtrType; charConstPtrType ] false;
  add "strcspn" sizeType [ charConstPtrType; charConstPtrType ] false;
  add "strlen" sizeType [ charConstPtrType ] false;
  add "strncat" charPtrType [ charPtrType; charConstPtrType; sizeType ] false;
  add "strncmp" intType [ charConstPtrType; charConstPtrType; sizeType ] false;
  add "strncpy" charPtrType [ charPtrType; charConstPtrType; sizeType ] false;
  add "strspn" sizeType [ charConstPtrType; charConstPtrType ] false;
  add "strpbrk" charPtrType [ charConstPtrType; charConstPtrType ] false;
  add "strrchr" charPtrType [ charConstPtrType; intType ] false;
  add "strstr" charPtrType [ charConstPtrType; charConstPtrType ] false;
  (* When we parse builtin_types_compatible_p, we change its interface *)
  add "types_compatible_p"
    intType
    [ Cil.theMachine.typeOfSizeOf;(* Sizeof the type *)
      Cil.theMachine.typeOfSizeOf (* Sizeof the type *) ]
    false;
  add "tan" doubleType [ doubleType ] false;
  add "tanf" floatType [ floatType ] false;
  add "tanl" longDoubleType [ longDoubleType ] false;

  add "tanh" doubleType [ doubleType ] false;
  add "tanhf" floatType [ floatType ] false;
  add "tanhl" longDoubleType [ longDoubleType ] false;

  add "tgamma" doubleType [ doubleType ] false;
  add "tgammaf" floatType [ floatType ] false;
  add "tgammal" longDoubleType [ longDoubleType ] false;

  add "tolower" intType [ intType ] false;
  add "toupper" intType [ intType ] false;

  add "trunc" doubleType [ doubleType ] false;
  add "truncf" floatType [ floatType ] false;
  add "truncl" longDoubleType [ longDoubleType ] false;

  add "unreachable" voidType [ ] false;

  let int8_t = Some Cil.scharType in
  let int16_t = try Some (Cil.int16_t ()) with Not_found -> None in
  let int32_t = try Some (Cil.int32_t ()) with Not_found -> None in
  let int64_t = try Some (Cil.int64_t ()) with Not_found -> None in
  let uint8_t = Some Cil.ucharType in
  let uint16_t = try Some (Cil.uint16_t ()) with Not_found -> None in
  let uint32_t = try Some (Cil.uint32_t ()) with Not_found -> None in
  let uint64_t = try Some (Cil.uint64_t ()) with Not_found -> None in

  (* Binary monomorphic versions of atomic builtins *)
  let atomic_instances =
    [int8_t, "_int8_t";
     int16_t,"_int16_t";
     int32_t,"_int32_t";
     int64_t,"_int64_t";
     uint8_t, "_uint8_t";
     uint16_t,"_uint16_t";
     uint32_t,"_uint32_t";
     uint64_t,"_uint64_t"]
  in
  let add_sync (typ,name) f =
    match typ with
    | Some typ ->
      add ~prefix:"__sync_" (f^name) typ [ TPtr(typeAddVolatile typ,[]); typ] true
    | None -> ()
  in
  let add_sync f =
    List.iter (fun typ -> add_sync typ f) atomic_instances
  in
  add_sync "fetch_and_add";
  add_sync "fetch_and_sub";
  add_sync "fetch_and_or";
  add_sync "fetch_and_and";
  add_sync "fetch_and_xor";
  add_sync "fetch_and_nand";
  add_sync "add_and_fetch";
  add_sync "sub_and_fetch";
  add_sync "or_and_fetch";
  add_sync "and_and_fetch";
  add_sync "xor_and_fetch";
  add_sync "nand_and_fetch";
  add_sync "lock_test_and_set";
  List.iter (fun (typ,n) ->
      match typ with
      | Some typ ->
        add ~prefix:"" ("__sync_bool_compare_and_swap"^n)
          intType
          [ TPtr(typeAddVolatile typ,[]); typ ; typ]
          true
      | None -> ())
    atomic_instances;
  List.iter (fun (typ,n) ->
      match typ with
      | Some typ ->
        add ~prefix:"" ("__sync_val_compare_and_swap"^n)
          typ
          [ TPtr(typeAddVolatile typ,[]); typ ; typ]
          true
      | None -> ())
    atomic_instances;
  List.iter (fun (typ,n) ->
      match typ with
      | Some typ ->
        add ~prefix:"" ("__sync_lock_release"^n)
          voidType
          [ TPtr(typeAddVolatile typ,[]) ]
          true;
      | None -> ())
    atomic_instances;
  add ~prefix:"" "__sync_synchronize" voidType [] true
;;

(* Builtins related to va_list. Added to all non-msvc machdeps, because
   Cabs2cil supposes they exist. *)
let initVABuiltins () =
  let hasbva = Cil.theMachine.theMachine.has__builtin_va_list in
  let add = add_builtin in
  add "next_arg"
    (* When we parse builtin_next_arg we drop the second argument *)
    (if hasbva then TBuiltin_va_list [] else voidPtrType) [] false;
  if hasbva then begin
    add "va_end" voidType [ TBuiltin_va_list [] ] false;
    add "varargs_start" voidType [ TBuiltin_va_list [] ] false;
    (* When we parse builtin_{va,stdarg}_start, we drop the second argument *)
    add "va_start" voidType [ TBuiltin_va_list [] ] false;
    add "stdarg_start" voidType [ TBuiltin_va_list [] ] false;
    (* When we parse builtin_va_arg we change its interface *)
    add "va_arg"
      voidType
      [ TBuiltin_va_list [];
        Cil.theMachine.typeOfSizeOf;(* Sizeof the type *)
        voidPtrType (* Ptr to res *) ]
      false;
    add "va_copy" voidType [ TBuiltin_va_list []; TBuiltin_va_list [] ] false;
  end

let initMsvcBuiltins () : unit =
  (** Take a number of wide string literals *)
  Builtin_functions.add "__annotation" (voidType, [ ], true)

let init_common_builtins () =
  add_builtin
    "offsetof"
    Cil.theMachine.typeOfSizeOf
    [ Cil.theMachine.typeOfSizeOf ]
    false

let init_builtins () =
  if not (Cil.selfMachine_is_computed ()) then
    Kernel.fatal ~current:true "You must call initCIL before init_builtins" ;
  if Builtin_functions.length () <> 0 then
    Kernel.fatal ~current:true "Cil builtins already initialized." ;
  init_common_builtins ();
  if Cil.msvcMode () then
    initMsvcBuiltins ()
  else begin
    initVABuiltins ();
    if Cil.gccMode () then initGccBuiltins ();
  end

(** This is used as the location of the prototypes of builtin functions. *)
let builtinLoc: location = Location.unknown

let () =
  Cil.init_builtins_ref := init_builtins
