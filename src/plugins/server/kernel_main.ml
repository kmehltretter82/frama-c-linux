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
      ~descr:(Md.plain "Frama-C Kernel configuration")
      ~input:(module Junit) () in
  let result name descr =
    Request.result get_config ~name ~descr:(Md.plain descr) (module Jstring) in
  let set_version = result "version" "Frama-C version" in
  let set_datadir = result "datadir" "Shared directory (FRAMAC_SHARE)" in
  let set_libdir = result "libdir" "Lib directory (FRAMAC_LIB)" in
  let set_pluginpath = Request.result get_config
      ~name:"pluginpath" ~descr:(Md.plain "Plugin directories (FRAMAC_PLUGIN)")
      (module Jstring.Jlist) in
  Request.register_sig get_config
    begin fun rq () ->
      set_version rq Fc_config.version ;
      set_datadir rq Fc_config.datadir ;
      set_libdir rq Fc_config.libdir ;
      set_pluginpath rq Fc_config.plugin_dir ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Load saves                                                         --- *)
(* -------------------------------------------------------------------------- *)

let () =
  let signature =
    Request.signature ~page ~kind:`SET ~name:"kernel.load"
      ~descr:(Md.plain "Load a save file")
      ~input:(module Jstring)
      ~output:(module Jstring.Joption)
      ()
  in
  let load _rq file =
    try Project.load_all file; None
    with Project.IOError err -> Some err
  in
  Request.register_sig signature load

(* -------------------------------------------------------------------------- *)
(* --- File Positions                                                     --- *)
(* -------------------------------------------------------------------------- *)

module LogSource = Collection
    (struct
      type t = Filepath.position

      let syntax = Sy.publish ~page:Data.page ~name:"source"
          ~synopsis:(Sy.record [ "file" , Sy.string ; "line" , Sy.int ])
          ~descr:(Md.plain "Source file positions.")
          ~details:Md.([Block [Text (plain "The file path is normalized, \
                                            and the line number starts at one.")]])
          ()

      let to_json p = `Assoc [
          "file" , `String (p.Filepath.pos_path :> string) ;
          "line" , `Int p.Filepath.pos_lnum ;
        ]

      let of_json = function
        | `Assoc [ "file" , `String path ; "line" , `Int line ]
        | `Assoc [ "line" , `Int line ; "file" , `String path ]
          -> Log.source ~file:(Filepath.Normalized.of_string path) ~line
        | js -> failure_from_type_error "Invalid source format" js

    end)

(* -------------------------------------------------------------------------- *)
(* --- Log Lind                                                           --- *)
(* -------------------------------------------------------------------------- *)

module LogKind = Collection
    (struct

      let kinds = Enum.dictionary ~page
          ~name:"logkind" ~title:"Log Kind"
          ~descr:(Md.plain "Frama-C message category.")
          ()

      let t_kind value name descr =
        Enum.tag kinds ~name ~descr:(Md.plain descr) ~value ()

      let t_error = t_kind Log.Error "ERROR" "User Error"
      let t_warning = t_kind Log.Warning "WARNING" "User Warning"
      let t_feedback = t_kind Log.Feedback "FEEDBACK" "Plugin Feedback"
      let t_result = t_kind Log.Result "RESULT" "Plugin Result"
      let t_failure = t_kind Log.Failure "FAILURE" "Plugin Failure"
      let t_debug = t_kind Log.Debug "DEBUG" "Analyser Debug"

      let tag = function
        | Log.Error -> t_error
        | Log.Warning -> t_warning
        | Log.Feedback -> t_feedback
        | Log.Result -> t_result
        | Log.Failure -> t_failure
        | Log.Debug -> t_debug

      let data = Enum.publish kinds ~tag ()
      let () = Request.dictionary kinds

      include (val data : S with type t = Log.kind)
    end)

(* -------------------------------------------------------------------------- *)
(* --- Log Events                                                         --- *)
(* -------------------------------------------------------------------------- *)

module LogEvent = Collection
    (struct

      type rlog

      let jlog : rlog Record.signature = Record.signature ~page
          ~name:"log" ~descr:(Md.plain "Message event record.") ()

      let kind = Record.field jlog ~name:"kind"
          ~descr:(Md.plain "Message kind") (module LogKind)
      let plugin = Record.field jlog ~name:"plugin"
          ~descr:(Md.plain "Emitter plugin") (module Jstring)
      let message = Record.field jlog ~name:"message"
          ~descr:(Md.plain "Message text") (module Jstring)
      let category = Record.option jlog ~name:"category"
          ~descr:(Md.plain "Message category (DEBUG or WARNING)") (module Jstring)
      let source = Record.option jlog ~name:"source"
          ~descr:(Md.plain "Source file position") (module LogSource)

      module R = (val (Record.publish jlog) : Record.S with type r = rlog)

      type t = Log.event
      let syntax = R.syntax

      let to_json evt =
        R.default |>
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

    end)

(* -------------------------------------------------------------------------- *)
(* --- Log Monitoring                                                     --- *)
(* -------------------------------------------------------------------------- *)

let monitoring = ref false
let monitored = ref false
let events : Log.event Queue.t = Queue.create ()

let set_monitoring flag =
  if flag != !monitoring then
    monitoring := flag ;
  if !monitoring && not !monitored then
    begin
      monitored := true ;
      Log.add_listener (fun evt -> if !monitoring then Queue.add evt events)
    end

let monitor_server activity =
  if not (Senv.AutoLog.get ()) then set_monitoring activity

let monitor_autologs () =
  if Senv.AutoLog.get () then
    begin
      Senv.feedback "Auto-log started." ;
      set_monitoring true ;
    end

let () =
  Main.on monitor_server ;
  Cmdline.run_after_configuring_stage monitor_autologs

(* -------------------------------------------------------------------------- *)
(* --- Log Requests                                                       --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register
    ~page ~kind:`SET ~name:"kernel.setLogs"
    ~descr:(Md.plain "Turn logs monitoring on/off")
    ~input:(module Jbool) ~output:(module Junit)
    set_monitoring

let () = Request.register
    ~page ~kind:`GET ~name:"kernel.getLogs"
    ~descr:(Md.plain "Flush the last emitted logs since last call (max 100)")
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
