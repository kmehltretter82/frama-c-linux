(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

module C_compiler = struct (* This could be put in Dune? *)
  type t =
    { compiler: string
    ; is_gnu: bool
    }

  let find_compiler configurator =
    let cc_env = try Sys.getenv "CC" with Not_found -> "" in
    if cc_env <> "" then cc_env
    else
      let finder compiler = C.which configurator compiler |> Option.is_some in
      try List.find finder [ "gcc"; "cc"; "cl.exe" ]
      with Not_found -> C.die "Could not find a C compiler"

  let write_file name code =
    let out = open_out name in
    Printf.fprintf out "%s" code ;
    close_out out

  let call configurator compiler options code =
    let dir = Temp.create_dir () in
    let file =
      Temp.create ~dir ~suffix:".c" (fun name -> write_file name code) in
    C.Process.run configurator ~dir compiler (options @ [ file ])


  let preprocess_flag = "-E"

  let is_gnu configurator compiler =
    let code = {|#ifndef __GNUC__
      this is not a gnuc compiler
#endif
|}
    in
    (call configurator compiler ["-c"] code).exit_code = 0

  let get configurator =
    let compiler = find_compiler configurator in
    let is_gnu = is_gnu configurator compiler in
    { compiler ; is_gnu }

  let preprocess configurator t options =
    call configurator t.compiler (preprocess_flag :: options)

  let _compile configurator t options =
    call configurator t.compiler ("-c" :: options)
end

(* Frama-C specific part *)

module Cpp = struct
  module GnuLike = struct
    let code = {|
#define foo 0
/* foo */
int main(){}
|}

    let check configurator compiler =
      let options = ["-dD" ; "-nostdinc"] in
      (C_compiler.preprocess configurator compiler options code).exit_code = 0
  end

  module KeepComments = struct
    let code =
      {|/* Check whether comments are kept in output */|}

    let check configurator compiler options =
      let result = C_compiler.preprocess configurator compiler options code in
      result.exit_code = 0 &&
      let re = Str.regexp_string "kept" in
      try ignore (Str.search_forward re result.stdout 0); true
      with Not_found -> false
  end

  module Archs = struct
    let opt_m_code value =
      Format.asprintf {|/* Check if preprocessor supports option -m%s */|} value

    let check configurator compiler arch =
      let code = opt_m_code arch in
      let options = [ Format.asprintf "-m%s" arch ] in
      if (C_compiler.preprocess configurator compiler options code).exit_code = 0
      then Some arch else None

    let supported_archs configurator compiler archs =
      let check = check configurator compiler in
      List.map (fun s -> "-m" ^ s) @@ List.filter_map check archs
  end

  type t =
    { compiler : C_compiler.t
    ; default_args : string list
    ; is_gnu_like : bool
    ; keep_comments : bool
    ; supported_archs_opts : string list
    }

  let get configurator =
    let compiler = C_compiler.get configurator in
    let default_args = [ "-C" ; "-I." ] in
    let is_gnu_like = GnuLike.check configurator compiler in
    let keep_comments = KeepComments.check configurator compiler [ "-C" ] in
    let supported_archs_opts =
      Archs.supported_archs configurator compiler [ "16" ; "32" ; "64" ] in
    { compiler; default_args; is_gnu_like; keep_comments; supported_archs_opts }

  let pp_flags fmt =
    let pp_sep fmt () = Format.fprintf fmt " " in
    Format.pp_print_list ~pp_sep Format.pp_print_string fmt

  let pp_default_cpp fmt cpp =
    Format.fprintf fmt "%s %a"
      cpp.compiler.compiler
      pp_flags (C_compiler.preprocess_flag :: cpp.default_args)

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
