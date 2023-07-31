(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

(** {1 Definition of output modules for multi-thread analyses } *)

(** {2 Summary of the analysis in HTML format} *)
module Html : sig
  val output_threads : MtThread.analysis_state -> unit ;;
end

(** {2 Superposes the results of Value in the analysis project} *)
module Eva_results : sig
  val display: MtThread.analysis_state -> unit ;;
end
