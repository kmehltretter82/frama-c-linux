val dirname : string

val filepath : string -> Filepath.t

val generate_file : Cil_types.file -> unit

val run : string -> (unit -> 'a) -> 'a
