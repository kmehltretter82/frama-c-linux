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

(* -------------------------------------------------------------------------- *)
(* --- New WP Computer (main entry points)                                --- *)
(* -------------------------------------------------------------------------- *)

let generators = WpContext.MINDEX.create 1

let generator setup driver =
  let model = Factory.instance setup driver in
  try WpContext.MINDEX.find generators model
  with Not_found ->
    let module VCG = (val CfgWP.vcgen setup driver) in
    let module WP = CfgCalculus.Make(VCG) in
    let generator : Wpo.generator =
      object
        method model = model
        method compute_ip _ = Bag.empty
        method compute_call _ = Bag.empty
        method compute_main ?fct ?bhv ?prop () =
          ignore fct ;
          ignore bhv ;
          ignore prop ;
          Bag.empty
      end in
    WpContext.MINDEX.add generators model generator ;
    generator

(* -------------------------------------------------------------------------- *)
