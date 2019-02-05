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

(* -------------------------------------------------------------------------- *)
(* --- Project Requests                                                   --- *)
(* -------------------------------------------------------------------------- *)

open Data
module Jutil = Yojson.Basic.Util

let project_page =
  Doc.page `Kernel ~title:"Project Management" ~filename:"project.md"

module ProjectInfo =
struct
  type t = Project.t
  let descr = Markdown.href (`Name "project-info")
  let name_of_json = function
    | `Assoc info -> Jstring.of_json (List.assoc "id" info)
    | `String id -> id
    | js -> failure "Kernel.ProjectInfo" js
  let of_json js =
    Project.from_unique_name (name_of_json js)
  let to_json p =
    `Assoc [
      "id", `String (Project.get_unique_name p) ;
      "name", `String (Project.get_name p) ;
      "current", `Bool (Project.is_current p) ;
    ]
end

module ProjectRequest =
struct
  type t = Project.t * string * json
  let descr = Markdown.(tt "{" <+> href (`Name "project-request") <+> tt "}")
  let of_json js =
    begin
      ProjectInfo.of_json (Jutil.member "project-request" js) ,
      Jutil.(member "request" js |> to_string) ,
      Jutil.(member "data" js)
    end

  let process kind (project,request,data) =
    match Main.find request with
    | Some(kd,handler) when kd = kind -> Project.on project handler data
    | Some _ -> failwith (Printf.sprintf "Incompatible kind for '%s'" request)
    | None -> failwith (Printf.sprintf "Request '%s' undefined" request)

end

module GetCurrent =
  Request.Register
    (Junit)
    (ProjectInfo)
    (struct
      let page = project_page
      let kind = `GET
      let name = "Kernel.Project.GetCurrent"
      let descr = Markdown.rm "Returns the current project"
      let details = []
      type input = unit
      type output = Project.t
      let process = Project.current
    end)

module SetCurrent =
  Request.Register
    (ProjectInfo)
    (Junit)
    (struct
      let page = project_page
      let kind = `SET
      let name = "Kernel.Project.SetCurrent"
      let descr = Markdown.rm "Switches the current project"
      let details = []
      type input = Project.t
      type output = unit
      let process p = Project.set_current p
    end)

module GetProjects =
  Request.Register
    (Junit)
    (Jlist(ProjectInfo))
    (struct
      let page = project_page
      let kind = `GET
      let name = "Kernel.Project.GetList"
      let descr = Markdown.rm "List of projects"
      let details = []
      type input = unit
      type output = Project.t list
      let process () = Project.fold_on_projects (fun ids p -> p :: ids) []
    end)

module GetOn =
  Request.Register
    (ProjectRequest)
    (Jany)
    (struct
      let page = project_page
      let kind = `GET
      let name = "Kernel.Project.GetOn"
      let descr = Markdown.rm "Execute a GET request within the given project"
      let details = []
      type input = Project.t * string * json
      type output = json
      let process = ProjectRequest.process `GET
    end)

module SetOn =
  Request.Register
    (ProjectRequest)
    (Jany)
    (struct
      let page = project_page
      let kind = `SET
      let name = "Kernel.Project.SetOn"
      let descr = Markdown.rm "Execute a SET request within the given project"
      let details = []
      type input = Project.t * string * json
      type output = json
      let process = ProjectRequest.process `SET
    end)

module ExecOn =
  Request.Register
    (ProjectRequest)
    (Jany)
    (struct
      let page = project_page
      let kind = `EXEC
      let name = "Kernel.Project.ExecOn"
      let descr = Markdown.rm "Execute an EXEC request within the given project"
      let details = []
      type input = Project.t * string * json
      type output = json
      let process = ProjectRequest.process `EXEC
    end)

(* -------------------------------------------------------------------------- *)
