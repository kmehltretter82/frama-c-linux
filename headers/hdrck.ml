(* Parameters settable from command line *)
let debug_flag = ref false
and spec_file = ref None
and header_dirs = ref [ Sys.getcwd (); ]
and root_dir = ref (Sys.getcwd ())
and distrib_file = ref None
and header_except_file = ref None
and headache_config_file = ref "headers/headache_config.txt"
and exit_on_error = ref true (* only set to false for debugging purposes *)

type mode =
  | Check
  | Update

let mode = ref Check

(** Temporary directory management **)

let tmp_dirname = ref None
let remove_tmp_dirname () = match !tmp_dirname with
  | None -> ()
  | Some dirname -> if not !debug_flag then Unix.rmdir dirname

(** Utilities for message printing **)

let is_first_job_line = ref false

let job_head fmt =
  is_first_job_line:=true;
  Format.printf fmt

let job_done () =
  Format.printf "done@."

let pp_job_first_line () =
  if !is_first_job_line then
    begin
      is_first_job_line := false;
      Format.printf "@."
    end

let debug fmt =
  if !debug_flag then begin
    pp_job_first_line ();
    Format.printf "- [debug] ";
    Format.printf fmt
  end
  else Format.ifprintf Format.std_formatter  fmt

let warn fmt =
    pp_job_first_line ();
    Format.printf "- [warning] ";
    Format.printf fmt

let error_fmt fmt =
    pp_job_first_line ();
    Format.printf "- [error] ";
    Format.printf fmt

let error ~exit_value =
  pp_job_first_line ();
  let exit_fmt ~exit_value =
    Format.printf "- [fatal] ";
    Format.kfprintf
      (fun fmt ->
         Format.pp_print_flush fmt () ;
         remove_tmp_dirname () ;
         exit exit_value)
      Format.std_formatter
  in
  if !exit_on_error then exit_fmt ~exit_value else error_fmt

(* Temporary directory management (cont.) *)
let get_tmp_dirname () = match !tmp_dirname with
  | None ->
    let dirname = Filename.concat (Filename.get_temp_dir_name ()) ".hdck" in
    debug "Using temporary directory: %s@." dirname;
    if not (Sys.file_exists dirname) then Unix.mkdir dirname 0o740;
    tmp_dirname := Some dirname;
    dirname
  | Some dirname -> dirname

(* Reads [nlines] lines of a file named [filename].
 *
 * Defaults to reading the file entirely since any integer will ever be greater
 * or equal than [max_int].
 *)
let read_lines ?nlines:(nlines=max_int) filename =
  let lines = ref [] in
  let ic = open_in filename in
  let n = ref 1 in
  try
    while !n <= nlines do
      lines := input_line ic :: !lines;
      incr n
    done;
    close_in ic;
    List.rev !lines
  with
  | End_of_file ->
    close_in ic;
    List.rev !lines

(* Reads the contents of the specification into a (file -> license header name)
   hashtable.

   Each line of the file is assumed to contain one association of the form:
   <filename_id>\s+:\s+<license_id>
   where:
   - \s matches any whitespace character
   - identifiers can contain anything but whitespaces.

   Lines that do not match this pattern are ignored.
*)
let read_specs (spec_file : string) : (string, string) Hashtbl.t  =
  job_head "Checking format of specification file %s... @?" spec_file;
  let spec_lines = read_lines spec_file in
  let h = Hashtbl.create (List.length spec_lines) in
  let colon = Str.regexp ":" in
  List.iteri
    (fun i spec_line ->
       match Str.split colon spec_line with
       | filename :: [license_name] ->
         let filename = Filename.concat !root_dir (String.trim filename) in
         let license_name = String.trim license_name in
         if Hashtbl.mem h filename then
           warn "%s: specification duplicated (%d)@." filename i;
         Hashtbl.add h filename license_name
       | _ ->
         warn "%s (%d): bad line format@." spec_file i
    ) spec_lines;
  job_done ();
  h

(* Reads all directories defined in variable [header_dirs].
   @assumes each file in said directories is a valid header definition.
   @assumes filenames in directories are license names
   @return a filename -> filepath hashtable
*)
let get_header_files ?directories:(dirs=(!header_dirs)) () :
  (string, string) Hashtbl.t =
  let license_path_tbl = Hashtbl.create 7 in
  List.iter
    (fun dir ->
       job_head "Reading license header definition files from directory %s... @?" dir;
       if Sys.file_exists dir && Sys.is_directory dir then begin
         Array.iter
           (fun filename ->
              let license_name = filename in
              let filepath = Filename.concat dir filename in
              Hashtbl.add license_path_tbl license_name filepath;
           )
           (Sys.readdir dir)
       end
       else warn "Ignoring absent directory %s@." dir;
       job_done ();
    ) dirs;
  license_path_tbl

