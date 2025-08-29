(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Plugin.Register
    (struct
      let name = "GUI"
      let shortname = "gui"
      let help = "Graphical User Interface"
    end)

module Config_dir = Config_dir ()

let () = Parameter_customize.do_not_projectify ()
module Project_name =
  Empty_string
    (struct
      let option_name = "-gui-project"
      let arg_name = "p"
      let help = "run the GUI on project <p> after applying the \
                  command line actions (by default, it is run on the default project"
    end)

(* Used mainly for debugging purposes. No need to show it to the user *)
let () = Parameter_customize.is_invisible ()
module Undo =
  True
    (struct
      let option_name = "-gui-undo"
      let help = "possible to click on the `undo' button (set by default)"
    end)
