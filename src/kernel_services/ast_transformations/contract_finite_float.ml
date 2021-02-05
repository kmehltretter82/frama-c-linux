(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

let rec is_infinite_or_nan pred =
  match pred.pred_content with
  | Pand(a,b) -> is_infinite_or_nan a || is_infinite_or_nan b
  | Papp ({l_var_info = { lv_name = ("\\is_plus_infinity"
                                    |"\\is_minus_infinity"
                                    |"\\is_infinite"
                                    |"\\is_NaN")}},[],[_]) -> true
  | _ -> false

let visit = object
  inherit Cil.nopCilVisitor

  method! vspec spec =
    let requires, behaviors = Extlib.fold_map_opt
        (fun acc bhv ->
           let exists = List.exists (function
               | (Normal,v) ->
                 is_infinite_or_nan v.ip_content.tp_statement
               | _ -> false
             )
               bhv.b_post_cond
           in
           if exists
           then
             let neg_assumes =
               List.map
                 (fun e -> (Logic_const.pnot (e.ip_content.tp_statement)))
                 bhv.b_assumes
             in
             Logic_const.(new_predicate (pors neg_assumes))::acc
           , None
           else acc, Some bhv
        )
        [] spec.spec_behavior
    in
    spec.spec_behavior <- behaviors;
    begin match requires with
    | [] -> ()
    | _ ->
      List.iter
        (fun bhv ->
           if bhv.b_name = Cil.default_behavior_name then
             bhv.b_requires <- requires@bhv.b_requires
        )
        spec.spec_behavior
    end;
    Cil.SkipChildren

end

let run ast =
  if Kernel.ContractFiniteFloat.get () then
    Cil.visitCilFileSameGlobals visit ast

let transform =
  File.register_code_transformation_category "contract_finite_float"

let () =
  File.add_code_transformation_before_cleanup
    ~deps:[(module Kernel.ContractFiniteFloat)]
    transform run
