(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
  if mode = Cleanup || Wp_parameters.is_interactive () then
    Hashtbl.replace cleanup hash ()

module CACHEDIR = WpContext.StaticGenerator(Datatype.Unit)
    (struct
      type key = unit
      type data = Filepath.t
      let name = "Wp.Cache.dir"
      let compile () =
        try
          if not (Wp_parameters.CacheEnv.get()) then
            raise Not_found ;
          let gdir = Sys.getenv "FRAMAC_WP_CACHEDIR" in
          if gdir = "" then raise Not_found ;
          Filepath.of_string gdir
        with Not_found ->
        try
          let gdir = Wp_parameters.CacheDir.get() in
          if gdir = "" then raise Not_found ;
          Filepath.of_string gdir
        with Not_found ->
          Wp_parameters.get_session_dir ~force:false "cache"
    end)

let get_dir () = Filepath.to_string_abs (CACHEDIR.get ())

let is_session_dir path =
  0 = Filepath.compare
    path (Wp_parameters.get_session_dir ~force:false "cache")

let get_usable_dir ?(make=false) () =
  let path = CACHEDIR.get () in
  let parents = is_session_dir path in
  if not (Filesystem.exists path) && make then
    ignore (Filesystem.make_dir ~parents path 0o755);
  if not (Filesystem.dir_exists path) then begin
    Wp_parameters.warning ~current:false ~once:true
      "Cache path %a is not a directory"
      Filepath.pretty path;
    raise Not_found
  end;
  path

let has_dir () =
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
          if Wp_parameters.has_session () || has_dir ()
          then Update else NoCache
    end)

let get_mode = MODE.get
let set_mode m = MODE.set () m

let is_active = function
  | NoCache -> false
  | Replay | Offline | Update | Rebuild | Cleanup -> true

let is_updating = function
  | NoCache | Replay | Offline -> false
  | Update | Rebuild | Cleanup -> true

let time_fits time = function
  | None | Some 0.0 -> true
  | Some limit -> time <= limit

let steps_fits steps = function
  | None | Some 0 -> true
  | Some limit -> steps <= limit

let time_seized time = function
  | None | Some 0.0 -> false
  | Some limit -> limit <= time

let steps_seized steps steplimit =
  steps <> 0 &&
  match steplimit with
  | None | Some 0 -> false
  | Some limit -> limit <= steps

let promote ?timeout ?steplimit (res : VCS.result) =
  match res.verdict with
  | VCS.NoResult | VCS.Computing _ | VCS.Invalid | VCS.Failed -> VCS.no_result
  | VCS.Valid | VCS.Unknown ->
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

let file_from_hash file_hash =
  let dir = get_usable_dir ~make:true () in
  Filepath.(dir / (file_hash ^ ".json"))

let get_cache_result ~mode hash =
  match mode with
  | NoCache | Rebuild -> VCS.no_result
  | Update | Cleanup | Replay | Offline ->
    try
      let hash = Lazy.force hash in
      let file = file_from_hash hash in

      if not (Filesystem.exists file) then VCS.no_result
      else
        try
          mark_cache ~mode hash ;
          Json.load_file file |> ProofScript.result_of_json
        with err ->
          Wp_parameters.warning ~current:false ~once:true
            "invalid cache entry (%s)" (Printexc.to_string err) ;
          VCS.no_result
    with Not_found -> VCS.no_result

let set_cache_result ~mode hash prover result =
  match mode with
  | NoCache | Replay | Offline -> ()
  | Rebuild | Update | Cleanup ->
    let hash = Lazy.force hash in
    try
      let file = file_from_hash hash in
      mark_cache ~mode hash ;
      ProofScript.json_of_result (VCS.Why3 prover) result
      |> Json.save_file file
    with err ->
      Wp_parameters.warning ~current:false ~once:true
        "can not update cache (%s)" (Printexc.to_string err)

let clear_result ~digest prover goal =
  try
    let hash = digest prover goal in
    let file = file_from_hash hash in
    Filesystem.remove_file file
  with err ->
    Wp_parameters.warning ~current:false ~once:true
      "can not clean cache entry (%s)" (Printexc.to_string err)

let cleanup_cache () =
  let mode = get_mode () in
  if mode = Cleanup && (!hits > 0 || !miss > 0) then
    try
      let dir = get_usable_dir () in
      if is_global_cache () then
        Wp_parameters.warning ~current:false ~once:true
          "Cleanup mode deactivated with global cache."
      else
        Filesystem.iter_dir
          (fun f ->
             if Filename.check_suffix f ".json" then
               let hash = Filename.chop_suffix f ".json" in
               if not (Hashtbl.mem cleanup hash) then
                 begin
                   incr removed ;
                   Filesystem.remove_file Filepath.(dir / f) ;
                 end
          ) dir ;
    with
    | Unix.Unix_error _ as exn ->
      Wp_parameters.warning ~current:false
        "Can not cleanup cache (%s)" (Printexc.to_string exn)
    | Not_found ->
      Wp_parameters.warning ~current:false
        "Cannot cleanup cache"

type 'a digest =
  Why3Provers.t -> 'a -> string

type 'a runner =
  timeout:float option -> steplimit:int option -> Why3Provers.t -> 'a ->
  VCS.result Task.task

let get_result ~digest ~runner ~timeout ~steplimit prover goal =
  let mode = get_mode () in
  match mode with
  | NoCache -> runner ~timeout ~steplimit prover goal
  | Offline ->
    let hash = lazy (digest prover goal) in
    let result = get_cache_result ~mode hash |> VCS.cached in
    if VCS.is_verdict result then incr hits else incr miss ;
    Task.return result
  | Update | Replay | Rebuild | Cleanup ->
    let hash = lazy (digest prover goal) in
    let result =
      get_cache_result ~mode hash
      |> promote ?timeout ?steplimit |> VCS.cached in
    if VCS.is_verdict result
    then
      begin
        incr hits ;
        Task.return result
      end
    else
      Task.finally
        (runner ~timeout ~steplimit prover goal)
        begin function
          | Task.Result result when VCS.is_verdict result ->
            incr miss ;
            set_cache_result ~mode hash prover result
          | _ -> ()
        end

(* -------------------------------------------------------------------------- *)
