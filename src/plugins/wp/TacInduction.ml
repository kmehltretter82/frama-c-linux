(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

open Lang

type env = {
  n : F.var ;
  sigma : F.sigma ;
  mutable hind : F.pred list ;
}

let rec strip env p =
  match F.p_expr p with
  | And ps -> F.p_all (strip env) ps
  | _ ->
      let p = F.p_subst env.sigma p in
      if F.occursp env.n p then
        ( env.hind <- p :: env.hind ; F.p_true )
      else p

let process value n0 ~inf ~sup seq =

  (* Transfrom seq into: hyps => (forall n, goal) *)
  let n = Lang.freshvar ~basename:"n" Qed.Logic.Int in
  let i = Lang.freshvar ~basename:"i" Qed.Logic.Int in
  let vn = F.e_var n in
  let vi = F.e_var i in
  let v0 = F.e_int n0 in
  let sigma = Lang.sigma () in
  F.Subst.add sigma value vn ;
  let env = { n ; sigma ; hind = [] } in
  let hyps = Conditions.map_sequence (strip env) (fst seq) in
  let goal_n = F.p_hyps env.hind @@ F.p_subst sigma (snd seq) in
  let goal_i = F.p_subst_var n vi goal_n in

  (* Base: n = n0 *)
  let goal_base = F.p_imply (F.p_equal vn v0) goal_n in

  (* Hind: n0 <= i < n *)
  let goal_sup =
    if sup
    then
      let hsup = [ F.p_leq v0 vi ; F.p_lt vi vn ] in
      let hind = F.p_forall [i] (F.p_hyps hsup goal_i) in
      F.p_hyps [F.p_lt v0 vn; hind] goal_n
    else F.p_leq value v0 in

  (* Hind: n < i <= n0 *)
  let goal_inf =
    if inf
    then
      let hinf = [ F.p_lt vn vi ; F.p_leq vi v0 ] in
      let hind = F.p_forall [i] (F.p_hyps hinf goal_i) in
      F.p_hyps [F.p_lt vn v0; hind] goal_n
    else F.p_leq v0 value in

  (* All Cases *)
  List.map (fun (name,goal) -> name , (hyps,goal)) [
    "Base" , goal_base ;
    "Induction (sup)" , goal_sup ;
    "Induction (inf)" , goal_inf ;
  ]

(* -------------------------------------------------------------------------- *)
(* --- Induction Tactical                                                 --- *)
(* -------------------------------------------------------------------------- *)

let vbase,pbase = Tactical.spinner ~id:"base"
    ~title:"Base" ~descr:"Value of base case" ()
let vsup,psup = Tactical.checkbox ~id:"hsup"
    ~title:"Sup" ~descr:"Induction over base <= n" ~default:true ()
let vinf,pinf = Tactical.checkbox ~id:"hinf"
    ~title:"Inf" ~descr:"Induction over n <= base" ~default:true ()

class induction =
  object(self)
    inherit Tactical.make
        ~id:"Wp.induction"
        ~title:"Induction"
        ~descr:"Proof by integer induction"
        ~params:[pbase;psup;pinf]

    method select _feedback (s : Tactical.selection) =
      let value = Tactical.selected s in
      if F.is_int value then
        let base = self#get_field vbase in
        let inf = self#get_field vinf in
        let sup = self#get_field vsup in
        Applicable(process value base ~inf ~sup)
      else Not_applicable

  end

let tactical = Tactical.export (new induction)

(* -------------------------------------------------------------------------- *)
