(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

let package = P.package ~plugin:"wp" ~name:"tac"
    ~title:"WP Tactics" ()

(* -------------------------------------------------------------------------- *)
(* --- Tacticals                                                          --- *)
(* -------------------------------------------------------------------------- *)

module Jtactic = (val D.jkey ~kind:"tactic")

module TacInfo =
struct
  type t = Tactical.t
  let jtype = D.declare ~package ~name:"tactic"
      ~descr:(Md.plain "TIP Tactic Information")
      (P.Jrecord [ "id", Jtactic.jtype; "label", Jstring; "title", Jstring])
  let of_json _ = D.failure "not implemented"
  let to_json (t : Tactical.t) : Json.t =
    `Assoc [
      "id", `String t#id ;
      "label", `String t#title ;
      "title", `String t#descr ;
    ]
end

module TacticId = D.Static(Map.Make(String))
    (struct let name = "tactic" end)

(* -------------------------------------------------------------------------- *)
(* --- Tactical Kind                                                      --- *)
(* -------------------------------------------------------------------------- *)

module Jkind =
struct
  include D.Jstring
  let jtype = D.declare ~package
      ~name:"kind" ~descr:(Md.plain "Parameter kind")
      (Junion [Jtag "checkbox"; Jtag "spinner"; Jtag "selector";
               Jtag "editor"; Jtag "browser"])
end

(* -------------------------------------------------------------------------- *)
(* --- Named Value Encoding                                               --- *)
(* -------------------------------------------------------------------------- *)

type value = V: 'a Tactical.named -> value

module Jvalue =
struct
  type t = value
  let jtype = D.declare ~package
      ~name:"value" ~descr:(Md.plain "Parameter option value")
      (Jrecord ["id",Jkey "value"; "label",Jstring; "title",Jstring])
  let of_json _ = D.failure "not implemented"
  let to_json (V a) = `Assoc [
      "id", `String a.vid ;
      "label", `String a.title ;
      "title", `String a.descr ;
    ]
end

let jvalues vlist = List.map (fun v -> V v) vlist

let joptions (type a)
    (values : a Tactical.named list)
    (equal : a -> a -> bool)
  : a D.data =
  let module M =
  struct
    type t = a
    let jtype = P.Jstring
    let to_json a =
      try `String (List.find (fun v -> equal v.Tactical.value a) values).vid
      with Not_found -> `Null
    let of_json js : t =
      let id = Json.string js in
      try (List.find (fun v -> v.Tactical.vid = id) values).value
      with Not_found -> D.failure "Incorrect value"
  end in (module M : (D.S with type t = a))

(* -------------------------------------------------------------------------- *)
(* --- Tactic Parameters & Fields                                         --- *)
(* -------------------------------------------------------------------------- *)

module Jparam = (val D.jkey ~kind:"param")

module Jparameter =
struct
  open D.Record
  type record
  let record : record signature = signature ()

  let id = field record ~name:"id"
      ~descr:(Md.plain "Parameter identifier") (module Jparam)

  let kind = field record ~name:"kind"
      ~descr:(Md.plain "Parameter kind") (module Jkind)

  let label = field record ~name:"label"
      ~descr:(Md.plain "Short name") (module D.Jstring)

  let title = field record ~name:"title"
      ~descr:(Md.plain "Description") (module D.Jstring)

  let enabled = field record ~name:"enabled"
      ~descr:(Md.plain "Enabled parameter")
      ~default:true (module D.Jbool)

  let value = field record ~name:"value"
      ~descr:(Md.plain "Value (with respect to kind)")
      (module D.Jany)

  let vmin = option record ~name:"vmin"
      ~descr:(Md.plain "Minimum range value (spinner only)")
      (module D.Jint)

  let vmax = option record ~name:"vmax"
      ~descr:(Md.plain "Maximum range value (spinner only)")
      (module D.Jint)

  let vstep = option record ~name:"vstep"
      ~descr:(Md.plain "Range step (spinner only)")
      (module D.Jint)

  let vlist = option record ~name:"vlist"
      ~descr:(Md.plain "List of options (selector only)")
      (module D.Jlist(Jvalue))

  include (val publish ~package
              ~name:"parameter"
              ~descr:(Md.plain "Parameter configuration")
              record)
end

