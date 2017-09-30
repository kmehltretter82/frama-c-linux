module Self: Plugin.S

(** state of [-mdr-out] option *)
module Output: Parameter_sig.String

(** state of [-mdr-generate] option *)
module Generate: Parameter_sig.Bool

(** state of [-mdr-authors] option *)
module Authors: Parameter_sig.String_list

(** generates the report. *)
val main: unit -> unit
