(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(** Ast Data *)
(* -------------------------------------------------------------------------- *)

open Cil_types

(** Represented by a Json record with file, dir, basename, line *)
module Position : Data.S with type t = Filepath.position

(* -------------------------------------------------------------------------- *)
(** Ast Markers *)
(* -------------------------------------------------------------------------- *)

module type Tag =
sig
  (** Exported as Json string with their unique tag. *)
  include Data.S

  val index : t -> string
  (** Memoized unique identifier. *)

  val find : string -> t
  (** Get back the scope, if any.
      @raises Not_found if the marker is not defined yet *)

end

module Decl : (Tag with type t = Printer_tag.declaration)
module Marker : (Tag with type t = Printer_tag.localizable)

(* -------------------------------------------------------------------------- *)
(** Ast Markers of Specific Kinds *)
(* -------------------------------------------------------------------------- *)

(** Markers that are l-values. *)
module Lval :
sig
  include Data.S with type t = kinstr * lval
  val mem : Marker.t -> bool
  val find : Marker.t -> t
end

(** Markers that are statements. *)
module Stmt : Data.S with type t = stmt

(** Optional markers interpreted as kinstr. *)
module Kinstr : Data.S with type t = kinstr

(* -------------------------------------------------------------------------- *)
(** Ast Printer *)
(* -------------------------------------------------------------------------- *)

module PrinterTag : Printer_tag.S_pp

(* -------------------------------------------------------------------------- *)
(** Ast Information *)
(* -------------------------------------------------------------------------- *)

module Information :
sig
  (**
     Registers a marker information printer.
     Identifier [id] shall be unique.

     - [label] shall be very short.
     - [title] shall succinctly describe the kind of information.
     - [descr] optional longer description explaining the informations
     - [enable] optional dynamical filter for enabling this information

     The printer shall raise [Not_found] exception when there is no
     information for the localizable.
  *)
  val register :
    id:string -> label:string -> title:string -> ?descr:string ->
    ?enable:(unit -> bool) ->
    (Format.formatter -> Printer_tag.localizable -> unit) -> unit

  (** Updated information signal *)
  val signal : Request.signal

  (** Emits a signal to server clients to reload AST marker information. *)
  val update : unit -> unit
end

(* -------------------------------------------------------------------------- *)
(** Globals *)
(* -------------------------------------------------------------------------- *)

module Functions :
sig
  val iter : (kernel_function -> unit) -> unit
  val key : kernel_function -> string
  val array : kernel_function States.array
end

(* -------------------------------------------------------------------------- *)
