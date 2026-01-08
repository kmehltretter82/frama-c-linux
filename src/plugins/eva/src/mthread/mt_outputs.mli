(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** {1 Definition of output modules for multi-thread analyses } *)

(** {2 Summary of the analysis in HTML format} *)
module Html : sig
  val output_threads : Mt_thread.analysis_state -> unit ;;
end

(** {2 Superposes the results of Value in the analysis project} *)
module Eva_results : sig
  val display: Mt_thread.analysis_state -> unit ;;
end
