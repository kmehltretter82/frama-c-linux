(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module R = Options

(* -------------------------------------------------------------------------- *)
(* --- Region Analysis Main Entry Point                                   --- *)
(* -------------------------------------------------------------------------- *)

let main () =
  if R.Enabled.get () then
    begin
      Ast.compute () ;
      R.feedback "Analyzing regions" ;
      Globals.Functions.iter
        begin fun kf ->
          let domain = Analysis.get kf in
          Options.result "@[<v 2>Function %a:%t@]@."
            Kernel_function.pretty kf
            begin fun fmt ->
              List.iter
                begin fun r ->
                  Format.pp_print_newline fmt () ;
                  Memory.pp_region fmt r ;
                end @@
              Memory.regions domain
            end
        end
    end

let () = Boot.Main.extend main
