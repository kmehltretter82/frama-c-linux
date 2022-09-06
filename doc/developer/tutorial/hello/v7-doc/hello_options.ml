(** This module contains the possible command line options
    for the Hello plug-in.
    @author Anne Onymous
    @see <http://frama-c.com/download/frama-c-plugin-development-guide.pdf>
        Frama-C Developer Manual, Tutorial
*)

(** Content of the welcome message. *)
let help_msg = "output a warm welcome message to the user"

(** Registration of the plug-in to Frama-C. *)
module Self = Plugin.Register
    (struct
      let name = "hello world"
      let shortname = "hello"
      let help = help_msg
    end)

(** Enabling of the plug-in. *)
module Enabled = Self.False
    (struct
      let option_name = "-hello"
      let help = "when on (off by default), " ^ help_msg
    end)

(** Output of the plug-in. *)
module Output_file = Self.String
    (struct
      let option_name = "-hello-output"
      let default = "-"
      let arg_name = "output-file"
      let help =
        "file where the message is output (default: output to the console)"
    end)
