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
(* --- Prover Results                                                     --- *)
(* -------------------------------------------------------------------------- *)

let dkey_shell = Wp_parameters.register_category "shell"

type prover =
  | Why3 of Why3Provers.t (* Prover via WHY *)
  | Qed           (* Qed Solver *)
  | Tactical      (* Interactive Prover *)

type mode =
  | Batch (* Only check scripts *)
  | Update (* Check and update scripts *)
  | Edit  (* Edit then check scripts *)
  | Fix   (* Try to check script, then edit script on non-success *)
  | FixUpdate (* Update and fix *)

let parse_prover = function
  | "" | "none" -> None
  | "qed" | "Qed" -> Some Qed
  | "script" -> Some Tactical
  | "tip" -> Some Tactical
  | "why3" -> Some (Why3 { Why3.Whyconf.prover_name = "why3";
                           Why3.Whyconf.prover_version = "";
                           Why3.Whyconf.prover_altern = "generate only" })
  | name ->
    match Why3Provers.lookup name with
    | Some p -> Some (Why3 p)
    | None ->
      Wp_parameters.error ~once:true
        "Prover '%s' not found in why3.conf" name ; None

let parse_mode m =
  match String.lowercase_ascii m with
  | "fix" -> Fix
  | "edit" -> Edit
  | "batch" -> Batch
  | "update" -> Update
  | "fixup" -> FixUpdate
  | _ ->
    Wp_parameters.error ~once:true
      "Unrecognized mode %S (use 'batch' instead)" m ; Batch

let name_of_prover = function
  | Why3 s -> Why3Provers.ident_wp s
  | Qed -> "qed"
  | Tactical -> "script"

let prover_of_name ?fallback = function
  | "qed" -> Some Qed
  | "script" -> Some Tactical
  | name ->
    match Why3Provers.lookup ?fallback name with
    | None -> None
    | Some prv -> Some (Why3 prv)

let title_of_prover ?version = function
  | Why3 s ->
    let version = match version with Some v -> v | None ->
      not (Wp_parameters.has_dkey dkey_shell)
    in Why3Provers.title ~version s
  | Qed -> "Qed"
  | Tactical -> "Script"

let title_of_mode = function
  | Fix -> "Fix"
  | Edit -> "Edit"
  | Batch -> "Batch"
  | Update -> "Update"
  | FixUpdate -> "Fix Update"

let sanitize_why3 s =
  let buffer = Buffer.create 80 in
  assert (s <> "ide");
  Buffer.add_string buffer "Why3_" ;
  String.iter
    (fun c ->
       let c = if
         ('0' <= c && c <= '9') ||
         ('a' <= c && c <= 'z') ||
         ('A' <= c && c <= 'Z')
         then c else '_'
       in Buffer.add_char buffer c) s ;
  Buffer.contents buffer

let filename_for_prover = function
  | Why3 s -> sanitize_why3 (Why3Provers.ident_wp s)
  | Qed -> "Qed"
  | Tactical -> "Tactical"

let is_prover = function
  | Qed | Why3 _ -> true
  | Tactical -> false

let is_extern = function
  | Qed | Tactical -> false
  | Why3 _ -> true

let is_auto = function
  | Qed -> true
  | Tactical -> false
  | Why3 p -> Why3Provers.is_auto p

let eq_prover p q =
  match p,q with
  | Qed,Qed -> true
  | Tactical,Tactical -> true
  | Why3 p, Why3 q -> Why3Provers.compare p q = 0
  | (Why3 _ | Qed | Tactical) , _ -> false

let has_counter_examples = function
  | Qed | Tactical -> false
  | Why3 p -> Why3Provers.with_counter_examples p <> None

let cmp_prover p q =
  match p,q with
  | Qed , Qed -> 0
  | Qed , _ -> (-1)
  | _ , Qed -> (+1)
  | Why3 p , Why3 q -> Why3Provers.compare p q
  | Why3 _ , _ -> (-1)
  | _ , Why3 _ -> (+1)
  | Tactical , Tactical -> 0

let pp_prover fmt p = Format.pp_print_string fmt (title_of_prover p)
let pp_mode fmt m = Format.pp_print_string fmt (title_of_mode m)

let provers () =
  List.map (fun p -> Why3 p) @@
  List.filter Why3Provers.is_mainstream @@
  Why3Provers.provers ()

module P = struct type t = prover let compare = cmp_prover end
module Pset = Set.Make(P)
module Pmap = Map.Make(P)

(* -------------------------------------------------------------------------- *)
(* --- Config                                                             --- *)
(* -------------------------------------------------------------------------- *)

type config = {
  valid : bool ;
  timeout : float option ;
  stepout : int option ;
  memlimit : int option ;
}

