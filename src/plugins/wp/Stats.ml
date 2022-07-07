(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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
(* --- Performance Reporting                                              --- *)
(* -------------------------------------------------------------------------- *)

open VCS

type pstats = {
  time: float; (* cumulated, in seconds *)
  success: int; (* cumulated number of success *)
}

type stats = {
  provers : (VCS.prover * pstats) list ;
  tactics : int ;
  proved : int ;
  timeout : int ;
  unknown : int ;
  noresult : int ;
  failed : int ;
  cached : int ;
}

(* -------------------------------------------------------------------------- *)
(* --- Prover Stats                                                       --- *)
(* -------------------------------------------------------------------------- *)

module Plist = Qed.Listmap.Make
    (struct
      type t = VCS.prover
      let equal a b = a==b || (VCS.cmp_prover a b = 0)
      let compare = VCS.cmp_prover
    end)

let pzero = {
  time = 0.0 ;
  success = 0 ;
}

let padd a b =
  if a == pzero then b else
  if b == pzero then a else
    {
      time = a.time +. b.time ;
      success = a.success + b.success ;
    }

let pmerge = Plist.union (fun _ a b -> padd a b)


let pqed r =
  { time = r.solver_time ; success = if VCS.is_valid r then 1 else 0 }

let presult r =
  { time = r.prover_time ; success = if VCS.is_valid r then 1 else 0 }

let psolver r =
  { time = r.solver_time ; success = 0 }

(* -------------------------------------------------------------------------- *)
(* --- Global Stats                                                       --- *)
(* -------------------------------------------------------------------------- *)

let zero = {
  provers = [];
  tactics = 0;
  proved = 0;
  timeout = 0;
  unknown = 0 ;
  noresult = 0 ;
  failed = 0 ;
  cached = 0 ;
}

let choose (p,rp) (q,rq) =
  if VCS.leq rp rq then (p,rp) else (q,rq)

let consolidated = function
  | [] -> NoResult, 0, []
  | u::w as results ->
    let p,r = List.fold_left choose u w in
    let cached =
      p = Qed ||
      if VCS.is_valid r then r.cached else
        List.for_all
          (fun (_,r) -> r.VCS.cached || not (VCS.is_verdict r))
          results in
    r.verdict,
    (if cached then 1 else 0),
    if p = Qed then [Qed,pqed r]
    else
    if VCS.is_valid r
    then pmerge [Qed,psolver r] [p,presult r]
    else []

let results prs =
  let verdict, cached, provers = consolidated prs in
  match verdict with
  | Valid ->
    { zero with provers ; cached ; proved = 1 }
  | Timeout | Stepout ->
    { zero with provers ; cached ; timeout = 1 }
  | Unknown ->
    { zero with provers ; cached ; unknown = 1 }
  | NoResult | Computing _ ->
    { zero with provers ; cached ; noresult = 1 }
  | Failed | Invalid ->
    { zero with provers ; cached ; failed = 1 }

let add a b =
  if a == zero then b else
  if b == zero then a else
    {
      provers = pmerge a.provers b.provers ;
      tactics = a.tactics + b.tactics ;
      proved = a.proved + b.proved ;
      timeout = a.timeout + b.timeout ;
      unknown = a.unknown + b.unknown ;
      noresult = a.noresult + b.noresult ;
      failed = a.failed + b.failed ;
      cached = a.cached + b.cached ;
    }

let tactical ~qed children =
  let provers =
    [Qed,{ time = qed ; success = if children = [] then 1 else 0 }]
  in List.fold_left add { zero with provers ; tactics = 1 } children

(* -------------------------------------------------------------------------- *)
(* --- Utils                                                              --- *)
(* -------------------------------------------------------------------------- *)

let proofs s =
  s.proved + s.timeout + s.unknown + s.noresult + s.failed

let complete s = s.proved = proofs s

let pretty fmt s =
  let vp = s.proved in
  let np = proofs s in
  if vp < np && np > 1 then
    Format.fprintf fmt " (Proofs %d/%d)" vp np ;
  if s.tactics > 1 then
    Format.fprintf fmt " (Tactics %d)" s.tactics
  else if np <= 1 && s.tactics = 1 then
    Format.fprintf fmt " (Tactic)" ;
  let shell = Wp_parameters.has_dkey dkey_shell in
  List.iter
    (fun (p,pr) ->
       Format.fprintf fmt " (%a" VCS.pp_prover p ;
       if pr.success > 0 && np > 1 then
         Format.fprintf fmt " %d/%d" pr.success np ;
       if not shell && pr.time > Rformat.epsilon then
         Format.fprintf fmt " %a" Rformat.pp_time pr.time ;
       Format.fprintf fmt ")"
    ) s.provers ;
  if 0 < s.cached then
    if s.cached = np then
      Format.fprintf fmt " (Cached)"
    else
      Format.fprintf fmt " (Cached %d/%d)" s.cached np

(* -------------------------------------------------------------------------- *)
(* --- Yojson                                                             --- *)
(* -------------------------------------------------------------------------- *)

let to_json_p (p,r) : Json.t = `Assoc [
    "prover", `String (VCS.name_of_prover p) ;
    "hprover", `String (VCS.title_of_prover p) ;
    "time", `Float r.time ;
    "htime", `String (Pretty_utils.to_string Rformat.pp_time r.time) ;
    "success", `Int r.success ;
  ]

let to_json s : Json.t = `Assoc [
    "provers", `List (List.map to_json_p s.provers);
    "tactics", `Int s.tactics;
    "proved", `Int s.proved;
    "timeout", `Int s.timeout;
    "unknown", `Int s.unknown ;
    "noresult", `Int s.noresult ;
    "failed", `Int s.failed ;
    "cached", `Int s.cached ;
  ]

(* -------------------------------------------------------------------------- *)
