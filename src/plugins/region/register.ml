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

let annotate map kf =
  R.feedback "annotating function %a" Kernel_function.pretty kf ;
  let fd = Kernel_function.get_definition kf in
  List.iter
    (fun stmt ->
       Guards.iter_stmt map
         (fun condition ~valid ->
            Guards.annotate ~kf ~valid stmt condition
         ) stmt
    ) fd.sallstmts

let main () =
  if R.Enabled.get () || R.Rte.get () then
    begin
      Ast.compute () ;
      R.feedback "Analyzing regions" ;
      Globals.Functions.iter
        begin fun kf ->
          let map = Analysis.get kf in
          if R.Enabled.get () then
            Options.result "@[<v 2>Function %a:%t@]@."
              Kernel_function.pretty kf
              begin fun fmt ->
                List.iter
                  begin fun r ->
                    Format.pp_print_newline fmt () ;
                    Memory.pp_region fmt r ;
                  end @@
                Memory.regions map ;
              end ;
          if R.Rte.get () && Kernel_function.has_definition kf then
            annotate map kf
        end
    end

let () = Boot.Main.extend main

(* -------------------------------------------------------------------------- *)