let current () =
  let t = Wp_parameters.Timeout.get () in
  let s = Wp_parameters.Steps.get () in
  let m = Wp_parameters.Memlimit.get () in
  {
    valid = false ;
    timeout = if t > 0 then Some (float t) else None ;
    stepout = if s > 0 then Some s else None ;
    memlimit = if m > 0 then Some m else None ;
  }

let default =
  { valid = false ; timeout = None ; stepout = None ; memlimit = None }

let get_timeout ?kf ~smoke = function
  | { timeout = None } ->
    if smoke
    then float @@ Wp_parameters.SmokeTimeout.get ()
    else
      let t =
        match Option.map Wp_parameters.FctTimeout.find kf with
        | None | exception Not_found -> Wp_parameters.Timeout.get ()
        | Some timeout -> timeout
      in float t
  | { timeout = Some t } -> t

let get_stepout = function
  | { stepout = None } -> Wp_parameters.Steps.get ()
  | { stepout = Some t } -> t

let get_memlimit = function
  | { memlimit = None } -> Wp_parameters.Memlimit.get ()
  | { memlimit = Some t } -> t

(* -------------------------------------------------------------------------- *)
(* --- Results                                                            --- *)
(* -------------------------------------------------------------------------- *)

type verdict =
  | NoResult
  | Unknown
  | Timeout
  | Stepout
  | Computing of (unit -> unit) (* kill function *)
  | Valid
  | Invalid (* model *)
  | Failed

type model = Why3Provers.model Probe.Map.t

type result = {
  verdict : verdict ;
  cached : bool ;
  solver_time : float ;
  prover_time : float ;
  prover_steps : int ;
  prover_errpos : Lexing.position option ;
  prover_errmsg : string ;
  prover_model : model ;
}

let is_result = function
  | Valid | Invalid | Unknown | Timeout | Stepout | Failed -> true
  | NoResult | Computing _ -> false
let is_verdict r = is_result r.verdict
let is_valid = function { verdict = Valid } -> true | _ -> false
let is_trivial r = is_valid r && r.prover_time = 0.0
let is_not_valid r = is_verdict r && not (is_valid r)
let is_computing = function { verdict=Computing _ } -> true | _ -> false
let has_model r = not @@ Probe.Map.is_empty r.prover_model

let is_none = function { verdict=NoResult } -> true | _ -> false
let is_proved ~smoke = function
  | NoResult | Computing _ | Failed -> false
  | Valid -> not smoke
  | Unknown | Timeout | Stepout | Invalid -> smoke

let configure r =
  let valid = (r.verdict = Valid) in
  let timeout =
    let t = r.prover_time in
    if t > 0.0 then
      let timeout = float @@ max 0 @@ Wp_parameters.Timeout.get() in
      let margin = float @@ max 0 @@ Wp_parameters.TimeExtra.get () in
      Some(timeout +. margin)
    else
      None in
  let stepout =
    if r.prover_steps > 0 && r.prover_time <= 0.0 then
      let stepout = max 0 @@ Wp_parameters.Steps.get () in
      let margin = 1000 in
      Some(max stepout margin)
    else None in
  let memlimit =
    let m = Wp_parameters.Memlimit.get () in
    if m > 0 then Some m else None in
  {
    valid ;
    timeout ;
    stepout ;
    memlimit ;
  }

let time_fits t =
  t = 0.0 ||
  let timeout = float @@ Wp_parameters.Timeout.get () in
  timeout = 0.0 ||
  let margin = float_of_string @@ Wp_parameters.TimeMargin.get () in
  t +. margin <= timeout

let step_fits n =
  n = 0 ||
  let stepout = Wp_parameters.Steps.get () in
  stepout = 0 || n < stepout

let autofit r =
  time_fits r.prover_time &&
  step_fits r.prover_steps

let result ?(model=Probe.Map.empty) ?(cached=false) ?(solver=0.0) ?(time=0.0) ?(steps=0) verdict =
  {
    verdict ;
    cached = cached ;
    solver_time = solver ;
    prover_time = time ;
    prover_steps = steps ;
    prover_errpos = None ;
    prover_errmsg = "" ;
    prover_model = model;
  }

let no_result = result NoResult
let valid = result Valid
let unknown = result Unknown
let timeout t = result ~time:t Timeout
let stepout n = result ~steps:n Stepout
let computing kill = result (Computing kill)
let failed ?pos msg = {
  verdict = Failed ;
  cached = false ;
  solver_time = 0.0 ;
  prover_time = 0.0 ;
  prover_steps = 0 ;
  prover_errpos = pos ;
  prover_errmsg = msg ;
  prover_model = Probe.Map.empty ;
}

let cached r = if is_verdict r then { r with cached=true } else r

let kfailed ?pos msg = Pretty_utils.ksfprintf (failed ?pos) msg

