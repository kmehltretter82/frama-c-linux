(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

open Server

let chapter = `Plugin "Eva"
let page = Doc.page chapter ~title:"Eva general services" ~filename:"eva.md"

module CallSite = Data.Jpair (Kernel_ast.Kf) (Kernel_ast.Stmt)

let callers kf =
  let list = !Db.Value.callers kf in
  List.concat (List.map (fun (kf, l) -> List.map (fun s -> kf, s) l) list)

let () = Request.register ~page
    ~kind:`GET ~name:"eva.callers"
    ~descr:(Markdown.plain "Get the list of call site of a function")
    ~input:(module Kernel_ast.Kf) ~output:(module Data.Jlist (CallSite))
    callers
