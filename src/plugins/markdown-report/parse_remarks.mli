(** Parse skeleton files to add manually written comments to various parts
    of the report. *)

(** [get_remarks f] retrieves the elements associated to various sections
    of the report, referenced by their anchor. *)
val get_remarks: string -> Markdown.element list Datatype.String.Map.t
