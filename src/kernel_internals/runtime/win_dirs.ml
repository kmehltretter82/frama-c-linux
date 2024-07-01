let env_or_default env default sub =
  let open Filepath.Normalized in
  match Sys.getenv_opt env, sub with
  | Some s, _ (* ignored *) when s <> "" -> concat (of_string s) "frama-c"
  | _, Some sub -> concats (of_string default) [ "frama-c" ; sub ]
  | _, None -> concat (of_string default) "frama-c"

let cache () =
  env_or_default "XDG_CACHE_HOME" (Sys.getenv "TEMP") None
let config () =
  env_or_default "XDG_CONFIG_HOME" (Sys.getenv "LOCALAPPDATA") (Some "config")
let state () =
  env_or_default "XDG_STATE_HOME" (Sys.getenv "LOCALAPPDATA") (Some "state")
