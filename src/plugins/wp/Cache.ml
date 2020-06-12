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

(* -------------------------------------------------------------------------- *)
(* --- Cache Management                                                   --- *)
(* -------------------------------------------------------------------------- *)

type mode = NoCache | Update | Replay | Rebuild | Offline | Cleanup

let hits = ref 0
let miss = ref 0
let removed = ref 0
let cleanup = Hashtbl.create 0
(* used entries, never to be reset since cleanup is performed at exit *)

let get_hits () = !hits
let get_miss () = !miss
let get_removed () = !removed

let mark_cache ~mode hash =
  if mode = Cleanup || !Fc_config.is_gui then Hashtbl.replace cleanup hash ()

module CACHEDIR = WpContext.StaticGenerator(Datatype.Unit)
    (struct
      type key = unit
      type data = Filepath.Normalized.t
      let name = "Wp.Cache.dir"
      let compile () =
        try
          if not (Wp_parameters.CacheEnv.get()) then
            raise Not_found ;
          let gdir = Sys.getenv "FRAMAC_WP_CACHEDIR" in
          if gdir = "" then raise Not_found ;
          Filepath.Normalized.of_string gdir
        with Not_found ->
        try
          let gdir = Wp_parameters.CacheDir.get() in
          if gdir = "" then raise Not_found ;
          Filepath.Normalized.of_string gdir
        with Not_found ->
          Wp_parameters.get_session_dir ~force:false "cache"
    end)

let get_cache_dir () = (CACHEDIR.get () :> string)

let has_cache_dir () =
  try
    if not (Wp_parameters.CacheEnv.get()) then
      raise Not_found ;
    Sys.getenv "FRAMAC_WP_CACHEDIR" <> ""
  with Not_found -> Wp_parameters.CacheDir.get () <> ""

let is_global_cache () = Wp_parameters.CacheDir.get () <> ""

(* -------------------------------------------------------------------------- *)
(* --- Cache Management                                                   --- *)
(* -------------------------------------------------------------------------- *)

let parse_mode ~origin ~fallback = function
  | "none" -> NoCache
  | "update" -> Update
  | "replay" -> Replay
  | "rebuild" -> Rebuild
  | "offline" -> Offline
  | "cleanup" -> Cleanup
  | "" -> raise Not_found
  | m ->
      Wp_parameters.warning ~current:false
        "Unknown %s mode %S (use %s instead)" origin m fallback ;
      raise Not_found

let mode_name = function
  | NoCache -> "none"
  | Update -> "update"
  | Replay -> "replay"
  | Rebuild -> "rebuild"
  | Offline -> "offline"
  | Cleanup -> "cleanup"

module MODE = WpContext.StaticGenerator(Datatype.Unit)
    (struct
      type key = unit
      type data = mode
      let name = "Wp.Cache.mode"
      let compile () =
        try
          if not (Wp_parameters.CacheEnv.get()) then
            raise Not_found ;
          let origin = "FRAMAC_WP_CACHE" in
          parse_mode ~origin ~fallback:"-wp-cache" (Sys.getenv origin)
        with Not_found ->
        try
          let mode = Wp_parameters.Cache.get() in
          parse_mode ~origin:"-wp-cache" ~fallback:"none" mode
        with Not_found ->
          if Wp_parameters.has_session () || has_cache_dir ()
          then Update else NoCache
    end)

let get_mode = MODE.get
let set_mode m = MODE.clear () ; Wp_parameters.Cache.set (mode_name m)

let task_hash wpo drv prover task =
  lazy
    begin
      let file = Wpo.DISK.file_goal
          ~pid:wpo.Wpo.po_pid
          ~model:wpo.Wpo.po_model
          ~prover:(VCS.Why3 prover) in
      let _ = Command.print_file file
          begin fun fmt ->
            Format.fprintf fmt "(* WP Task for Prover %s *)@\n"
              (Why3Provers.print_why3 prover) ;
            Why3.Driver.print_task_prepared drv fmt task ;
          end
      in Digest.file file |> Digest.to_hex
    end

let time_fits time = function
  | None | Some 0 -> true
  | Some limit -> time <= float limit

let steps_fits steps = function
  | None | Some 0 -> true
  | Some limit -> steps <= limit

let time_seized time = function
  | None | Some 0 -> false
  | Some limit -> float limit <= time

