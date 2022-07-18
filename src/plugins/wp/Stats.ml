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
  verdict : VCS.verdict ;
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

let pqed r = ptime r.solver_time (VCS.is_valid r)
let presult r = ptime r.prover_time (VCS.is_valid r)
let psolver r = ptime r.solver_time false

(* -------------------------------------------------------------------------- *)
(* --- Global Stats                                                       --- *)
(* -------------------------------------------------------------------------- *)

let empty = {
  verdict = NoResult;
  provers = [];
  tactics = 0;
  proved = 0;
  timeout = 0;
  unknown = 0 ;
  noresult = 0 ;
  failed = 0 ;
  cached = 0 ;
}

let choose_best a b =
  if VCS.leq (snd a) (snd b) then a else b

let choose_worst a b =
  if VCS.leq (snd b) (snd a) then a else b

let consolidated_valid = function
  | [] -> NoResult, 0, []
  | u::w as results ->
    let p,r = List.fold_left choose_best u w in
    let cached =
      p = Qed ||
      if VCS.is_valid r then r.cached else
        List.for_all
          (fun (_,r) -> r.VCS.cached || not (VCS.is_verdict r))
          results in
    r.VCS.verdict,
    (if cached then 1 else 0),
    if p = Qed then [Qed,pqed r]
    else pmerge [Qed,psolver r] [p,presult r]

let valid_stats prs =
  let verdict, cached, provers = consolidated_valid prs in
  match verdict with
  | Valid ->
    { empty with verdict ; provers ; cached ; proved = 1 }
  | Timeout | Stepout ->
    { empty with verdict ; provers ; cached ; timeout = 1 }
  | Unknown ->
    { empty with verdict ; provers ; cached ; unknown = 1 }
  | NoResult | Computing _ ->
    { empty with verdict ; provers ; cached ; noresult = 1 }
  | Failed | Invalid ->
    { empty with verdict ; provers ; cached ; failed = 1 }

let results ~smoke prs =
  if not smoke then valid_stats prs
  else
    let verdict, missing =
      List.partition (fun (_,r) -> VCS.is_verdict r) prs in
    let doomed, passed =
      List.partition (fun (_,r) -> VCS.is_valid r) verdict in
    if doomed <> [] then
      valid_stats doomed
    else
      let cached = List.fold_left
          (fun c (_,r) -> if r.VCS.cached then succ c else c)
          0 passed in
      let stucked = List.map
          (fun (p,r) -> p, ptime r.prover_time true)
          passed in
      let solver = List.fold_left
          (fun t (_,r) -> t +. r.solver_time)
          0.0 passed in
      let provers = pmerge [Qed,ptime solver false] stucked in
      let verdict =
        if missing <> [] then NoResult else
          match passed with
          | [] -> NoResult
          | u::w -> (snd @@ List.fold_left choose_worst u w).verdict in
      let proved = List.length passed in
      let failed = List.length missing in
      { empty with verdict ; provers ; cached ; proved ; failed }

let add a b =
  if a == empty then b else
  if b == empty then a else
    {
      verdict = VCS.combine a.verdict b.verdict ;
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
  let valid = List.for_all (fun c -> c.verdict = Valid) children in
  let qed_only = children = [] in
  let verdict = if valid then Valid else Unknown in
  let provers = [Qed,ptime qed qed_only] in
  List.fold_left add { empty with verdict ; provers ; tactics = 1 } children

let script stats =
  let cached = stats.cached = stats.proved in
  let solver = List.fold_left
      (fun t (p,s) -> if p = Qed then t +. s.time else t) 0.0 stats.provers in
  let time = List.fold_left
      (fun t (p,s) -> if p <> Qed then t +. s.time else t) 0.0 stats.provers in
  VCS.result ~cached ~solver ~time stats.verdict

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
  if s.tactics > 1 then
    Format.fprintf fmt " (Tactics %d)" s.tactics
  else if s.tactics = 1 then
    Format.fprintf fmt " (Tactic)" ;
  let print_cache =
    0 < s.cached && List.exists (fun (p,_) -> p <> Qed) s.provers in
  let print_perfo =
    not shell || (print_cache && not updating && s.cached < np) in
  let qed_only =
    match s.provers with [Qed,_] -> vp = np | _ -> false in
  List.iter
    (fun (p,pr) ->
       let success = truncate pr.success in
       let print_perfo = print_perfo && pr.time > Rformat.epsilon in
       let print_proofs = success > 0 && np > 1 in
       let print_qed = qed_only && s.verdict = Valid && vp = np in
       if p != Qed || print_qed || print_perfo || print_proofs then
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
  if print_cache then
    if s.cached = np || updating then
      Format.fprintf fmt " (Cached)"
    else
    if shell then
      Format.fprintf fmt " (Cache miss %d)" (np - s.cached)
    else
      Format.fprintf fmt " (Cached %d/%d)" s.cached np

let pretty = pp_stats ~shell:false ~updating:false

(* -------------------------------------------------------------------------- *)
