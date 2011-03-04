(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2010                                               *)
(*    CEA (Commissariat à l'Énergie Atomique)                             *)
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

let text =
  let buf = Buffer.create 97 in
  fun () ->
    if Buffer.length buf = 0 then begin
      let fname = Filename.concat Config.datadir "e_acsl.h" in
      try
	let cin = open_in fname in
	try
	  while true do
	    let l = input_line cin in
	    Buffer.add_string buf l;
	    Buffer.add_char buf '\n';
	  done
	with End_of_file ->
	  close_in cin
      with Sys_error s ->
	Options.abort "cannot read file `%s': %s" fname s
    end;
    Buffer.contents buf

(*
Local Variables:
compile-command: "make"
End:
*)
