let () = Kernel.AutoLoadPlugins.off ()
let () = Dynamic.load_module "frama-c-eva"

let run s f =
  Format.printf "Running Crowbar tests on %s@." s;
  f ()
