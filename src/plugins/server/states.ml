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

type 'a callback = ('a -> unit) -> unit

let install signal hook = function
  | None -> ()
  | Some add_hook ->
    let once = ref true in
    let install ok =
      if ok && !once then
        begin
          once := false ;
          add_hook hook ;
        end
    in Request.on_signal signal install

let install_emit signal add_hook =
  install signal (fun () -> Request.emit signal) add_hook

(* -------------------------------------------------------------------------- *)
(* --- Values                                                             --- *)
(* -------------------------------------------------------------------------- *)

let register_value (type a) ~page ~name ~descr ?(details=[])
    ~(output : a Request.output) ~get
    ?(add_hook : unit callback option) ()
  =
  let open Markdown in
  let title =  Printf.sprintf "`VALUE` %s" name in
  let index = [ Printf.sprintf "%s (`VALUE`)" name ] in
  let contents = [ Block [Text descr] ; Block details] in
  let h = Server_doc.publish ~page ~name ~title ~index ~contents () in
  let signal = Request.signal ~page ~name:(name ^ ".sig")
      ~descr:(plain "Signal for value " @ href h) () in
  Request.register ~page ~kind:`GET ~name:(name ^ ".get")
    ~descr:(plain "Getter for value " @ href h)
    ~input:(module Junit) ~output get ;
  install_emit signal add_hook ;
  signal

(* -------------------------------------------------------------------------- *)
(* --- States                                                             --- *)
(* -------------------------------------------------------------------------- *)

let register_state (type a) ~page ~name ~descr ?(details=[])
    ~(data : a data) ~get ~set
    ?(add_hook : unit callback option) () =
  let open Markdown in
  let title =  Printf.sprintf "`STATE` %s" name in
  let index = [ Printf.sprintf "%s (`STATE`)" name ] in
  let contents = [ Block [Text descr] ; Block details] in
  let h = Server_doc.publish ~page ~name ~title ~index ~contents () in
  let signal = Request.signal ~page ~name:(name ^ ".sig")
      ~descr:(plain "Signal for state " @ href h) () in
  Request.register ~page ~kind:`GET ~name:(name ^ ".get")
    ~descr:(plain "Getter for state " @ href h)
    ~input:(module Junit) ~output:(module (val data)) get ;
  Request.register ~page ~kind:`SET ~name:(name ^ ".set")
    ~descr:(plain "Setter for state " @ href h)
    ~input:(module (val data)) ~output:(module Junit) set ;
  install_emit signal add_hook ;
  signal

(* -------------------------------------------------------------------------- *)
(* --- Model Signature                                                    --- *)
(* -------------------------------------------------------------------------- *)

type 'a column = Syntax.field * ('a -> json)

type 'a model = 'a column list ref

let model () = ref []

let column (type a b) ~(model : a model) ~name ~descr
    ~(data: b Request.output) ~(get : a -> b) () =
  let module D = (val data) in
  if name = "key" || name = "index" then
    raise (Invalid_argument "Server.States.column: invalid name") ;
  if List.exists (fun (fd,_) -> fd.Syntax.fd_name = name) !model then
    raise (Invalid_argument "Server.States.column: duplicate name") ;
  let fd = Syntax.{
      fd_name = name ;
      fd_syntax = D.syntax ;
      fd_descr = descr ;
    } in
  model := (fd , fun a -> D.to_json (get a)) :: !model

module Kmap = Map.Make(String)

(* -------------------------------------------------------------------------- *)
(* --- Model Content                                                      --- *)
(* -------------------------------------------------------------------------- *)

type 'a update = Remove | Add of 'a
type 'a content = {
  mutable cleared : bool ;
  mutable updates : 'a update Kmap.t ;
}

type 'a array = {
  signal : Request.signal ;
  key : 'a -> string ;
  iter : ('a -> unit) -> unit ;
  getter : (string * ('a -> json)) list ;
  (* [LC+JS]
     The two following fields allow to keep an array in sync
     with the current project and still have a polymorphic data type. *)
  mutable current : 'a content option ; (* fast access to current project *)
  projects : (string , 'a content) Hashtbl.t ; (* indexed by project *)
}

let synchronize array =
  begin
    Project.register_after_set_current_hook
      ~user_only:false (fun _ -> array.current <- None) ;
    let cleanup p =
      Hashtbl.remove array.projects (Project.get_unique_name p) in
    Project.register_before_remove_hook cleanup ;
    Project.register_todo_before_clear cleanup ;
    Request.on_signal array.signal
      (fun _ ->
         array.current <- None ;
         Hashtbl.clear array.projects ;
      );
  end

let content array =
  match array.current with
  | Some w -> w
  | None ->
    let prj = Project.(current () |> get_unique_name) in
    let content =
      try Hashtbl.find array.projects prj
      with Not_found ->
        let w = {
          cleared = true ;
          updates = Kmap.empty ;
        } in
        Hashtbl.add array.projects prj w ; w
    in
    array.current <- Some content ;
    Request.emit array.signal ;
    content

let reload array =
  let m = content array in
  m.cleared <- true ;
  m.updates <- Kmap.empty ;
  Request.emit array.signal

let update array k =
  let m = content array in
  if not m.cleared then
    begin
      m.updates <- Kmap.add (array.key k) (Add k) m.updates ;
      Request.emit array.signal ;
    end

let remove array k =
  let m = content array in
  if not m.cleared then
    begin
      m.updates <- Kmap.add (array.key k) Remove m.updates ;
      Request.emit array.signal ;
    end

let signal array = array.signal

(* -------------------------------------------------------------------------- *)
(* --- Fetch Model Updates                                                --- *)
(* -------------------------------------------------------------------------- *)

type buffer = {
  reload : bool ;
  mutable capacity : int ;
  mutable pending : int ;
  mutable removed : string list ;
  mutable updated : json list ;
}

let add_entry buffer cols key v =
  let fjs = List.fold_left (fun fjs (fd,to_json) ->
      try (fd , to_json v) :: fjs
      with Not_found -> fjs
    ) [] cols in
  buffer.updated <- `Assoc( ("key", `String key):: fjs) :: buffer.updated ;
  buffer.capacity <- pred buffer.capacity

let remove_entry buffer key =
  buffer.removed <- key :: buffer.removed ;
  buffer.capacity <- pred buffer.capacity

let update_entry buffer cols key = function
  | Remove -> remove_entry buffer key
  | Add v -> add_entry buffer cols key v

let fetch array n =
  let m = content array in
  let reload = m.cleared in
  let buffer = {
    reload ;
    capacity = n ;
    pending = 0 ;
    removed = [] ;
    updated = [] ;
  } in
  begin
    if reload then
      begin
        m.cleared <- false ;
        array.iter
          begin fun v ->
            let key = array.key v in
            if buffer.capacity > 0 then
              add_entry buffer array.getter key v
            else
              ( m.updates <- Kmap.add key (Add v) m.updates ;
                buffer.pending <- succ buffer.pending ) ;
          end ;
      end
    else
      m.updates <- Kmap.filter
          begin fun key upd ->
            if buffer.capacity > 0 then
              ( update_entry buffer array.getter key upd ; false )
            else
              ( buffer.pending <- succ buffer.pending ; true )
          end m.updates ;
  end ;
  buffer

(* -------------------------------------------------------------------------- *)
(* --- Signature Registry                                                 --- *)
(* -------------------------------------------------------------------------- *)

let register_array ~page ~name ~descr ?(details=[]) ~key
    ~(iter : 'a callback)
    ?(add_update_hook : 'a callback option)
    ?(add_remove_hook : 'a callback option)
    ?(add_reload_hook : unit callback option)
    model =
  let open Markdown in
  let title =  Printf.sprintf "`ARRAY` %s" name in
  let index = [ Printf.sprintf "%s (`ARRAY`)" name ] in
  let columns = !model in
  let contents = [
    Block [Text descr] ;
    Syntax.fields ~title:"Columns"
      begin
        Syntax.{
          fd_name = "key" ;
          fd_syntax = Syntax.ident ;
          fd_descr = plain "entry identifier" ;
        } :: List.rev (List.map fst columns)
      end ;
    Block details
  ] in
  let mref = Server_doc.publish ~page:page ~name:name ~title ~index ~contents () in
  let signal = Request.signal ~page ~name:(name ^ ".sig")
      ~descr:(plain "Signal for array " @ href mref) () in
  let getter = List.map Syntax.(fun (fd,to_js) -> fd.fd_name , to_js) columns in
  let array = {
    key ; iter ; getter ; signal ;
    current = None ; projects = Hashtbl.create 0
  } in
  let signature =
    Request.signature ~kind:`GET ~page ~name:(name ^ ".fetch")
      ~descr:(plain "Fetch updates for array " @ href mref)
      ~input:(module Jint)
      ~details:[
        Text(plain
               "Collect all entry updates since the last fetch.\n\
                The number of fetched entries is limited to the\n\
                provided integer. When `reload:true` is returned,\n\
                _all_ previously received entries must be removed.")]
      () in
  let module Jentries =
    (struct
      include Jany
      let syntax = Syntax.data "entry" mref
    end) in
  let set_reload = Request.result signature
      ~name:"reload" ~descr:(plain "array fully reloaded")
      (module Jbool) in
  let set_removed = Request.result signature
      ~name:"removed" ~descr:(plain "removed entries")
      (module Jident.Jlist) in
  let set_updated = Request.result signature
      ~name:"updated" ~descr:(plain "updated entries")
      (module Jlist(Jentries)) in
  let set_pending = Request.result signature
      ~name:"pending" ~descr:(plain "remaining entries to be fetched")
      (module Jint) in
  Request.register_sig signature
    begin fun rq n ->
      let buffer = fetch array n in
      set_reload rq buffer.reload ;
      set_removed rq buffer.removed ;
      set_updated rq buffer.updated ;
      set_pending rq buffer.pending ;
    end ;
  Request.register ~kind:`GET ~page ~name:(name ^ ".reload")
    ~descr:(plain "Force full reload for array " @ href mref)
    ~input:(module Junit) ~output:(module Junit)
    (fun () -> reload array) ;
  synchronize array ;
  install signal (update array) add_update_hook ;
  install signal (remove array) add_remove_hook ;
  install signal (fun () -> reload array) add_reload_hook ;
  array

(* -------------------------------------------------------------------------- *)