let steps_seized steps steplimit =
  steps <> 0 &&
  match steplimit with
  | None | Some 0 -> false
  | Some limit -> limit <= steps

let promote ~timeout ~steplimit (res : VCS.result) =
  match res.verdict with
  | VCS.NoResult | VCS.Computing _ -> VCS.no_result
  | VCS.Failed -> res
  | VCS.Invalid | VCS.Valid | VCS.Unknown ->
      if not (steps_fits res.prover_steps steplimit) then
        { res with verdict = Stepout }
      else
      if not (time_fits res.prover_time timeout) then
        { res with verdict = Timeout }
      else res
  | VCS.Timeout | VCS.Stepout ->
      if steps_seized res.prover_steps steplimit then
        { res with verdict = Stepout }
      else
      if time_seized res.prover_time timeout then
        { res with verdict = Timeout }
      else (* can be run a longer time or widely *)
        VCS.no_result

let get_cache_result ~mode hash =
  match mode with
  | NoCache | Rebuild -> VCS.no_result
  | Update | Cleanup | Replay | Offline ->
      let dir = get_cache_dir () in
      if not (Sys.file_exists dir && Sys.is_directory dir) then
        VCS.no_result
      else
        let hash = Lazy.force hash in
        let file = Printf.sprintf "%s/%s.json" dir hash in
        if not (Sys.file_exists file) then VCS.no_result
        else
          try
            mark_cache ~mode hash ;
            Json.load_file file |> ProofScript.result_of_json
          with err ->
            Wp_parameters.warning ~current:false ~once:true
              "invalid cache entry (%s)" (Printexc.to_string err) ;
            VCS.no_result

let set_cache_result ~mode hash prover result =
  match mode with
  | NoCache | Replay | Offline -> ()
  | Rebuild | Update | Cleanup ->
      let dir = CACHEDIR.get () in
      let hash = Lazy.force hash in
      let file = Printf.sprintf "%s/%s.json" (dir :> string) hash in
      try
        mark_cache ~mode hash ;
        ProofScript.json_of_result (VCS.Why3 prover) result
        |> Json.save_file file
      with err ->
        Wp_parameters.warning ~current:false ~once:true
          "can not update cache (%s)" (Printexc.to_string err)

let cleanup_cache () =
  let mode = get_mode () in
  if mode = Cleanup && (!hits > 0 || !miss > 0) then
    let dir = get_cache_dir () in
    if is_global_cache () then
      Wp_parameters.warning ~current:false ~once:true
        "Cleanup mode deactivated with global cache."
    else
      try
        if Sys.file_exists dir && Sys.is_directory dir then
          Array.iter
            (fun f ->
               if Filename.check_suffix f ".json" then
                 let hash = Filename.chop_suffix f ".json" in
                 if not (Hashtbl.mem cleanup hash) then
                   begin
                     incr removed ;
                     Extlib.safe_remove (Printf.sprintf "%s/%s" dir f) ;
                   end
            ) (Sys.readdir dir) ;
      with Unix.Unix_error _ as exn ->
        Wp_parameters.warning ~current:false
          "Can not cleanup cache (%s)" (Printexc.to_string exn)

type runner =
  timeout:int option -> steplimit:int option ->
  Why3.Driver.driver -> Why3Provers.t -> Why3.Task.task ->
  VCS.result Task.task

let get_result wpo runner ~timeout ~steplimit drv prover task =
  let mode = get_mode () in
  match mode with
  | NoCache ->
      runner ~timeout ~steplimit drv prover task
  | Offline ->
      let hash = task_hash wpo drv prover task in
      let result = get_cache_result ~mode hash |> VCS.cached in
      if VCS.is_verdict result then incr hits else incr miss ;
      Task.return result
  | Update | Replay | Rebuild | Cleanup ->
      let hash = task_hash wpo drv prover task in
      let result =
        get_cache_result ~mode hash
        |> promote ~timeout ~steplimit |> VCS.cached in
      if VCS.is_verdict result
      then
        begin
          incr hits ;
          Task.return result
        end
      else
        Task.finally
          (runner ~timeout ~steplimit drv prover task)
          begin function
            | Task.Result result when VCS.is_verdict result ->
                incr miss ;
                set_cache_result ~mode hash prover result
            | _ -> ()
          end
