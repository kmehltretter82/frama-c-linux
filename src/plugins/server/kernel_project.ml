(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
module Md = Markdown

let package = Package.package ~name:"project"
    ~title:"Project Management" ~readme:"project.md" ()


module Jproject_id = Jstring

let _current_project_signal =
  let add_hook f =
    Project.register_after_set_current_hook ~user_only:false f;
    (* Since Project.set_name changes the unique_name of the project, which is
       used as internal state for the current project in Ivette, the state needs
       to be reloaded when it is renamed. *)
    Project.register_after_set_name_hook (fun (p, _) -> f p);
  in
  States.register_state ~package
    ~name:"current"
    ~descr:(Md.plain "Current Frama-C project")
    ~data:(module Jproject_id)
    ~get:(fun () -> Project.(current () |> get_unique_name))
    ~set:(fun unique_name -> Project.(from_unique_name unique_name |> set_current))
    ~add_hook
    ()

let () = Request.register
    ~package ~kind:`SET ~name:"create"
    ~descr:(Md.plain "Creates a new Frama-C project with the given name")
    ~input:(module Jstring) ~output:(module Junit)
    (fun name -> Project.create name |> Project.set_current)

let no_project_found unique_name =
  Format.asprintf "No project with unique name %s found." unique_name

let () = Request.register
    ~package ~kind:`SET ~name:"rename"
    ~descr:(Md.plain "Rename a project")
    ~input:(module Jpair (Jproject_id) (Jstring))
    ~output:(module Joption (Jstring))
    (fun (project_name, new_name) ->
       try
         let project = Project.from_unique_name project_name in
         Project.set_name project new_name;
         None
       with Project.Unknown_project ->
         let err = no_project_found project_name in
         Some err)

let () = Request.register
    ~package ~kind:`SET ~name:"remove"
    ~descr:(Md.plain "Remove a project from the session")
    ~input:(module Jproject_id) ~output:(module Joption (Jstring))
    (fun project_name ->
       try
         let project = Project.from_unique_name project_name in
         Project.remove ~project ();
         None
       with
       | Project.Unknown_project ->
         let err = no_project_found project_name in
         Some err
       | Project.Cannot_remove p ->
         let err = Format.asprintf "Cannot remove project %s." p in
         Some err)

let () = Request.register
    ~package ~kind:`SET ~name:"copy"
    ~descr:(Md.plain "Duplicate a project")
    ~input:(module Jpair (Jproject_id) (Jstring)) ~output:(module Joption (Jstring))
    (fun (project_name, new_name) ->
       try
         let project = Project.from_unique_name project_name in
         let _ =
           Project.create_by_copy
             ~last:false
             ~src:project
             new_name
         in
         None
       with Project.Unknown_project ->
         let err = no_project_found project_name in
         Some err)

let () = Request.register
    ~package ~kind:`SET ~name:"load"
    ~descr:(Md.plain "Load a saved project")
    ~input:(module Jfile) ~output:(module Joption (Jstring))
    (fun filepath ->
       try
         Project.load filepath
         |> Project.set_current;
         None
       with Project.IOError err ->
         Some err)

let () = Request.register
    ~package ~kind:`SET ~name:"save"
    ~descr:(Md.plain "Save a project on disk")
    ~input:(module Jpair (Jproject_id) (Jfile)) ~output:(module Joption (Jstring))
    (fun (project_name, filepath) ->
       try
         let project = Project.from_unique_name project_name in
         Project.save ~project filepath;
         None
       with
       | Project.Unknown_project ->
         let err = no_project_found project_name in
         Some err
       | Project.IOError err ->
         Some err)

let _project_list =
  let model = States.model () in

  States.column model ~name:"uniqueName"
    ~descr:(Md.plain "Project unique name")
    ~data:(module Jproject_id)
    ~get:Project.get_unique_name;

  States.column model ~name:"name"
    ~descr:(Md.plain "Project name")
    ~data:(module Jstring)
    ~get:Project.get_name;

  let add_update_hook f =
    Project.register_create_hook f
  in
  let add_remove_hook f =
    Project.register_before_remove_hook f
  in
  let add_reload_hook f =
    (* Since Project.set_name changes the unique_name of the project, which is
       the key of this array, the whole array needs to be reloaded when a
       project is renamed. *)
    let f _ = f () in
    Project.register_after_set_name_hook f
  in
  States.register_array ~package
    ~name:"list"
    ~descr:(Md.plain "List of Frama-C projects")
    ~key:Project.get_unique_name
    ~iter:Project.iter_on_projects
    ~add_update_hook
    ~add_remove_hook
    ~add_reload_hook
    model
