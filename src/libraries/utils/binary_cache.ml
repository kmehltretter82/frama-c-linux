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

let memory_footprint_var_name = "FRAMA_C_MEMORY_FOOTPRINT"

let memory_footprint =
  let error () =
    Cmdline.Kernel_log.error
      "@[Bad value for environment variable@ %s.@ Expected value: \
       integer between@ 1 and 10.@ Using@ default value@ of 2.@]"
      memory_footprint_var_name;
    2
  in
  try
    let i = int_of_string (Sys.getenv memory_footprint_var_name) in
    if i <= 0 || i > 10 then error ()
    else i
  with
  | Not_found -> 2
  | Failure _ -> error ()

let cache_size = 1 lsl (8 + memory_footprint)

(** The caches of this module are lazy, for two reasons:

    - some caches are never used, because the function that created them is
      never called. This typically happens for functors implementing generic
      datastructures, where not all functions are used in every module
      (but every function with a static cache creates its cache nevertheless)

    - Caches must be cleared as soon as some states change, in order to remain
      coherent (for example, when the current project changes). When setting
      multiple command-line options, the caches may be cleared after each option.
      When caches are big, this becomes very time-consuming. To avoid this,
      the functions [clear] do nothing when the caches have not been forced yet.
      (This is not perfect: once a lazy cache has been forced, each 'clear'
      operation becomes costly again.)
*)
let (!!) = Lazy.force

module type Cacheable =
sig
  type t
  val hash : t -> int
  val sentinel : t
  val equal : t -> t -> bool
end

module type Result =
sig
  type t
  val sentinel : t
end

(** The Array_k modules (k = 2, 3, 4) below provide a small interface to arrays
    of k-tuples. However, for performance reasons, they are implemented as
    k-tuples of arrays of the same size. (The difference can be up to 10% on
    some benchmarks.)

    Note that there used to be an even faster implementation (about 2% on the
    same benchmarks) as a flattened array of k times the size. It relied on a
    precise understanding of the low-level OCaml memory model (and the Obj
    module). However, that made some maintainers worry on the rare occasions
    they had to look at this file.
*)

module Array = struct
  include Stdlib.Array
  let clear : 'a t -> 'a -> unit
    = fun t a -> fill t 0 (length t) a
end

