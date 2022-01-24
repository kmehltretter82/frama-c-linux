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

open Tactical
open Conditions

class clear =
  object(_)
    inherit Tactical.make ~id:"Wp.clear"
        ~title:"Clear"
        ~descr:"Remove Hypothesis"
        ~params:[]

    method select _feedback sel =
      match sel with
      | Clause(Step step) ->
          let removed = [ "Cleared hypothesis", Conditions.Have Lang.F.p_true] in
          Applicable (Tactical.replace ~at:step.id removed)
      | Inside(Step step, remove) ->
          let cond p = (* keep original kind of step *)
            match step.condition with
            | Type _ -> Type p
            | Have _ -> Have p
            | When _ -> When p
            | Core _ -> Core p
            | Init _ -> Init p
            | _ -> assert false (* see above pattern matching *)
          in
          let rec collect p =
            match Lang.F.p_expr p with
            | And ps -> collect_list ps
            | _ -> [ p ]
          and collect_list = function
            | [] -> []
            | p :: l -> List.rev_append (List.rev @@ collect p) (collect_list l)
          in
          begin match step.condition with
            | Type p | Have p | When p | Core p | Init p ->
                let ps = Lang.F.e_props @@ collect p in
                if List.mem remove ps then
                  let ps = List.filter (fun x -> x <> remove) ps in
                  let cond = cond @@ Lang.F.p_bool @@ Lang.F.e_and ps in
                  let filtered = [ "Filtered", cond ] in
                  Applicable (Tactical.replace ~at:step.id filtered)
                else
                  Not_applicable

            | _ -> Not_applicable
          end
      | _ -> Not_applicable
  end

let tactical = Tactical.export (new clear)
