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

class printer () : Ptip.pseq =
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
  Ptip.pseq ~autofocus ~plang ~pcond

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

let () = Wpo.add_removed_hook
    (fun wpo ->
       let registry = PRINTER.get () in
       Hashtbl.remove registry wpo.po_gid)

let () = Wpo.add_cleared_hook
    (fun () ->
       let registry = PRINTER.get () in
       Hashtbl.clear registry)

let printer (wpo : Wpo.t) : printer =
  let registry = PRINTER.get () in
  try Hashtbl.find registry wpo.po_gid with Not_found ->
    let pp = new printer () in
    Hashtbl.add registry wpo.po_gid pp ; pp

(* -------------------------------------------------------------------------- *)
(* --- Printer Requests                                                   --- *)
(* -------------------------------------------------------------------------- *)

let signal = R.signal ~package ~name:"sequent" ~descr:(Md.plain "Updated TIP")

let flags (type a) tags : a R.input =
  (module struct
    type t = a
    let jtype = P.Junion (List.map (fun (tg,_) -> P.Jtag tg) tags)
    let of_json js = List.assoc (Json.string js) tags
  end)

let iformat : Plang.iformat R.input =
  flags [ "dec", `Dec ; "hex", `Hex ; "bin", `Bin ]

let rformat : Plang.rformat R.input =
  flags [ "ratio", `Ratio ; "float", `Float ; "double", `Double ]

let () =
  let printSequent = R.signature ~output:(module D.Jtext) () in
  let get_node = R.param printSequent ~name:"node"
      ~descr:(Md.plain "Proof Node") (module WpApi.Node) in
  let get_indent = R.param_opt printSequent ~name:"indent"
      ~descr:(Md.plain "Number of identation spaces") (module D.Jint) in
  let get_margin = R.param_opt printSequent ~name:"margin"
      ~descr:(Md.plain "Maximial text width") (module D.Jint) in
  let get_iformat = R.param_opt printSequent ~name:"iformat"
      ~descr:(Md.plain "Integer constants format") iformat in
  let get_rformat = R.param_opt printSequent ~name:"rformat"
      ~descr:(Md.plain "Real constants format") rformat in
  R.register_sig ~package
    ~kind:`EXEC
    ~name:"printSequent"
    ~descr:(Md.plain "Pretty-print the associated node  in its current state")
    ~signals:[signal] printSequent
    begin fun rq () ->
      let node = get_node rq in
      let indent = get_indent rq in
      let margin = get_margin rq in
      let tree = ProofEngine.tree node in
      let main = ProofEngine.main tree in
      let goal = ProofEngine.goal node in
      let pp = printer main in
      Option.iter pp#set_iformat (get_iformat rq) ;
      Option.iter pp#set_rformat (get_rformat rq) ;
      D.jpretty ?indent ?margin pp#pp_goal goal
    end

(* -------------------------------------------------------------------------- *)