module Array_2 =
struct
  type ('a, 'b) t = 'a array * 'b array

  let (clear : ('a, 'b) t -> 'a -> 'b -> unit)
    = fun (ta, tb) a b -> Array.(clear ta a; clear tb b)

  let (make : int -> 'a -> 'b -> ('a, 'b) t)
    = fun size a b -> Array.(make size a, make size b)

  let (set : ('a, 'b) t -> int -> 'a -> 'b -> unit)
    = fun (ta, tb) i a b -> Array.(set ta i a; set tb i b)

  let (get0 : ('a, 'b) t -> int -> 'a)
    = fun (ta, _) i -> Array.get ta i

  let (get1 : ('a, 'b) t -> int -> 'b)
    = fun (_, tb) i -> Array.get tb i
end

module Array_3 =
struct
  type ('a, 'b, 'c) t = 'a array * 'b array * 'c array

  let (clear : ('a, 'b, 'c) t -> 'a -> 'b -> 'c -> unit)
    = fun (ta, tb, tc) a b c -> Array.(clear ta a; clear tb b; clear tc c)

  let (make : int -> 'a -> 'b -> 'c -> ('a, 'b, 'c) t)
    = fun size a b c -> Array.(make size a, make size b, make size c)

  let (set : ('a, 'b, 'c) t -> int -> 'a -> 'b -> 'c -> unit)
    = fun (ta, tb, tc) i a b c -> Array.(set ta i a; set tb i b; set tc i c)

  let (get0 : ('a, 'b, 'c) t -> int -> 'a)
    = fun (ta, _, _) i -> Array.get ta i

  let (get1 : ('a, 'b, 'c) t -> int -> 'b)
    = fun (_, tb, _) i -> Array.get tb i

  let (get2 : ('a, 'b, 'c) t -> int -> 'c)
    = fun (_, _, tc) i -> Array.get tc i
end

module Array_4 =
struct
  type ('a, 'b, 'c, 'd) t = 'a array * 'b array * 'c array * 'd array

  let (clear : ('a , 'b , 'c , 'd) t -> 'a -> 'b -> 'c -> 'd -> unit)
    = fun (ta, tb, tc, td) a b c d ->
      Array.(clear ta a; clear tb b; clear tc c; clear td d)

  let (make : int -> 'a -> 'b -> 'c -> 'd -> ('a , 'b , 'c , 'd) t)
    = fun size a b c d ->
      Array.(make size a, make size b, make size c, make size d)

  let (set : ('a, 'b, 'c, 'd) t -> int -> 'a -> 'b -> 'c -> 'd -> unit)
    = fun (ta, tb, tc, td) i a b c d ->
      Array.(set ta i a; set tb i b; set tc i c; set td i d)

  let (get0 : ('a, 'b, 'c, 'd) t -> int -> 'a)
    = fun (ta, _, _, _) i -> Array.get ta i

  let (get1 : ('a, 'b, 'c, 'd) t -> int -> 'b)
    = fun (_, tb, _, _) i -> Array.get tb i

  let (get2 : ('a, 'b, 'c, 'd) t -> int -> 'c)
    = fun (_, _, tc, _) i -> Array.get tc i

  let (get3 : ('a, 'b, 'c, 'd) t -> int -> 'd)
    = fun (_, _, _, td) i -> Array.get td i
end

module Symmetric_Binary (H: Cacheable) (R: Result) =
struct
  let size = cache_size
  let cache = lazy (Array_3.make size H.sentinel H.sentinel R.sentinel)

  let mask = pred size

  let clear () =
    if Lazy.is_val cache then
      Array_3.clear !!cache H.sentinel H.sentinel R.sentinel

  let hash = H.hash

  let merge f a0 a1 =
    let a0', a1', h0, h1 =
      let h0 = hash a0 in
      let h1 = hash a1 in
      if h0 < h1
      then a0, a1, h0, h1
      else a1, a0, h1, h0
    in
    let has = h1 lsl 5 - h1 + h0
    in
    let has = has land mask in

    if H.equal (Array_3.get0 !!cache has) a0'
    && H.equal (Array_3.get1 !!cache has) a1'
    then begin
      (*      Format.printf "Cache O@.";  *)
      Array_3.get2 !!cache has
    end
    else
      let result = f a0 a1 in
      (*      Format.printf "Cache N@."; *)
      Array_3.set !!cache has a0' a1' result;
      result
end

module Arity_One (H: Cacheable) (R: Result) =
struct
  let size = cache_size
  let cache = lazy (Array_2.make size H.sentinel R.sentinel)

  let mask = pred size

  let clear () =
    if Lazy.is_val cache then
      Array_2.clear !!cache H.sentinel R.sentinel

  let merge f a0 =
    let h0 = H.hash a0 in
    let has = h0 land mask in
    if H.equal (Array_2.get0 !!cache has) a0
    then begin
      (*      Format.printf "Cache O@.";  *)
      Array_2.get1 !!cache has
    end
    else
      let result = f a0 in
      (*      Format.printf "Cache N@."; *)
      Array_2.set !!cache has a0 result;
      result
end

module Arity_Two (H0: Cacheable) (H1: Cacheable) (R: Result) =
struct

  let size = cache_size
  let cache = lazy (Array_3.make size H0.sentinel H1.sentinel R.sentinel)
  let mask = pred size

  let clear () =
    if Lazy.is_val cache then
      Array_3.clear !!cache H0.sentinel H1.sentinel R.sentinel

  let merge f a0 a1 =
    let h0 = H0.hash a0 in
    let h1 = H1.hash a1 in
    let has = h1 lsl 5 - h1 + h0
    in
    let has = has land mask in

    if H0.equal (Array_3.get0 !!cache has) a0
    && H1.equal (Array_3.get1 !!cache has) a1
    then begin
      (*      Format.printf "Cache O@.";  *)
      Array_3.get2 !!cache has
    end
    else
      let result = f a0 a1 in
      (*      Format.printf "Cache N@."; *)
      Array_3.set !!cache has a0 a1 result;
      result
end

module Arity_Three (H0: Cacheable) (H1: Cacheable) (H2: Cacheable) (R: Result) =
struct
  let size = cache_size
  let cache =
    lazy (Array_4.make size H0.sentinel H1.sentinel H2.sentinel R.sentinel)
  let mask = pred size

  let clear () =
    if Lazy.is_val cache then
      Array_4.clear !!cache H0.sentinel H1.sentinel H2.sentinel R.sentinel

  let merge f a0 a1 a2 =
    let h0 = H0.hash a0 in
    let h1 = H1.hash a1 in
    let h2 = H2.hash a2 in
    let has = h0 + 117 * h1 + 2375 * h2 in
    let has = has land mask in

    if H0.equal (Array_4.get0 !!cache has) a0
    && H1.equal (Array_4.get1 !!cache has) a1
    && H2.equal (Array_4.get2 !!cache has) a2
    then begin
      (*      Format.printf "Cache O@.";  *)
      Array_4.get3 !!cache has
    end
    else
      let result = f a0 a1 a2 in
      (*      Format.printf "Cache N@."; *)
      Array_4.set !!cache has a0 a1 a2 result;
      result
end


module Array_Bit =
struct
  let make size =
    let size = (size + 7) lsr 3 in
    Bytes.make size (char_of_int 0)

  let get s i =
    let c = i lsr 3 in
    let b = 1 lsl (i land 7) in
    (Char.code (Bytes.get s c)) land b <> 0

  let set s i v =
    let c = i lsr 3 in
    let b = 1 lsl (i land 7) in
    let oldcontents = Char.code (Bytes.get s c) in
    let newcontents =
      if v
      then b lor oldcontents
      else
        let mask = lnot b in
        oldcontents land mask
    in
    Bytes.set s c (Char.chr newcontents)

  let clear s =
    let zero = char_of_int 0 in
    Bytes.fill s 0 (Bytes.length s) zero
end

module Binary_Predicate (H0: Cacheable) (H1: Cacheable) =
struct
  let size = cache_size
  let cache = lazy (Array_2.make size H0.sentinel H1.sentinel)
  let result = lazy (Array_Bit.make size)
  let mask = pred size

  let clear () =
    if Lazy.is_val cache then
      Array_2.clear !!cache H0.sentinel H1.sentinel;
    if Lazy.is_val result then
      Array_Bit.clear !!result

  let merge f a0 a1 =
    let has =
      let h0 = H0.hash a0 in
      let h1 = H1.hash a1 in
      599 * h0 + h1
    in
    let has = has land mask in

    if H0.equal (Array_2.get0 !!cache has) a0
    && H1.equal (Array_2.get1 !!cache has) a1
    then begin
      (*      Format.printf "Cache O@.";  *)
      Array_Bit.get !!result has
    end
    else
      let r = f a0 a1 in
      (*      Format.printf "Cache N@."; *)
      Array_2.set !!cache has a0 a1;
      Array_Bit.set !!result has r;
      r
end

module Symmetric_Binary_Predicate (H0: Cacheable) =
struct
  let size = cache_size
  let cache = lazy (Array_2.make size H0.sentinel H0.sentinel)
  let result = lazy (Array_Bit.make size)
  let mask = pred size

  let clear () =
    if Lazy.is_val cache then
      Array_2.clear !!cache H0.sentinel H0.sentinel;
    if Lazy.is_val result then
      Array_Bit.clear !!result

  let hash = H0.hash

  let merge f a0 a1 =
    let a0, a1, h0, h1 =
      let h0 = hash a0 in
      let h1 = hash a1 in
      if h0 < h1
      then a0, a1, h0, h1
      else a1, a0, h1, h0
    in
    let has = h1 lsl 5 - h1 + h0
    in
    let has = has land mask in

    if H0.equal (Array_2.get0 !!cache has) a0
    && H0.equal (Array_2.get1 !!cache has) a1
    then begin
      (*      Format.printf "Cache O@.";  *)
      Array_Bit.get !!result has
    end
    else
      let r = f a0 a1 in
      (*      Format.printf "Cache N@."; *)
      Array_2.set !!cache has a0 a1;
      Array_Bit.set !!result has r;
      r
end


(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
