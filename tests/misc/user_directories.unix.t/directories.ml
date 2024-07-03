let () = Plugin.is_session_visible ()
module Self =
  Plugin.Register
    (struct
      let name = "directories"
      let shortname = "dirs"
      let help = ""
    end)

module OnlyCache = Self.False(struct
    let option_name = "-dirs-cache-only"
    let help = ""
  end)

module Cache = Self.Cache_dir ()
module Config = Self.Config_dir ()
module State = Self.State_dir ()
module Session = Self.Session

let run_all () =
  if OnlyCache.get ()
  then
    ignore @@ Cache.get_dir ~mode:`Create_path "created"
  else
    try
      ignore @@ Cache.get_dir ~mode:`Create_path "created" ;
      ignore @@ Config.get_dir ~mode:`Create_path "created" ;
      ignore @@ State.get_dir ~mode:`Create_path "created" ;
      ignore @@ Session.get_dir ~mode:`Create_path "created" ;
      ignore @@ Session.get_file ~mode:`Create_path "created_filepath/file" ;


      (* Here: ~mode:`Normalize_only *)
      let cache_dir = Cache.get_dir "not_created" in
      let config_dir = Config.get_dir "not_created" in
      let state_dir = State.get_dir "not_created" in
      let session_dir = Session.get_dir "not_created" in
      let session_file = Session.get_file "not_created_filepath/file" in

      Self.feedback "Not created:" ;
      Self.feedback "%a" Filepath.Normalized.pretty cache_dir ;
      Self.feedback "%a" Filepath.Normalized.pretty config_dir ;
      Self.feedback "%a" Filepath.Normalized.pretty state_dir ;
      Self.feedback "%a" Filepath.Normalized.pretty session_dir ;
      Self.feedback "%a" Filepath.Normalized.pretty session_file
    with Not_found ->
      Self.error "Failure when creating directories"

let () = Boot.Main.extend run_all
