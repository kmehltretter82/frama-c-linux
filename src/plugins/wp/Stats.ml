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
  tmin : float ;
  tval : float ;
  tmax : float ;
  tnbr : float ;
  time : float ;
  success : float ;
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
  tmin = max_float ;
  tval = 0.0 ;
  tmax = 0.0 ;
  tnbr = 0.0 ;
  time = 0.0 ;
  success = 0.0 ;
}

let padd a b =
  if a == pzero then b else
  if b == pzero then a else
    {
      tmin = min a.tmin b.tmin ;
      tmax = max a.tmax b.tmax ;
      tval = a.tval +. b.tval ;
      time = a.time +. b.time ;
      tnbr = a.tnbr +. b.tnbr ;
      success = a.success +. b.success ;
    }

let pmerge = Plist.union (fun _ a b -> padd a b)

let ptime t valid =
  { tmin = t ; tval = t ; tmax = t ; time = t ; tnbr = 1.0 ;
    success = if valid then 1.0 else 0.0 }

let psmoke r =
  { pzero with
    time = r.prover_time ;
    success = if VCS.is_valid valid then 1.0 else 0.0 }

let pqed r = ptime r.solver_time (VCS.is_valid r)
let presult r = ptime r.prover_time (VCS.is_valid r)
let psolver r = ptime r.solver_time false

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

let consolidated ~smoke = function
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
    else pmerge [Qed,psolver r] [p,if smoke then psmoke r else presult r]

let smoked_result (p,r) = p, { r with verdict = VCS.smoked r.verdict }

let results ~smoke prs =
  let prs = if smoke then List.map smoked_result prs else prs in
  let verdict, cached, provers = consolidated ~smoke prs in
  verdict,
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
  let valid = children = [] in
  let provers = [Qed,ptime qed valid] in
  List.fold_left add { zero with provers ; tactics = 1 } children

(* -------------------------------------------------------------------------- *)
(* --- Utils                                                              --- *)
(* -------------------------------------------------------------------------- *)

let proofs s = s.proved + s.timeout + s.unknown + s.noresult + s.failed
let complete s = s.proved = proofs s

let pp_pstats fmt p =
  if p.tnbr > 0.0 &&
     p.tmin > Rformat.epsilon &&
     not (Wp_parameters.has_dkey VCS.dkey_shell)
  then
    let mean = p.tval /. p.tnbr in
    let epsilon = 0.05 *. mean in
    let delta = p.tmax -. p.tmin in
    if delta < epsilon then
      Format.fprintf fmt " (%a)" Rformat.pp_time mean
    else
      let middle = (p.tmin +. p.tmax) *. 0.5 in
      if abs_float (middle -. mean) < epsilon then
        Format.fprintf fmt " (%a-%a)"
          Rformat.pp_time p.tmin
          Rformat.pp_time p.tmax
      else
        Format.fprintf fmt " (%a-%a-%a)"
          Rformat.pp_time p.tmin
          Rformat.pp_time mean
          Rformat.pp_time p.tmax

let pp_stats ~shell ~updating fmt s =
  let vp = s.proved in
  let np = proofs s in
  if vp < np && np > 1 then
    Format.fprintf fmt " (Proofs %d/%d)" vp np ;
  if s.tactics > 1 then
    Format.fprintf fmt " (Tactics %d)" s.tactics
  else if np <= 1 && s.tactics = 1 then
    Format.fprintf fmt " (Tactic)" ;
  let perfo = not shell || (not updating && s.cached < vp) in
  let only_qed = match s.provers with [Qed,_] -> true | _ -> false in
  List.iter
    (fun (p,pr) ->
       let success = truncate pr.success in
       let print_perfo = perfo && pr.time > Rformat.epsilon in
       let print_proofs = success > 0 && np > 1 in
       if p != Qed || only_qed || print_perfo || print_proofs then
         begin
           let title = VCS.title_of_prover ~version:false p in
           Format.fprintf fmt " (%s" title ;
           if print_proofs then
             Format.fprintf fmt " %d/%d" success np ;
           if print_perfo then
             Format.fprintf fmt " %a" Rformat.pp_time pr.time ;
           Format.fprintf fmt ")"
         end
    ) s.provers ;
  if 0 < s.cached && List.exists (fun (p,_) -> p <> Qed) s.provers
  then
    if s.cached = vp || updating then
      Format.fprintf fmt " (Cached)"
    else
    if shell then
      Format.fprintf fmt " (Cache miss %d)" (np - s.cached)
    else
      Format.fprintf fmt " (Cached %d/%d)" s.cached np

(* -------------------------------------------------------------------------- *)
(* --- Yojson                                                             --- *)
(* -------------------------------------------------------------------------- *)

let pstats_to_json (p,r) : Json.t = `Assoc [
    "prover", `String (VCS.name_of_prover p) ;
    "hprover", `String (VCS.title_of_prover p) ;
    "time", `Float r.time ;
    "htime", `String (Pretty_utils.to_string Rformat.pp_time r.time) ;
    "success", `Int (truncate r.success) ;
  ]

let stats_to_json s : Json.t = `Assoc [
    "provers", `List (List.map pstats_to_json s.provers);
    "tactics", `Int s.tactics;
    "proved", `Int s.proved;
    "timeout", `Int s.timeout;
    "unknown", `Int s.unknown ;
    "noresult", `Int s.noresult ;
    "failed", `Int s.failed ;
    "cached", `Int s.cached ;
  ]

(* -------------------------------------------------------------------------- *)
