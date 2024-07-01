let home () =
  match Sys.getenv "HOME" with
  | "" -> raise Not_found
  | s -> Filepath.Normalized.of_string s

let env_or_default env default =
  let open Filepath.Normalized in
  let location =
    match Sys.getenv_opt env with
    | Some env when env <> "" -> of_string env
    | _ -> concats (home ()) default
  in
  concat location "frama-c"

let cache () =
  env_or_default "XDG_CACHE_HOME" [ ".cache" ]
let config () =
  env_or_default "XDG_CONFIG_HOME" [ ".config" ]
let state () =
  env_or_default "XDG_STATE_HOME" [ ".local" ; "state" ]
