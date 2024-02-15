(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Cil_types
open Locations

let warn_locals_escape is_block fundec k locals =
  let pretty_base = Base.pretty in
  let pretty_block fmt = Pretty_utils.pp_cond is_block fmt "a block of " in
  let sv = fundec.svar in
  Self.warning
    ~wkey:Self.wkey_locals_escaping
    ~current:true ~once:true
    "locals %a escaping the scope of %t%a through %a"
    Base.Hptset.pretty locals pretty_block Printer.pp_varinfo sv pretty_base k

(* Auxiliary function for [do_assign] below. When computing the
   result of [lv = exp], warn if the evaluation of [exp] results in
   an imprecision. [loc_lv] is the location pointed to by [lv].
   [exp_val] is the part of the evaluation of [exp] that is imprecise. *)
let warn_right_exp_imprecision lv loc_lv exp_val =
  match exp_val with
  | Location_Bytes.Top(topparam, origin) ->
    Origin.register_write topparam origin;
    Self.warning ~wkey:Self.wkey_garbled_mix_write ~once:true ~current:true
      "@[<v>@[Assigning imprecise value to %a%t.@]%a%t@]"
      Printer.pp_lval lv
      (fun fmt -> match lv with
         | (Mem _, _) ->
           Format.fprintf fmt "@ (pointing to %a)"
             (Locations.pretty_english ~prefix:false) loc_lv
         | (Var _, _) -> ())
      (fun fmt org ->
         if not (Origin.is_unknown origin) then
           Format.fprintf fmt
             "@ @[The imprecision@ originates@ from@ %a@]"
             Origin.pretty org)
      origin
      Eva_utils.pp_callstack
  | Location_Bytes.Map _ -> ()


(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
