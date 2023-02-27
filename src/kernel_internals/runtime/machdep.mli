(** Managing machine-dependent information. *)

(** generates a [__fc_machdep.h] file in a temp directory and returns the
    directory name. The generated header contains all [#define] directives
    required by [share/libc/features.h] and other system-dependent headers.
*)
val generate_machdep_header: Cil_types.mach -> Filepath.Normalized.t
