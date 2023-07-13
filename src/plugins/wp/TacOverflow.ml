(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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
open Tactical

class overflow =
  object
    inherit Tactical.make
        ~id:"Wp.overflow"
        ~title:"Overflow"
        ~descr:"Split integer overflow into in and out of range"
        ~params:[]

    method select _feedback selection =
      let e = Tactical.selected selection in
      let open Qed.Logic in
      match F.repr e with
      | Fun(f,[v]) ->
        let open Lang.F in
        let min, max = Ctypes.bounds @@ Cint.to_cint f in
        let min, max = e_zint min, e_zint max in

        let lower = p_lt v min and upper = p_lt max v in
        let in_range = p_not (p_or lower upper) in

        let length = e_add (e_sub max min) e_one in
        let overflow = e_add min (e_mod (e_sub v min) length) in

        let replace_with v = fun u -> if u == e then v else raise Not_found in

        Applicable(fun (hs,g) -> [
              "In-Range",
              Conditions.subst (replace_with v) (hs , p_imply in_range g) ;
              "Lower",
              Conditions.subst (replace_with overflow) (hs , p_imply lower g) ;
              "Upper",
              Conditions.subst (replace_with overflow) (hs , p_imply upper g)
            ])
      | _ -> Not_applicable

  end

let overflow = Tactical.export (new overflow)
