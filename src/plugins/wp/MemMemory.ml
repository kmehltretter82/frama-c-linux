(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(* -------------------------------------------------------------------------- *)
(* --- Memory Model                                                       --- *)
(* -------------------------------------------------------------------------- *)

open Lang
open Lang.F

module L = Qed.Logic

let library = "memory"

let ty_fst_arg = function
  | Some l :: _ -> l
  | _ -> raise Not_found


let l_memcpy = Qed.Engine.F_call "memcpy"
let l_set_init = Qed.Engine.F_call "set_init"

let f_memcpy = Lang.extern_f ~library ~typecheck:ty_fst_arg ~link:l_memcpy "memcpy"
let p_framed = Lang.extern_fp ~coloring:true ~library "framed" (* m-pointer -> prop *)
let p_sconst = Lang.extern_fp ~coloring:true ~library "sconst" (* int-memory -> prop *)
let f_set_init =
  Lang.extern_f ~library ~typecheck:ty_fst_arg ~link:l_set_init "set_init"
let p_cinits = Lang.extern_fp ~coloring:true ~library "cinits" (* initializaton-table -> prop *)
let p_is_init_r = Lang.extern_fp ~library "is_init_range"
let p_monotonic = Lang.extern_fp ~library "monotonic_init"

(* -------------------------------------------------------------------------- *)
(* --- Utilities                                                          --- *)
(* -------------------------------------------------------------------------- *)

let t_mem t = L.Array(MemAddr.t_addr,t)
let t_malloc = L.Array(L.Int,L.Int)
let t_init = L.Array(MemAddr.t_addr,L.Bool)

let cinits memory = p_call p_cinits [ memory ]
let sconst memory = p_call p_sconst [ memory ]
let framed memory = p_call p_framed [ memory ]

(* -------------------------------------------------------------------------- *)
(* --- Simplifier for 'memcpy'                                            --- *)
(* -------------------------------------------------------------------------- *)

(* memcpy(m,m0,q,q0,n)[p] =
   - m[p] WHEN separated (p,1,q,n)
   - m0[q0 ++ p.offset - q.offset] WHEN not separated (p,1,q,n)
*)
let r_get_memcpy es ks =
  match es, ks with
  | [m;m0;q;q0;n],[p] ->
    begin
      match MemAddr.is_separated [p;e_one;q;n] with
      | L.Yes -> F.e_get m p
      | L.No ->
        if p == q then
          F.e_get m0 q0
        else
        if q == q0 then
          F.e_get m0 p
        else
          let i = MemAddr.offset p in
          let j = MemAddr.offset q in
          let q' = MemAddr.shift q0 (F.e_sub i j) in
          F.e_get m0 q'
      | _ -> raise Not_found
    end
  | _ -> raise Not_found

(* -------------------------------------------------------------------------- *)
(* --- Simplifiers Registration                                           --- *)
(* -------------------------------------------------------------------------- *)

let () = Context.register
    begin fun () ->
      F.set_builtin_get f_memcpy r_get_memcpy ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Unsupported Unions                                                 --- *)
(* -------------------------------------------------------------------------- *)

let wkey = Wp_parameters.register_warn_category "union"

let unsupported_union ~model (fd : Cil_types.fieldinfo) =
  if not fd.fcomp.cstruct then
    Wp_parameters.warning ~once:true ~wkey
      "Accessing union fields with %s model might be unsound.@\n\
       Please refer to WP manual." model

(* -------------------------------------------------------------------------- *)
