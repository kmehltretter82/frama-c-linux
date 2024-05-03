(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
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

open Pdg_types

type t = PdgTypes.Pdg.t

(**************************************************************************)

let compute = Build.compute_pdg

module Tbl =
  Kernel_function.Make_Table
    (PdgTypes.Pdg)
    (struct
      let name = "Pdg.State"
      let dependencies = [] (* postponed because From.self may not exist yet *)
      let size = 17
    end)

let self = Tbl.self
let get = Tbl.memo compute

(**************************************************************************)

let pretty ?(bw=false) fmt pdg =
  let kf = PdgTypes.Pdg.get_kf pdg in
  Format.fprintf fmt "@[RESULT for %s:@]@\n@[ %a@]"
    (Kernel_function.get_name kf) (PdgTypes.Pdg.pretty_bw ~bw) pdg

let pretty_node short =
  if short then PdgTypes.Node.pretty
  else PdgTypes.Node.pretty_node

let print_dot pdg filename =
  PdgTypes.Pdg.build_dot filename pdg;
  Pdg_parameters.feedback "dot file generated in %s" filename

let pretty_key = PdgIndex.Key.pretty

(**************************************************************************)
