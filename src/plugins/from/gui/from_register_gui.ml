(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

let main (main_ui:Design.main_window_extension_points) =
  let filetree_selector ~was_activated ~activating node =
    (* [JS 2009/30/03] GUI may become too slow if froms are displayed *)
    if false && Eva.Analysis.is_computed () then begin
      if not was_activated && activating then begin
        match node with
        | Filetree.Global (Cil_types.GFun ({svar=v},_)) ->
          begin
            try
              let kf = Globals.Functions.get v in
              if From.is_computed kf then
                main_ui#pretty_information
                  "@[Functional dependencies:@\n%a@]@." From.pretty kf
            with Not_found -> ()
          end
        | _ -> ();
      end;
    end
  in
  main_ui#file_tree#add_select_function filetree_selector

let () = Design.register_extension main
