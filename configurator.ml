(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
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

module C = Configurator.V1

module Temp = struct (* Almost copied from configurator *)
  let (^/) a b = a ^ "/" ^ b

  let rec rm_rf dir =
    Array.iter (fun fn ->
        let fn = dir ^/ fn in
        if Sys.is_directory fn then rm_rf fn else Unix.unlink fn)
      (Sys.readdir dir);
    Unix.rmdir dir

  let prng = lazy (Random.State.make_self_init ())

  let gen_name ~dir ~prefix ~suffix =
    let rnd = Random.State.bits (Lazy.force prng) land 0xFFFFFF in
    dir ^/ Printf.sprintf "%s%06x%s" prefix rnd suffix

  let create_dir () =
    let dir =
      gen_name ~dir:(Filename.get_temp_dir_name ()) ~prefix:"" ~suffix:"" in
    Unix.mkdir dir 0o700 ;
    at_exit (fun () -> rm_rf dir) ;
    dir

  let create ?(dir=create_dir ()) ?(prefix="") ?(suffix="") mk =
    let rec try_name counter =
      let name = gen_name ~dir ~prefix ~suffix in
      match mk name with
      | () -> name
      | exception Unix.Unix_error _ when counter < 1000 -> try_name (counter + 1)
    in
    try_name 0
end

module C_preprocessor = struct (* This could be put in Dune? *)
  type t =
    { preprocessor: string
    ; pp_opt: string option
    }

  let stdout_contains out str =
    let re = Str.regexp_string str in
    try ignore (Str.search_forward re out 0); true
    with Not_found -> false

  let find_preprocessor configurator =
    let cc_env = try Sys.getenv "CPP" with Not_found -> "" in
    if cc_env <> "" then (cc_env, None) (* assume default CPP needs no args *)
    else
      let finder (command, _pp_opt) =
        C.which configurator command |> Option.is_some
      in
      (* Note: We could add 'cl.exe' to the list, but since it requires
         '/<opt>' and not '-<opt>' for its options, it will fail in every
         check anyway. So the user may manually specify it if they want it,
         but having it here brings no benefit.
         Note: 'cpp' is NOT the POSIX way to call the preprocessor, and it
         behaves VERY badly on macOS (as if using '-traditional', see
         https://stackoverflow.com/questions/9508159).
         Therefore, we try `gcc -E` and `cc -E`, but not 'cpp'.
      *)
      try List.find finder [("gcc", Some "-E"); ("cc", Some "-E")]
      with Not_found -> C.die "Could not find a C preprocessor"

  let write_file name code =
    let out = open_out name in
    Printf.fprintf out "%s" code ;
    close_out out

  let call configurator preprocessor options code =
    let dir = Temp.create_dir () in
    let file =
      Temp.create ~dir ~suffix:".c" (fun name -> write_file name code) in
    C.Process.run configurator ~dir preprocessor (options @ [ file ])

  let get configurator =
    let preprocessor, pp_opt = find_preprocessor configurator in
    { preprocessor ; pp_opt }

  let preprocess configurator t options code =
    call configurator t.preprocessor (Option.to_list t.pp_opt @ options) code
end

(* Frama-C specific part *)

module Cpp = struct
  module GnuLike = struct
    let code = {|
#define foo 0
/* foo */
int main(){}
|}

    let check configurator preprocessor =
      let options = ["-dD" ; "-nostdinc"] in
      (C_preprocessor.preprocess configurator preprocessor options code).exit_code = 0
  end

  module KeepComments = struct
    let code =
      {|/* Check whether comments are kept in output */|}

    let keep_comments_option = "-C"

    let check configurator preprocessor =
      let result = C_preprocessor.preprocess configurator preprocessor [keep_comments_option] code in
      result.exit_code = 0 && C_preprocessor.stdout_contains result.stdout "kept"
  end

  module Archs = struct
    let opt_m_code value =
      Format.asprintf {|/* Check if preprocessor supports option -m%s */|} value

    let check configurator preprocessor arch =
      let code = opt_m_code arch in
      let options = [ Format.asprintf "-m%s" arch ] in
      if (C_preprocessor.preprocess configurator preprocessor options code).exit_code = 0
      then Some arch else None

    let supported_archs configurator preprocessor archs =
      let check = check configurator preprocessor in
      List.map (fun s -> "-m" ^ s) @@ List.filter_map check archs
  end

  type t =
    { preprocessor : C_preprocessor.t
    ; default_args : string list
    ; is_gnu_like : bool
    ; keep_comments : bool
    ; supported_archs_opts : string list
    }

  let get configurator =
    let preprocessor = C_preprocessor.get configurator in
    let default_args = Option.to_list preprocessor.pp_opt @ [ "-C" ; "-I." ] in
    let is_gnu_like = GnuLike.check configurator preprocessor in
    let keep_comments = KeepComments.check configurator preprocessor in
    let supported_archs_opts =
      Archs.supported_archs configurator preprocessor [ "16" ; "32" ; "64" ] in
    { preprocessor; default_args; is_gnu_like; keep_comments; supported_archs_opts }

  let pp_flags fmt =
    let pp_sep fmt () = Format.fprintf fmt " " in
    Format.pp_print_list ~pp_sep Format.pp_print_string fmt

  let pp_default_cpp fmt cpp =
    Format.fprintf fmt "%s %a"
      cpp.preprocessor.preprocessor
      pp_flags cpp.default_args

  let pp_archs fmt cpp =
    let pp_arch fmt arch = Format.fprintf fmt "\"%s\"" arch in
    let pp_sep fmt () = Format.fprintf fmt "; " in
    Format.fprintf fmt
      "%a" (Format.pp_print_list ~pp_sep pp_arch) cpp.supported_archs_opts

  let pp_sed fmt cpp =
    Format.fprintf fmt
      "s|@FRAMAC_DEFAULT_CPP@|%a|\n" pp_default_cpp cpp ;
    Format.fprintf fmt
      "s|@FRAMAC_DEFAULT_CPP_ARGS@|%a|\n" pp_flags cpp.default_args ;
    Format.fprintf fmt
      "s|@FRAMAC_GNU_CPP@|%b|\n" cpp.is_gnu_like ;
    Format.fprintf fmt
      "s|@DEFAULT_CPP_KEEP_COMMENTS@|%b|\n" cpp.keep_comments ;
    Format.fprintf fmt
      "s|@DEFAULT_CPP_SUPPORTED_ARCH_OPTS@|%a|" pp_archs cpp
end

module Fc_version = struct
  type t =
    { major: string
    ; minor: string
    ; ext: string
    ; name: string
    }

  let get configurator =
    let out_VERSION =
      let out = C.Process.run configurator "cat" ["VERSION"] in
      if out.exit_code <> 0 then C.die "Can't read VERSION." ;
      out.stdout
    in
    let re_version =
      Str.regexp {|\([1-9][0-9]\)\.\([0-9]\)\(.*\)|}
    in
    let major, minor, ext =
      if Str.string_match re_version out_VERSION 0 then
        Str.matched_group 1 out_VERSION,
        Str.matched_group 2 out_VERSION,
        try Str.matched_group 3 out_VERSION with Not_found -> ""
      else
        C.die "Can't read VERSION."
    in
    let name =
      let out = C.Process.run configurator "cat" ["VERSION_CODENAME"] in
      if out.exit_code <> 0 then
        C.die "Can't read VERSION_CODENAME." ;
      String.sub out.stdout 0 (String.length out.stdout - 1)
    in
    { major; minor; ext; name }

  let pp_sed fmt version =
    Format.fprintf fmt
      "s|@VERSION@|%s.%s%s|\n" version.major version.minor version.ext ;
    Format.fprintf fmt
      "s|@VERSION_CODENAME@|%s|\n" version.name ;
    Format.fprintf fmt
      "s|@MAJOR_VERSION@|%s|\n" version.major ;
    Format.fprintf fmt
      "s|@MINOR_VERSION@|%s|" version.minor
end

let python_available configurator =
  let result = C.Process.run configurator "python3" ["--version"] in
  if result.exit_code <> 0 then false
  else
    let out = result.stdout in
    let re_version =
      Str.regexp {|.* \([0-9]\)\.\([0-9]+\).[0-9]+|}
    in
    try
      let maj, med =
        if Str.string_match re_version out 0 then
          int_of_string @@ Str.matched_group 1 out,
          int_of_string @@ Str.matched_group 2 out
        else raise Not_found
      in
      if maj <> 3 || med < 7 then raise Not_found ;
      true
    with Not_found | Failure _ -> false

let configure configurator =
  let version = Fc_version.get configurator in
  let cpp = Cpp.get configurator in
  let config_sed = open_out "config.sed" in
  let fmt = Format.formatter_of_out_channel config_sed in
  Format.fprintf fmt "%a\n%a\n" Fc_version.pp_sed version Cpp.pp_sed cpp ;
  close_out config_sed ;
  let python = open_out "python-3.7-available" in
  Printf.fprintf python "%b" (python_available configurator) ;
  close_out python

let () =
  C.main ~name:"frama_c_config" configure
