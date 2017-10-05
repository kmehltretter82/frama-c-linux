include Plugin.S

(** Value of [-mdr-out]. *)
module Output: Parameter_sig.String

(** Value of [-mdr-gen]. *)
module Generate: Parameter_sig.Bool

(** Value of [-mdr-gen-draft]. *)
module Gen_draft: Parameter_sig.Bool

(** Value of [-mdr-remarks]. *)
module Remarks: Parameter_sig.String

(** Value of [-mdr-flamegraph]. *)
module FlameGraph: Parameter_sig.String

(** Value of [-mdr-authors]. *)
module Authors: Parameter_sig.String_list

(** Value of [-mdr-stubs]. *)
module Stubs: Parameter_sig.String_list