module StringSet = struct
  include Set.Make(struct type t = string let compare = String.compare end)

  let pp fmt set =
    Format.fprintf fmt "@[<v 0>";
    iter (fun name -> Format.fprintf fmt "- %s@ " name) set;
    Format.fprintf fmt "@]"
end

(* Removes from further header specifications:
   - non-existing files; a warning is emitted
   - files marked with .ignore
*)
let filter_specs ?(warnings=true) h =
  job_head "Checking presence of files having an header specification... @?" ;
  let hnew = Hashtbl.create (Hashtbl.length h) in
  Hashtbl.iter
    (fun filename hdr_type ->
       if not (Sys.file_exists filename) then begin
         if warnings then warn "%s: specified but does not exist!@." filename
       end
       else if hdr_type <> ".ignore" then
         Hashtbl.add hnew filename hdr_type
    ) h;
  job_done ();
  hnew


(* Checks that all license headers specified in a given specification have a
 * definition in a file of the file system.

   @requires ignored files have been filtered out the specifications
*)
let check_declared_headers specification headers =
  job_head "Checking license specifications are defined... @?" ;
  Hashtbl.iter
    (fun file header_type ->
       if not (Hashtbl.mem headers header_type) then begin
         error ~exit_value:3 "%s : declaration for header %s not found"
           file header_type;
       end
    ) specification;
  job_done ()

(*  extract_header function is used in debug mode when there are discrepancies *)
let extract_header filename template_hdr =
  let dirname = get_tmp_dirname () in
  let hdr_filename = Filename.concat dirname (Filename.basename filename) in
  debug "%s: %s does not conform to %s@." filename hdr_filename template_hdr;
  let create_file filename = let oc = open_out filename in close_out oc in
  create_file hdr_filename;
  let cmd = Format.sprintf "headache -c %s -e %s > %s"
      !headache_config_file filename hdr_filename in
  let ret = Sys.command cmd in
  if ret <> 0 then
    debug "%s : error during header template generations@." filename

(* Check, for each file, if its license header specification corresponds to what
 * exists at the beginning of the file. If any discrepancy between the
 * specification and what the file contains is detected, a summary of all such
 * events is printed before exiting.
 *
 * @param specs a file -> license header hashtable
 * @param headers a license header -> template header file hashtable
 * @requires all files in specs exist
 * @requires all header specifications have a corresponding existing template
 *)
let check_spec_discrepancies
    (specs: (string, string) Hashtbl.t)
    (headers: (string, string) Hashtbl.t) : unit =
  let eq_header orig_file template_hdr =
    let cmd = Format.sprintf "headache -c %s -e %s | diff -q - %s > /dev/null"
        !headache_config_file orig_file template_hdr
    in
    let ret = Sys.command cmd in
    if ret <> 0 && !debug_flag then extract_header orig_file template_hdr ;
    ret = 0
  in
  job_head "Checking specification discrepancies... @?";
  let n = ref 0 in
  let discrepancies = ref [] in
  Hashtbl.iter
    (fun file hdr_type ->
       if Sys.file_exists file then begin
         let hdr_file_spec = Hashtbl.find headers hdr_type in
         (* Guaranteed to exists after check_declared_headers *)
         if not (eq_header file hdr_file_spec) then begin
            discrepancies := (file, hdr_type) :: !discrepancies;
            incr n;
         end;
       end
      ) specs ;
  if !n > 0 then begin
    error ~exit_value:4 "@[<v 2>%a%d / %d files with bad headers@]@."
      (fun ppf l ->
         List.iter
           (fun (file, hdr_type) ->
              error_fmt "%s : header differs from spec %s@."
             file hdr_type
           ) l) !discrepancies
      !n
      (Hashtbl.length specs)
    ;
  end;
  job_done ();
  remove_tmp_dirname ()

(* This is the main check. It checks that all distributed files, minus
 * exceptions, have a header specification, then launches other verifications.
 *
 * @param header_specifications file -> license header name hashtable
 * @param distributed_files a set of files considered for distribution
 * @param exceptions a set of files distributed but that should not be checked
*)
let check header_specifications distributed_files exceptions =
  let files_to_check = StringSet.diff distributed_files exceptions in
  let files_specified =
    Hashtbl.fold
      (fun file _ set -> StringSet.add file set)
      header_specifications StringSet.empty
  in
  job_head "Checking that all distributed files do exist... @?";
  let nonexistent_files =
    StringSet.filter (fun f -> not (Sys.file_exists f)) distributed_files
  in
  if not (StringSet.is_empty nonexistent_files) then begin
    error ~exit_value:5
      "@[<v 2># Non-existing files listed as distributed:@ %a@]@."
      StringSet.pp nonexistent_files
  end;
  job_done ();
  let distributed_unspecified = StringSet.diff files_to_check files_specified in
  job_head "Checking that distributed files have a license header specification... @?";
  if not (StringSet.is_empty distributed_unspecified) then begin
    error ~exit_value:2
      "@[<v 2># Files distributed without specified header:@ %a@]@."
      StringSet.pp distributed_unspecified;
  end;
  job_done ();
  (* Other verifications start here *)
  let headers = get_header_files () in
  (* Remove .ignore files, and warn when missing files are specified *)
  let filtered_specs = filter_specs header_specifications in
  (* Check all headers used in specification have a definition, except ignored
  ones  *)
  check_declared_headers filtered_specs headers;
  (* Check differences between declared headers and those found in the file *)
  check_spec_discrepancies filtered_specs headers


