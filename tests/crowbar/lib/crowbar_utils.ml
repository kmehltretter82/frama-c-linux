let () = Kernel.AutoLoadPlugins.off ()
let () = Dynamic.load_module "frama-c-eva"

let dirname = Filename.dirname Sys.executable_name

let filepath name =
  Filepath.of_string (dirname ^ "/" ^ name)

let generate_file file =
  let open Filesystem.Operators in
  let filepath = file.Cil_types.fileName in
  Kernel.add_debug_keys Kernel.dkey_print_attrs;
  let result =
    let+ channel = Filesystem.with_open_out filepath in
    let fmt = Format.formatter_of_out_channel channel in
    Format.fprintf fmt "%a@." Printer.pp_file file
  in
  match result with
  | Ok () -> ()
  | Error (msg, file) ->
    Format.printf "error writing to file %a: %s"
      Filepath.pretty file
      msg

let run s f =
  Format.printf "Running Crowbar tests on %s@." s;
  f ()
