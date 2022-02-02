(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

let negative n = F.p_leq n F.e_zero
let positive n = F.p_leq F.e_zero n
let concat ~result es = F.e_fun ~result Vlist.f_concat es
let repeat ~result a n = F.e_fun ~result Vlist.f_repeat [a;n]
let sum n = match F.repr n with
  | Add ns -> ns
  | _ -> [n]

(* -------------------------------------------------------------------------- *)
(* --- Induction Tactical                                                 --- *)
(* -------------------------------------------------------------------------- *)

let vmode,pmode =
  Tactical.selector ~id:"seq.side" ~title:"Mode" ~descr:"Unrolling mode"
    ~options:[
      { vid = "left" ; title = "Unroll left" ;
        descr = "Transform (A^n) into (A.A^n-1)" ; value = `Left } ;
      { vid = "right" ; title = "Unroll right" ;
        descr = "Transform (A^n) into (A^n-1.A)" ; value = `Right } ;
      { vid = "sum" ; title = "Concat sum" ;
        descr = "Transform A^(p+q) into (A^p.A^q)" ; value = `Sum }
    ] ()

class sequence =
  object(self)
    inherit Tactical.make
        ~id:"Wp.sequence"
        ~title:"Sequence"
        ~descr:"Unroll repeat-sequence operator"
        ~params:[pmode]

    method select _feedback (s : Tactical.selection) =
      let value = Tactical.selected s in
      match F.repr value with
      | Fun(f,[a;n]) when f == Vlist.f_repeat ->
          let result = F.typeof value in
          let at = Tactical.at s in
          Tactical.Applicable
            begin
              match self#get_field vmode with
              | `Sum ->
                  let ns = sum n in
                  let pos = F.p_all positive ns in
                  let cat = concat ~result (List.map (repeat ~result a) ns) in
                  Tactical.condition "Positive" pos @@
                  Tactical.rewrite ?at [ "Unroll" , pos , value , cat ]
              | `Left ->
                  let p = F.e_add n F.e_minus_one in
                  let unroll = concat ~result [a ; repeat ~result a p] in
                  Tactical.rewrite ?at [
                    "Nil", negative n , value , concat ~result [] ;
                    "Unroll", positive p , value , unroll ;
                  ]
              | `Right ->
                  let p = F.e_add n F.e_minus_one in
                  let unroll = concat ~result [repeat ~result a p ; a] in
                  Tactical.rewrite ?at [
                    "Nil", negative n , value , concat ~result [] ;
                    "Unroll", positive p , value , unroll ;
                  ]
            end
      | _ -> Not_applicable

  end

let tactical = Tactical.export (new sequence)

(* -------------------------------------------------------------------------- *)
