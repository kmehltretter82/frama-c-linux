(***************************************************************************)
(*                                                                         *)
(*  SPDX-License-Identifier BSD-3-Clause                                   *)
(*  Copyright (C) 2001-2003                                                *)
(*  George C. Necula    <necula@cs.berkeley.edu>                           *)
(*  Scott McPeak        <smcpeak@cs.berkeley.edu>                          *)
(*  Wes Weimer          <weimer@cs.berkeley.edu>                           *)
(*  Ben Liblit          <liblit@cs.berkeley.edu>                           *)
(*  All rights reserved.                                                   *)
(*  File modified by                                                       *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   *)
(*  INRIA (Institut National de Recherche en Informatique et Automatique)  *)
(*                                                                         *)
(***************************************************************************)


(** Reading and storing configuration files from the filesystem. Currently
    only used in Frama-C's GUI.*)


(************************************************************************ *)
(** {2 Configuration} *)
(* ************************************************************************)

(** The configuration data can be of several types **)
type configData =
    ConfInt of int
  | ConfBool of bool
  | ConfFloat of float
  | ConfString of string
  | ConfList of configData list

(** Load the configuration from a file *)
val loadConfiguration: Filepath.t -> unit

(** Save the configuration in a file. Overwrites the previous values *)
val saveConfiguration: Filepath.t -> unit

(** Clear all configuration data *)
val clearConfiguration: unit -> unit

(** Set a configuration element, with a key. Overwrites the previous values *)
val setConfiguration: string -> configData -> unit

(** Find a configuration elements, given a key. Raises Not_found if it cannot
    find it *)
val findConfiguration: string -> configData

(** Like findConfiguration but extracts the integer *)
val findConfigurationInt: string -> int

(** Looks for an integer configuration element, and if it is found, it uses
    the given function. Otherwise, does nothing *)
val useConfigurationInt: string -> (int -> unit) -> unit

val findConfigurationFloat: string -> float
val useConfigurationFloat: string -> (float -> unit) -> unit

val findConfigurationBool: string -> bool
val useConfigurationBool: string -> (bool -> unit) -> unit

val findConfigurationString: string -> string
val useConfigurationString: string -> (string -> unit) -> unit

val findConfigurationList: string -> configData list
val useConfigurationList: string -> (configData list -> unit) -> unit
