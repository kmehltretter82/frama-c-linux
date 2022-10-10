(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2022                                               *)
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

open Cil_types


let cmp ~loc bop e1 e2 env kf t_opt =
  let fname = "__gmpq_cmp" in
  let name = Misc.name_of_binop bop in
  (* TODO: [t1_opt] and [t2_opt] could be provided when creating [e1] and
     [e2] *)
  let e1, env = Gmp_gen.Q.create ~loc None env kf e1 in
  let e2, env = Gmp_gen.Q.create ~loc None env kf e2 in
  let _, e, env =
    Env.new_var
      ~loc
      env
      kf
      t_opt
      ~name
      Cil.intType
      (fun v _ ->
         [ Smart_stmt.rtl_call ~loc
             ~result:(Cil.var v)
             ~prefix:""
             fname
             [ e1; e2 ] ])
  in
  Cil.new_exp ~loc (BinOp(bop, e, Cil.zero ~loc, Cil.intType)), env

let new_var_and_init ~loc ?scope ?name env kf t_opt mk_stmts =
  Env.new_var
    ~loc
    ?scope
    ?name
    env
    kf
    t_opt
    (Gmp_types.Q.t ())
    (fun v e -> Gmp.init ~loc e :: mk_stmts v e)

let binop ~loc bop e1 e2 env kf t_opt =
  let name = Gmp.Q.name_arith_bop bop in
  (* TODO: [t1_opt] and [t2_opt] could be provided when creating [e1] and
     [e2] *)
  let e1, env = Gmp_gen.Q.create ~loc None env kf e1 in
  let e2, env = Gmp_gen.Q.create ~loc None env kf e2 in
  let mk_stmts _ e = [ Smart_stmt.rtl_call ~loc
                         ~prefix:""
                         name
                         [ e; e1; e2 ] ] in
  let name = Misc.name_of_binop bop in
  let _, e, env = new_var_and_init ~loc ~name env kf t_opt mk_stmts in
  e, env

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