class parameter
    ~(tactic : Tactical.t)
    ~(field : 'a Tactical.field)
    ~(kind : string)
    ~(data : 'a D.data)
    ?(range : int Tactical.range option)
    ?(options : 'a Tactical.named list option)
    () =
  let fd = Tactical.signature field in
  object(self)
    val mutable p_label = fd.title
    val mutable p_title = fd.descr
    val mutable p_vmin = None
    val mutable p_vmax = None
    val mutable p_vstep = None
    val mutable p_enabled = true
    initializer self#reset

    method reset =
      begin
        p_label <- fd.title ;
        p_title <- fd.descr ;
        p_vmin <- Option.bind range (fun rg -> rg.vmin) ;
        p_vmax <- Option.bind range (fun rg -> rg.vmax) ;
        p_vstep <- Option.map (fun rg -> rg.Tactical.vstep) range ;
        p_enabled <- true ;
      end

    method import (js : D.json) =
      tactic#set_field field (D.data_of_json data js)

    method update ?enabled ?title ?tooltip ?vmin ?vmax () =
      begin
        Option.iter (fun e -> p_enabled <- e) enabled ;
        Option.iter (fun s -> p_label <- s) title ;
        Option.iter (fun s -> p_title <- s) tooltip ;
        if vmin <> None then p_vmin <- vmin ;
        if vmax <> None then p_vmax <- vmax ;
      end

    method export : D.json =
      let module J = Jparameter in
      J.default
      |> J.set J.id fd.vid
      |> J.set J.kind kind
      |> J.set J.label p_label
      |> J.set J.title p_title
      |> J.set J.value (tactic#get_field field |> D.data_to_json data)
      |> J.set J.enabled p_enabled
      |> J.set J.vmin p_vmin
      |> J.set J.vmax p_vmax
      |> J.set J.vstep p_vstep
      |> J.set J.vlist (Option.map jvalues options)
      |> J.to_json

  end

module Phash = Hashtbl.Make
    (struct
      open Tactical
      type t = tactical * parameter
      let hash (t,p) = Hashtbl.hash (t#id ^ "::" ^ Tactical.param p)
      let equal (ta,pa) (tb,pb) = (ta == tb) && (pa == pb)
    end)

let parameters : parameter Phash.t = Phash.create 0

let parameter tactic param : parameter =
  let id = tactic,param in
  try Phash.find parameters id
  with Not_found ->
    let prm : parameter =
      match param with
      | Checkbox field ->
        new parameter ~tactic ~field ~kind:"checkbox" ~data:D.jbool ()
      | Spinner(field,range) ->
        new parameter ~tactic ~field ~kind:"spinner" ~data:D.jint ~range ()
      | Selector(field,options,equal) ->
        let data = joptions options equal in
        new parameter ~tactic ~field ~kind:"selector" ~data ~options ()
      | _ -> assert false
    in Phash.add parameters id prm ; prm

module ParameterConfig : D.S with type t = parameter =
struct
  type t = parameter
  let jtype = Jparameter.jtype
  let of_json _ = D.failure "not implemented"
  let to_json (p : parameter) = p#export
end

(* -------------------------------------------------------------------------- *)
(* --- Tactical Parameter Management                                      --- *)
(* -------------------------------------------------------------------------- *)

let configured = R.signal ~package ~name:"configured"
    ~descr:(Md.plain "Tactical configuration modified")

let () = R.register ~package ~kind:`GET
    ~name:"getTactics"
    ~descr:(Md.plain "List of registered tactics")
    ~input:(module D.Junit)
    ~output:(module D.Jlist(TacInfo))
    (fun () ->
       let pool = ref [] in
       Tactical.iter (fun t -> pool := t :: !pool) ;
       List.rev !pool)

let () = R.register ~package ~kind:`GET
    ~name:"getParameters"
    ~descr:(Md.plain "Return tactical current parameters")
    ~input:(module Jtactic)
    ~output:(module D.Jlist(ParameterConfig))
    ~signals:[configured]
    (fun id ->
       let tactic = Tactical.lookup ~id in
       List.map (parameter tactic) tactic#params)

let () =
  let setParameter = R.signature ~output:(module D.Junit) () in
  let get_tactic = R.param setParameter ~name:"tactic"
      ~descr:(Md.plain "Tactic to configure") (module Jtactic) in
  let get_param = R.param setParameter ~name:"param"
      ~descr:(Md.plain "Parameter to configure") (module Jparam) in
  let get_value = R.param setParameter ~name:"value"
      ~descr:(Md.plain "New parameter value") (module D.Jany) in
  R.register_sig ~package ~kind:`SET
    ~name:"setParameter"
    ~descr:(Md.plain "Configure tactical parameter")
    setParameter
    begin fun rq () ->
      let tactic = Tactical.lookup ~id:(get_tactic rq) in
      let param = Tactical.lookup_param tactic ~id:(get_param rq) in
      let p = parameter tactic param in
      p#import (get_value rq)
    end

(* -------------------------------------------------------------------------- *)