(* Update headers according to header specifications
 * The headers are simply overwritten.
 * No warning is emitted if the new license is not the same as the old license.
 *
 * @param header_specifications file -> license header name hashtable
 * @requires: files and licenses appearing in [header_specifications] exists
 *)
let update_headers header_specifications =
  let headers = get_header_files () in
  let warnings = false in
  let filtered_specs = filter_specs ~warnings header_specifications in
  check_declared_headers filtered_specs headers;
  let update filename header =
    debug "Updating %s with license %s@." filename header;
    let cmd = Format.sprintf "headache -r -c %s -h %s %s"
        !headache_config_file header filename in
    let ret = Sys.command cmd in
    if ret <> 0 then
      debug "%s : error updating header" filename
  in
  job_head "Updating header files ... @?";
  Hashtbl.iter
    (fun filename header_name ->
       let header_file = Hashtbl.find headers header_name in
       update filename header_file)
    filtered_specs;
  job_done ()


let check_headache_config_file () =
  if not (Sys.file_exists !headache_config_file) then
    error ~exit_value:5
      "Headache configuration file %s does not appear to exist@."
      !headache_config_file

(** Option management (cont.) **)

let set_opt (var:'a option ref) (value:'a) = var := Some value

let get_opt = function
  | None -> assert false
  | Some v -> v

let set_header_dirs (hdrs : string) =
  let rexp = Str.regexp "," in
  let dirs = List.map String.trim (Str.split rexp hdrs) in
  header_dirs := dirs

let executable_name = Sys.argv.(0)

let umsg =
  Format.sprintf "Usage: %s [options] <header spec file>" executable_name

let rec argspec = [
  "--help", Arg.Unit print_usage ,
  " print this option list and exits";
  "-help", Arg.Unit print_usage ,
  " print this option list and exits";
  "-debug", Arg.Set debug_flag,
  " enable debug messages";
  "-header-dirs", Arg.String set_header_dirs ,
  " add comma separated list of directories to search for license header \
   definitions [.]";
  "-distrib-file", Arg.String (set_opt distrib_file),
  " set filename with a list of files set for distribution";
  "-header-except-file", Arg.String (set_opt header_except_file),
  " set filename with a list of files whose headers do not need checking";
  "-headache-config-file", Arg.Set_string headache_config_file,
  Format.sprintf " set headache configuration file [%s]" !headache_config_file;
  "-no-exit-on-error", Arg.Unit (fun () -> exit_on_error := false),
  " do not exit on errors ";
  "-update", Arg.Unit (fun () -> mode := Update),
  " update headers w.r.t to the <header spec file>";
  "-C", Arg.Set_string root_dir,
  Format.sprintf
    " Prepend <dir> to filenames in header specification [%s] "
    !root_dir;
]

and sort argspec =
  List.sort (fun (name1, _, _) (name2, _, _) -> String.compare name1 name2)
    argspec

and print_usage () =
  Arg.usage (Arg.align (sort argspec)) umsg;
  exit 0

(** MAIN **)

let _ =
  (* Test if headache is in the path *)
  if Sys.command "headache -e >/dev/null 2>/dev/null" <> 0 then
    (Format.eprintf "error: 'headache' command not in PATH or incompatible \
                     version (option -e unsupported)@."; exit 6);
  (* [CULPRIT] if multiple files are passed on the command line, only the
   * last one is considered to be THE specification file, and the others are
   * ignored.
   *)
  Arg.parse (Arg.align (sort argspec)) (fun s -> set_opt spec_file s) umsg;
  check_headache_config_file ();
  match !spec_file, !distrib_file, !header_except_file with
  | None, _, _ ->
    Format.printf "Please set a specification file@\n@.";
    print_usage ();
  | Some spec_file, distrib_file_opt, header_except_opt ->
    debug "Specification file set to: %s@."  spec_file;
    let specified_files = read_specs spec_file in
    let stringset_from_opt_file = function
      | None -> StringSet.empty
      | Some file ->
        let lines = read_lines file in
        List.fold_left
(fun s l -> StringSet.add (Filename.concat !root_dir l) s) StringSet.empty lines
    in
    match !mode with
    | Check ->
      let distributed_files = stringset_from_opt_file distrib_file_opt in
      let header_exception_files = stringset_from_opt_file header_except_opt in
      check specified_files distributed_files header_exception_files
    | Update ->
      update_headers specified_files

(* Local Variables: *)
(* compile-command: "ocamlc -o hdrck unix.cma str.cma hdrck.ml" *)
(* End: *)
