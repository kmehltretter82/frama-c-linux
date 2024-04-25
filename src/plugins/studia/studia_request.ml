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

open Server
open Cil_types

let package =
  Package.package ~plugin:"studia" ~name:"studia" ~title:"Studia" ()

type effects = { direct: stmt list; indirect: stmt list }

let empty = { direct = []; indirect = []; }

module Effects = struct
  open Server.Data

  type record
  let record: record Record.signature = Record.signature ()

  let direct = Record.field record ~name:"direct"
      ~descr:(Markdown.plain "List of statements with direct effect.")
      (module Data.Jlist (Kernel_ast.Marker))
  let indirect = Record.field record ~name:"indirect"
      ~descr:(Markdown.plain "List of statements with indirect effect.")
      (module Data.Jlist (Kernel_ast.Marker))

  let data = Record.publish record ~package ~name:"effects"
      ~descr:(Markdown.plain "Statements that read or write a location.")

  module R : Record.S with type r = record = (val data)
  type t = effects
  let jtype = R.jtype

  let to_json effects =
    let markers = Printer_tag.localizable_of_stmt in
    R.default |>
    R.set direct (List.map markers effects.direct) |>
    R.set indirect (List.map markers effects.indirect) |>
    R.to_json
end

let compute_writes zone =
  try
    let reads = Writes.compute zone in
    let add acc = function
      | Writes.Assign stmt | CallDirect stmt ->
        { acc with direct = stmt :: acc.direct }
      | CallIndirect stmt ->
        { acc with indirect = stmt :: acc.indirect }
      | FormalInit (_vi, callsites) ->
        let calls = List.flatten (List.map snd callsites) in
        { acc with direct = calls @ acc.direct }
      | GlobalInit (_vi, _initinfo) ->
        acc (* for now ignore global initializations *)
    in
    List.fold_left add empty reads
  with exn ->
    Options.warning "Error when computing writes (%s)"
      (Printexc.to_string exn) ;
    empty

let compute_reads zone =
  try
    let reads = Reads.compute zone in
    let add acc = function
      | Reads.Direct stmt -> { acc with direct = stmt :: acc.direct }
      | Indirect stmt -> { acc with indirect = stmt :: acc.indirect }
    in
    List.fold_left add empty reads
  with exn ->
    Options.warning "Error when computing reads (%s)"
      (Printexc.to_string exn) ;
    empty

let lval_location kinstr lval =
  Eva.Results.(before_kinstr kinstr |> eval_address lval |> as_zone)

let () = Request.register ~package
    ~kind:`GET ~name:"getReadsLval"
    ~descr:(Markdown.plain "Get the list of statements that read a lval.")
    ~input:(module Kernel_ast.Lval)
    ~output:(module Effects)
    (fun (kinstr, lval) -> compute_reads (lval_location kinstr lval))

let () = Request.register ~package
    ~kind:`GET ~name:"getWritesLval"
    ~descr:(Markdown.plain "Get the list of statements that write a lval.")
    ~input:(module Kernel_ast.Lval)
    ~output:(module Effects)
    (fun (kinstr, lval) -> compute_writes (lval_location kinstr lval))
