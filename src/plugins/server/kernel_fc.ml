(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

open Data
module Sy = Syntax
module Md = Markdown
module Senv = Server_parameters

(* -------------------------------------------------------------------------- *)
(* --- Frama-C Kernel Services                                            --- *)
(* -------------------------------------------------------------------------- *)

let page = Doc.page `Kernel ~title:"Kernel Services" ~filename:"kernel.md"

(* -------------------------------------------------------------------------- *)
(* --- Config                                                             --- *)
(* -------------------------------------------------------------------------- *)

let () =
  let get_config = Request.signature
      ~page ~kind:`GET ~name:"kernel.getConfig"
      ~descr:(Md.rm "Frama-C Kernel configuration")
      ~input:(module Junit) () in
  let result name descr =
    Request.result get_config ~name ~descr:(Md.rm descr) (module Jstring) in
  let set_version = result "version" "Frama-C version" in
  let set_datadir = result "datadir" "Shared directory (FRAMAC_SHARE)" in
  let set_libdir = result "libdir" "Lib directory (FRAMAC_LIB)" in
  let set_pluginpath = Request.result get_config
      ~name:"pluginpath" ~descr:(Md.rm "Plugin directories (FRAMAC_PLUGIN)")
      (module Jstring.Jlist) in
  Request.register_sig get_config
    begin fun rq () ->
      set_version rq Config.version ;
      set_datadir rq Config.datadir ;
      set_libdir rq Config.libdir ;
      set_pluginpath rq Config.plugin_dir ;
    end

(* -------------------------------------------------------------------------- *)
(* --- File Positions                                                     --- *)
(* -------------------------------------------------------------------------- *)

module RawSource =
struct
  type t = Filepath.position
  let syntax = Sy.publish ~page ~name:"source"
      ~synopsis:(Sy.record [ "file" , Sy.string ; "line" , Sy.int ])
      ~descr:(Md.rm "Source file positions.")
      ~details:(Md.praw "The file path is normalized, \
                         and the line number starts at one.") ()

  let to_json p = `Assoc [
      "file" , `String (p.Filepath.pos_path :> string) ;
      "line" , `Int p.Filepath.pos_lnum ;
    ]

  let of_json = function
    | `Assoc [ "file" , `String path ; "line" , `Int line ]
    | `Assoc [ "line" , `Int line ; "file" , `String path ]
      -> Log.source ~file:(Filepath.Normalized.of_string path) ~line
    | js -> failure js "Invalid source format"

end

module LogSource = Collection(RawSource)

(* -------------------------------------------------------------------------- *)
(* --- Log Lind                                                           --- *)
(* -------------------------------------------------------------------------- *)

module RawKind =
struct
  type t = Log.kind
  let page = page
  let name = "kind"
  let descr = Md.rm "Frama-C message category."
  let values = [
    Log.Error,    "ERROR",    Md.rm "User Error" ;
    Log.Warning,  "WARNING",  Md.rm "User Warning" ;
    Log.Feedback, "FEEDBACK", Md.rm "Analyzer Feedback" ;
    Log.Result,   "RESULT",   Md.rm "Analyzer Result" ;
    Log.Failure,  "FAILURE",  Md.rm "Analyzer Failure" ;
    Log.Debug,    "DEBUG",    Md.rm "Analyser Debug" ;
  ]
end

module LogKind = Dictionary(RawKind)

(* -------------------------------------------------------------------------- *)
(* --- Log Events                                                         --- *)
(* -------------------------------------------------------------------------- *)

module RawEvent =
struct

  module R = Record
      (struct
        let page = page
        let name = "log"
        let descr = Md.rm "Message event record."
      end)

  let syntax = R.syntax

  let descr = Md.rm
  let kind = R.field "kind" ~descr:(descr "Message kind") (module LogKind)
  let plugin = R.field "plugin" ~descr:(descr "Emitter plugin") (module Jstring)
  let message = R.field "message" ~descr:(descr "Message text") (module Jstring)

  let category = R.option "category"
      ~descr:(descr "Message category (DEBUG or WARNING)")
      (module Jstring)

  let source = R.option "source" ~descr:(descr "Source file position")
      (module LogSource)

  type t = Log.event

  let to_json evt =
    R.default () |>
    R.set plugin evt.Log.evt_plugin |>
    R.set kind evt.Log.evt_kind |>
    R.set category evt.Log.evt_category |>
    R.set source evt.Log.evt_source |>
    R.set message evt.Log.evt_message |>
    R.to_json

  let of_json js =
    let r = R.of_json js in
    {
      Log.evt_plugin = R.get plugin r ;
      Log.evt_kind = R.get kind r ;
      Log.evt_category = R.get category r ;
      Log.evt_source = R.get source r ;
      Log.evt_message = R.get message r ;
    }

end

module LogEvent = Collection(RawEvent)

(* -------------------------------------------------------------------------- *)
(* --- Log Monitoring                                                     --- *)
(* -------------------------------------------------------------------------- *)

let monitoring = ref false
let monitored = ref false
let events : Log.event Queue.t = Queue.create ()

let monitor flag =
  if flag != !monitoring then
    ( if flag then
        Senv.feedback "Start logs monitoring."
      else
        Senv.feedback "Stop logs monitoring." ) ;
  monitoring := flag ;
  if !monitoring && not !monitored then
    begin
      monitored := true ;
      Log.add_listener (fun evt -> if !monitoring then Queue.add evt events)
    end

let monitor_logs () = monitor (Senv.Log.get ())

let monitor_server activity =
  if activity then monitor true else monitor_logs ()

let () =
  Main.on monitor_server ;
  Cmdline.run_after_configuring_stage monitor_logs

(* -------------------------------------------------------------------------- *)
(* --- Log Requests                                                       --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register
    ~page ~kind:`SET ~name:"kernel.setLogs"
    ~descr:(Md.rm "Turn logs monitoring on/off")
    ~input:(module Jbool) ~output:(module Junit) monitor

let () = Request.register
    ~page ~kind:`GET ~name:"kernel.getLogs"
    ~descr:(Md.rm "Flush the last emitted logs since last call (max 100)")
    ~input:(module Junit) ~output:(module LogEvent.Jlist)
    begin fun () ->
      let pool = ref [] in
      let count = ref 100 in
      while not (Queue.is_empty events) && !count > 0 do
        decr count ;
        pool := Queue.pop events :: !pool
      done ;
      List.rev !pool
    end

(* -------------------------------------------------------------------------- *)
