(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

module Senv = Server_parameters

(* -------------------------------------------------------------------------- *)
(* --- Frama-C Kernel Services                                            --- *)
(* -------------------------------------------------------------------------- *)

open Data

let fc_page =
  Doc.page `Kernel ~title:"Kernel Services" ~filename:"kernel.md"

(* -------------------------------------------------------------------------- *)
(* --- Config                                                             --- *)
(* -------------------------------------------------------------------------- *)

module ConfigInfo =
struct
  type t = unit
  let descr = Markdown.tt "{ … }"

  let version =
    Jstring.getter ~name:"version" ~descr:"Frama-C version"
      (fun () -> Config.version)

  let datadir =
    Jstring.getter ~name:"datadir" ~descr:"Shared directory (FRAMAC_SHARE)"
      (fun () -> Config.datadir)

  let libdir =
    Jstring.getter ~name:"libdir" ~descr:"Lib directory (FRAMAC_LIB)"
      (fun () -> Config.datadir)

  let pluginpath =
    Jstring.Jlist.getter ~name:"pluginpath"
      ~descr:"Plugin directories (FRAMAC_PLUGIN)"
      (fun () -> Config.plugin_dir)

  let record = [ version ; datadir ; libdir ; pluginpath ]

  let to_json = Data.Record.to_json record
  let details = Data.Record.descr_table record
end

module GetConfig =
  Request.Register
    (Junit)
    (ConfigInfo)
    (struct
      let page = fc_page
      let kind = `GET
      let name = "Kernel.GetConfig"
      let descr = Markdown.rm "Kernel configuration"
      let details =
        [Markdown.section ~title:"Output Configuration" ConfigInfo.details []]
      type input = unit
      type output = unit
      let process () = ()
    end)

(* -------------------------------------------------------------------------- *)
(* --- File Positions                                                     --- *)
(* -------------------------------------------------------------------------- *)

module RawSource =
struct

  type t = Filepath.position

  let descr = Markdown.href (Doc.href fc_page "source")

  let to_json p = `Assoc [
      "file" , `String (p.Filepath.pos_path :> string) ;
      "line" , `Int p.Filepath.pos_lnum ;
    ]

  let of_json = function
    | `Assoc [ "file" , `String path ; "line" , `Int line ]
    | `Assoc [ "line" , `Int line ; "file" , `String path ]
      -> Log.source ~file:(Filepath.Normalized.of_string path) ~line
    | js -> failure "invalid source format" js

  let details = Markdown.table
      [`Center "Field" ; `Center "Type" ; `Left "Description" ]
      [[ Markdown.tt "file" ; Jstring.descr ;
         Markdown.rm "File path (normalized)" ];
       [ Markdown.tt "line" ; Jint.descr ;
         Markdown.rm "Line number (counting from 1)" ]]
end

module LogSource = Collection(RawSource)

(* -------------------------------------------------------------------------- *)
(* --- Log Lind                                                           --- *)
(* -------------------------------------------------------------------------- *)

module RawKind =
struct
  type t = Log.kind
  let name = "Kind"
  let descr = Markdown.href (Doc.href fc_page "kind")
  let values = [
    Log.Error,    "ERROR",    Markdown.rm "User Error" ;
    Log.Warning,  "WARNING",  Markdown.rm "User Warning" ;
    Log.Feedback, "FEEDBACK", Markdown.rm "Analyzer Feedback" ;
    Log.Result,   "RESULT",   Markdown.rm "Analyzer Result" ;
    Log.Failure,  "FAILURE",  Markdown.rm "Analyzer Failure" ;
    Log.Debug,    "DEBUG",    Markdown.rm "Analyser Debug" ;
  ]
end

module LogKind =
struct
  include Dictionary(RawKind)
  let details = descr_table ~tag:(`Center "Kind") ()
end

(* -------------------------------------------------------------------------- *)
(* --- Log Events                                                         --- *)
(* -------------------------------------------------------------------------- *)

module RawEvent =
struct

  let kind = LogKind.field ~name:"kind" ~descr:"Message kind"
      Log.(fun evt -> evt.evt_kind)
      Log.(fun evt evt_kind -> { evt with evt_kind })

  let plugin = Jstring.field ~name:"plugin" ~descr:"Emitter plugin"
      Log.(fun evt -> evt.evt_plugin)
      Log.(fun evt evt_plugin -> { evt with evt_plugin })

  let category = Jstring.option ~name:"category"
      ~descr:"Message category (DEBUG or WARNING)"
      Log.(fun evt -> evt.evt_category)
      Log.(fun evt a -> { evt with evt_category = Some a })

  let source = LogSource.option ~name:"source" ~descr:"Source file position"
      Log.(fun evt -> evt.evt_source)
      Log.(fun evt s -> { evt with evt_source = Some s })

  let message = Jstring.field ~name:"message" ~descr:"Message text"
      Log.(fun evt -> evt.evt_message)
      Log.(fun evt evt_message -> { evt with evt_message })

  let record = [ kind ; plugin ; category ; source ; message ]

  type t = Log.event

  let default = Log.{
      evt_plugin = "" ;
      evt_kind = Feedback ;
      evt_category = None ;
      evt_source = None ;
      evt_message = "" ;
    }

  let to_json = Record.to_json record
  let of_json = Record.of_json record default

  let descr = Markdown.href (Doc.href fc_page "log")
  let details = Record.descr_table record

end

module LogEvent = Collection(RawEvent)

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

module SetLogs =
  Request.Register
    (Jbool)
    (Junit)
    (struct
      let name = "Kernel.SetLogs"
      let descr = Markdown.rm "Turn logs monitoring on/off"
      let details = []
      let page = fc_page
      let kind = `SET
      type input = bool
      type output = unit
      let process = monitor
    end)

module GetLogs =
  Request.Register
    (Junit)
    (LogEvent.Jlist)
    (struct
      let name = "Kernel.GetLogs"
      let descr = Markdown.rm "Flush emitted logs since last call (max 100)"

      let details = [
        Markdown.section ~name:"log" ~title:"Log Format" RawEvent.details [] ;
        Markdown.section ~name:"kind" ~title:"Log Kind" LogKind.details [] ;
        Markdown.section ~name:"source" ~title:"File position" RawSource.details [] ;
      ]

      let page = fc_page
      let kind = `GET
      type input = unit
      type output = Log.event list

      let process () =
        let pool = ref [] in
        let count = ref 100 in
        while not (Queue.is_empty events) && !count > 0 do
          decr count ;
          pool := Queue.pop events :: !pool
        done ;
        List.rev !pool

    end)

(* -------------------------------------------------------------------------- *)