let pp_perf_forced fmt r =
  begin
    let t = r.solver_time in
    if t > Rformat.epsilon
    then Format.fprintf fmt " (Qed:%a)" Rformat.pp_time t ;
    let t = r.prover_time in
    if t > Rformat.epsilon
    then Format.fprintf fmt " (%a)" Rformat.pp_time t ;
    let s = r.prover_steps in
    if s > 0
    then Format.fprintf fmt " (%d)" s ;
    if r.cached
    then Format.fprintf fmt " (cached)" ;
  end

let pp_perf_shell fmt r =
  if not (Wp_parameters.has_dkey dkey_shell) then
    pp_perf_forced fmt r

let name_of_verdict ?(computing=false) = function
  | NoResult -> "none"
  | Computing _ -> if computing then "computing" else "none"
  | Valid -> "valid"
  | Invalid -> "invalid"
  | Failed -> "failed"
  | Unknown -> "unknown"
  | Stepout -> "stepout"
  | Timeout -> "timeout"

let pp_hasmodel fmt (r : result) =
  if not @@ Probe.Map.is_empty r.prover_model then
    Format.fprintf fmt " (Model)"

let pp_result fmt r =
  match r.verdict with
  | NoResult -> Format.pp_print_string fmt "No Result"
  | Computing _ -> Format.pp_print_string fmt "Computing"
  | Failed -> Format.fprintf fmt "Failed@ %s" r.prover_errmsg
  | Valid -> Format.fprintf fmt "Valid%a" pp_perf_shell r
  | Invalid -> Format.fprintf fmt "Invalid%a" pp_hasmodel r
  | Unknown -> Format.fprintf fmt "Unknown%a%a" pp_hasmodel r pp_perf_shell r
  | Stepout -> Format.fprintf fmt "Step limit%a" pp_perf_shell r
  | Timeout -> Format.fprintf fmt "Timeout%a" pp_perf_shell r

let is_qualified prover result =
  match prover with
  | Qed | Tactical -> true
  | Why3 _ -> result.cached || result.prover_time <= Rformat.epsilon

let pp_cache_miss fmt st updating prover result =
  if not updating
  && not (is_qualified prover result)
  && Wp_parameters.has_dkey dkey_shell
  then
    Format.fprintf fmt "%s%a (missing cache)" st pp_perf_forced result
  else
  if is_valid result then
    Format.pp_print_string fmt "Valid"
  else
    Format.fprintf fmt "Unsuccess%a" pp_hasmodel result

let pp_result_qualif ?(updating=true) prover result fmt =
  if Wp_parameters.has_dkey dkey_shell then
    match result.verdict with
    | NoResult -> Format.pp_print_string fmt "No Result"
    | Computing _ -> Format.pp_print_string fmt "Computing"
    | Failed -> Format.fprintf fmt "Failed@ %s" result.prover_errmsg
    | Valid -> pp_cache_miss fmt "Valid" updating prover result
    | Invalid -> pp_cache_miss fmt "Invalid" updating prover result
    | Unknown -> pp_cache_miss fmt "Unsuccess" updating prover result
    | Timeout -> pp_cache_miss fmt "Timeout" updating prover result
    | Stepout -> pp_cache_miss fmt "Stepout" updating prover result
  else
    pp_result fmt result

let pp_model fmt model =
  Probe.Map.iter
    (fun probe model ->
       Format.fprintf fmt "@[<hov 2>Model %a = %a@]@\n"
         Probe.pretty probe Why3Provers.pp_model model
    ) model

let vrank = function
  | NoResult -> 1
  | Failed -> 2
  | Unknown -> 3
  | Timeout -> 4
  | Stepout -> 5
  | Valid -> 6
  | Invalid -> 7
  | Computing _ -> 8

let conjunction a b =
  if a == b then a else
    match a,b with
    | Computing p , Computing q -> Computing (fun () -> p () ; q ())
    | Computing _ , _ -> a
    | _ , Computing _ -> b
    | Valid,Valid -> Valid
    | Valid,r | r,Valid -> r
    | _ -> if vrank b > vrank a then b else a

let msize m = Probe.Map.fold (fun _ _ n -> succ n) m 0

let compare p q =
  match is_valid p , is_valid q with
  | true , false -> (-1)
  | false , true -> (+1)
  | _ ->
    let s = msize q.prover_model - msize p.prover_model in
    if s <> 0 then s else
      let r = vrank q.verdict - vrank p.verdict in
      if r <> 0 then r else
        let s = Stdlib.compare p.prover_steps q.prover_steps in
        if s <> 0 then s else
          let t = Stdlib.compare p.prover_time q.prover_time in
          if t <> 0 then t else
            Stdlib.compare p.solver_time q.solver_time

let bestp pr1 pr2 = if compare (snd pr1) (snd pr2) <= 0 then pr1 else pr2
let best = List.fold_left bestp (Qed,no_result)
