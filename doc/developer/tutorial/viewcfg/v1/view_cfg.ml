(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

(*
   This file is used by the ViewCfg tutorial.
   NOTE: any modifications changing line numbers will impact the
   generated PDF for the development guide!
*)

open Cil_types

let print_stmt out = function
  | Instr i -> Printer.pp_instr out i
  | Return _ -> Format.pp_print_string out "<return>"
  | Goto _ -> Format.pp_print_string out "<goto>"
  | Break _ -> Format.pp_print_string out "<break>"
  | Continue _ -> Format.pp_print_string out "<continue>"
  | If (e,_,_,_) -> Format.fprintf out "if %a" Printer.pp_exp e
  | Switch(e,_,_,_) -> Format.fprintf out "switch %a" Printer.pp_exp e
  | Loop _ -> Format.fprintf out "<loop>"
  | Block _ -> Format.fprintf out "<block>"
  | UnspecifiedSequence _ -> Format.fprintf out "<unspecified sequence>"
  | TryFinally _ | TryExcept _ | TryCatch _ -> Format.fprintf out "<try>"
  | Throw _ -> Format.fprintf out "<throw>"

class print_cfg out = object
  inherit Visitor.frama_c_inplace

  method! vfile _ =
    Format.fprintf out "digraph cfg {\n";
    Cil.DoChildrenPost (fun f -> Format.fprintf out "}\n%!"; f)

  method! vglob_aux g =
    match g with
    | GFun(f,_) ->
      Format.fprintf out "  subgraph cluster_%a {\n" Printer.pp_varinfo f.svar;
      Format.fprintf out "    graph [label=\"%a\"];\n" Printer.pp_varinfo f.svar;
      Cil.DoChildrenPost (fun g -> Format.fprintf out "  }\n"; g)
    | _ -> Cil.SkipChildren

  method! vstmt_aux s =
    Format.fprintf out "    s%d [label=%S];\n"
      s.sid (Pretty_utils.to_string print_stmt s.skind);
    List.iter (fun succ -> Format.fprintf out "    s%d -> s%d;\n" s.sid succ.sid)
      s.succs;
    Cil.DoChildren

end

let run () =
  let chan = open_out "cfg.out" in
  let fmt = Format.formatter_of_out_channel chan in
  Visitor.visitFramacFileSameGlobals (new print_cfg fmt) (Ast.get ());
  close_out chan

let () = Db.Main.extend run
