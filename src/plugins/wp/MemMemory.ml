(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

let l_havoc = Qed.Engine.F_call "havoc"
let l_set_init = Qed.Engine.F_call "set_init"

let p_eqmem = Lang.extern_fp ~library "eqmem"
let f_havoc = Lang.extern_f ~library ~typecheck:ty_fst_arg ~link:l_havoc "havoc"
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
(* --- Simplifier for 'havoc'                                             --- *)
(* -------------------------------------------------------------------------- *)

(* havoc(m_undef, havoc(_undef,m0,p0,a0), p1,a1) =
   - havoc(m_undef, m0, p1,a1) WHEN included (p1,a1,p0,a0) *)
let r_havoc = function
  | [undef1;m1;p1;a1] -> begin
      match F.repr m1 with
      | L.Fun( f , [_undef0;m0;p0;a0] ) when f == f_havoc -> begin
          let open Qed.Logic in
          match MemAddr.is_included [p0;a0;p1;a1] with
          | Yes -> F.e_fun f_havoc [undef1;m0;p1;a1]
          | _ -> raise Not_found
        end
      | _ -> raise Not_found
    end
  | _ -> raise Not_found

(* havoc(undef,m,p,a)[k] =
   - m[k]     WHEN separated (p,a,k,1)
   - undef[k] WHEN NOT separated (p,a,k,1)
*)
let r_get_havoc es ks =
  match es, ks with
  | [undef;m;p;a],[k] ->
    begin
      match MemAddr.is_separated [p;a;k;e_one] with
      | L.Yes -> F.e_get m k
      | L.No  -> F.e_get undef k
      | _ -> raise Not_found
    end
  | _ -> raise Not_found

(* -------------------------------------------------------------------------- *)
(* --- Simplifiers Registration                                           --- *)
(* -------------------------------------------------------------------------- *)

let () = Context.register
    begin fun () ->
      F.set_builtin f_havoc r_havoc ;
      F.set_builtin_get f_havoc r_get_havoc ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Frame Conditions                                                   --- *)
(* -------------------------------------------------------------------------- *)

module T = Definitions.Trigger

let frames ~addr:p ~offset:n ~sizeof:s ?(basename="mem") tau =
  let t_mem = L.Array(MemAddr.t_addr,tau) in
  let m  = F.e_var (Lang.freshvar ~basename t_mem) in
  let m' = F.e_var (Lang.freshvar ~basename t_mem) in
  let p' = F.e_var (Lang.freshvar ~basename:"q" MemAddr.t_addr) in
  let n' = F.e_var (Lang.freshvar ~basename:"n" L.Int) in
  let mh = F.e_fun f_havoc [m';m;p';n'] in
  let v' = F.e_var (Lang.freshvar ~basename:"v" tau) in
  let meq = F.p_call p_eqmem [m;m';p';n'] in
  let diff = F.p_call MemAddr.p_separated [p;n;p';s] in
  let sep = F.p_call MemAddr.p_separated [p;n;p';n'] in
  let inc = F.p_call MemAddr.p_included [p;n;p';n'] in
  let teq = T.of_pred meq in
  [
    "update" , [] , [diff] , m , e_set m p' v' ;
    "eqmem" , [teq] , [inc;meq] , m , m' ;
    "havoc" , [] , [sep] , m , mh ;
  ]

(* -------------------------------------------------------------------------- *)
(* --- Unsupported Unions                                                 --- *)
(* -------------------------------------------------------------------------- *)

let wkey = Wp_parameters.register_warn_category "union"

let unsupported_union (fd : Cil_types.fieldinfo) =
  if not fd.fcomp.cstruct then
    Wp_parameters.warning ~once:true ~wkey
      "Accessing union fields with WP might be unsound.@\n\
       Please refer to WP manual."

(* -------------------------------------------------------------------------- *)
