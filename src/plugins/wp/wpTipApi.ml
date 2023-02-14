(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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
(* --- Server API for WP                                                  --- *)
(* -------------------------------------------------------------------------- *)

module P = Server.Package
module D = Server.Data
module R = Server.Request
module S = Server.States
module Md = Markdown
module AST = Server.Kernel_ast

let () = ignore WpApi.package
let package = P.package ~plugin:"wp" ~name:"tip"
    ~title:"WP Interactive Prover" ()

(* -------------------------------------------------------------------------- *)
(* --- Sequent Indexers                                                   --- *)
(* -------------------------------------------------------------------------- *)

module Term = D.Tagged
    (struct
      type t = Lang.F.term
      let id t = Printf.sprintf "#e%d" (Lang.F.QED.id t)
    end)
    (struct let name = "term" end)

module Part = D.Tagged
    (struct
      type t = Ptip.part
      let id (p : t) = match p with
        | Term -> "#term"
        | Goal -> "#goal"
        | Step s -> Printf.sprintf "#s%d" s.id
    end)
    (struct let name = "part" end)

(* -------------------------------------------------------------------------- *)
(* --- Sequent Printer                                                    --- *)
(* -------------------------------------------------------------------------- *)

let wrap tag pp fmt x =
  begin
    Format.pp_open_stag fmt (Format.String_tag tag) ;
    pp fmt x ;
    Format.pp_close_stag fmt () ;
  end

class printer () =
  let terms : Ptip.term_wrapper =
    object
      method wrap pp fmt t = wrap (Term.get t) pp fmt t
    end in
  let focus : Ptip.term_wrapper =
    object
      method wrap pp fmt t = wrap "wp:focus" pp fmt t
    end in
  let target : Ptip.term_wrapper =
    object
      method wrap pp fmt t = wrap "wp:target" pp fmt t
    end in
  let parts : Ptip.part_marker =
    object
      method wrap pp fmt p = wrap (Part.get p) pp fmt p
      method mark : 'a. Ptip.part -> 'a Ptip.printer -> 'a Ptip.printer
        = fun p pp fmt x -> wrap (Part.get p) pp fmt x
    end in
  let autofocus = new Ptip.autofocus in
  let plang = new Ptip.plang ~terms ~focus ~target ~autofocus in
  let pcond = new Ptip.pcond ~parts ~target:parts ~autofocus ~plang in
  object
    initializer ignore pcond
  end

(* -------------------------------------------------------------------------- *)
(* --- Printer Registry                                                   --- *)
(* -------------------------------------------------------------------------- *)

module PRINTER = State_builder.Ref
    (Datatype.Make
       (struct
         include Datatype.Undefined
         type t = (string,printer) Hashtbl.t
         let name = "WpTipApi.PRINTER.Datatype"
         let reprs = [ Hashtbl.create 0 ]
         let mem_project = Datatype.never_any_project
       end))
    (struct
      let name = "WpApi.PRINTER"
      let dependencies = [ Ast.self ]
      let default () = Hashtbl.create 0
    end)

let printer (node : ProofEngine.node) : printer =
  let registry = PRINTER.get () in
  let wpo = ProofEngine.goal node in
  try Hashtbl.find registry wpo.po_gid with Not_found ->
    let pp = new printer () in
    Hashtbl.add registry wpo.po_gid pp ; pp

(* -------------------------------------------------------------------------- *)
(* --- Printer Hooks                                                      --- *)
(* -------------------------------------------------------------------------- *)

let () = Wpo.add_removed_hook
    (fun wpo ->
       let registry = PRINTER.get () in
       Hashtbl.remove registry wpo.po_gid)

let () = Wpo.add_cleared_hook
    (fun () ->
       let registry = PRINTER.get () in
       Hashtbl.clear registry)

let () = (*TODO*) ignore package
let () = (*TODO*) ignore printer


(* -------------------------------------------------------------------------- *)
