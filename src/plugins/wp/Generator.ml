(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Wp_parameters

(* -------------------------------------------------------------------------- *)
(* --- WP Computer (main entry points)                                    --- *)
(* -------------------------------------------------------------------------- *)

class type t =
  object
    method model : WpContext.model
    method generate_ip : Property.t -> Wpo.t Bag.t
    method generate_kf : kernel_function -> Wpo.t Bag.t
    method generate_call : stmt -> Wpo.t Bag.t
    method generate_main :
      ?fct:functions ->
      ?bhv:string list ->
      ?prop:string list ->
      unit -> Wpo.t Bag.t
  end

type computer = [ `Dump | `Legacy | `Cfg ]

let make
    ?(computer = `Cfg)
    ?(setup: Factory.setup option)
    ?(driver: Factory.driver option)
    () : t =
  ignore setup ; ignore driver ;
  match (computer : computer) with
  | `Cfg -> assert false
  | `Dump -> assert false
  | `Legacy -> assert false

(* -------------------------------------------------------------------------- *)
