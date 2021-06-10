(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(* Compute Init WP *)

module Make(W : Mcfg.S) =
struct

  let compute_global_init wenv filter obj =
    Globals.Vars.fold_in_file_order
      (fun var initinfo obj ->
         if var.vstorage = Extern then obj else
           let do_init = match filter with
             | `All -> true
             | `InitConst -> WpStrategy.isGlobalInitConst var
           in if not do_init then obj
           else
             let old_loc = Cil.CurrentLoc.get () in
             Cil.CurrentLoc.set var.vdecl ;
             let obj = W.init wenv var initinfo.init obj in
             Cil.CurrentLoc.set old_loc ; obj
      ) obj

  let process_global_const wenv obj =
    Globals.Vars.fold_in_file_order
      (fun var _initinfo obj ->
         if WpStrategy.isGlobalInitConst var
         then W.const wenv var obj
         else obj
      ) obj

  (* WP of global initializations. *)
  let process_global_init wenv kf obj =
    if WpStrategy.is_main_init kf then
      begin
        let obj = W.label wenv None Clabels.init obj in
        compute_global_init wenv `All obj
      end
    else if W.has_init wenv then
      begin
        let obj =
          if WpStrategy.isInitConst ()
          then process_global_const wenv obj else obj in
        let obj = W.use_assigns wenv None WpPropId.mk_init_assigns obj in
        let obj = W.label wenv None Clabels.init obj in
        compute_global_init wenv `All obj
      end
    else
    if WpStrategy.isInitConst ()
    then compute_global_init wenv `InitConst obj
    else obj

end
