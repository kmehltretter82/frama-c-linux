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

let analyze () =
  if R.Analyze.get () then
    begin
      Ast.compute () ;
      Globals.Functions.iter
        begin fun kf ->
          let map = Analysis.get kf in
          Options.result "@[<v 2>Function %a:%t@]@."
            Kernel_function.pretty kf
            begin fun fmt ->
              List.iter
                begin fun r ->
                  Format.pp_print_newline fmt () ;
                  Memory.pp_region fmt r ;
                end @@
              Memory.regions map ;
            end
        end ;
      R.Analyze.set false ;
    end

let annotate () =
  if R.Annotate.get () then
    begin
      Ast.compute () ;
      Globals.Functions.iter Guards.annotate ;
      R.Annotate.set false ;
    end

let () = Boot.Main.extend analyze
let () = Boot.Main.extend annotate

(* -------------------------------------------------------------------------- *)
