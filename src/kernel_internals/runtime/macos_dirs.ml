let home () =
  match Sys.getenv "HOME" with
  | "" -> raise Not_found
  | s -> Filepath.Normalized.of_string s

let env_or_default env default =
  let open Filepath.Normalized in
  match Sys.getenv_opt env with
  | Some s when s <> "" -> concat (of_string s) "frama-c"
  | _ -> concats (home ()) default

let cache () =
  env_or_default "XDG_CACHE_HOME" [ "Library" ; "Caches" ; "frama-c"]
let config () =
  env_or_default "XDG_CONFIG_HOME" [ "Application Support" ; "frama-c" ; "config" ]
let state () =
  env_or_default "XDG_STATE_HOME" [ "Application Support" ; "frama-c" ; "state" ]
