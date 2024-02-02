(** This module contains the main control logic of the Hello plug-in.
    @author Anne Onymous
    @see <http://frama-c.com/download/frama-c-plugin-development-guide.pdf>
        Frama-C Developer Manual, Tutorial
*)

(** Controls the output of a given message by
        {!val:Hello_print.output} depending on the state of
        {!module:Hello_options.Enabled}.
*)
let run () =
  if Hello_options.Enabled.get() then
    Hello_print.output "Hello, world!"

(** Definition of the entry point of the hello plug-in. *)
let () = Boot.Main.extend run
