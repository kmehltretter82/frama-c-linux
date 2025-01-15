(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
              Memory.regions domain.map
            end
        end
    end

let () = Boot.Main.extend main
