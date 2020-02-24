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

module Sy = Syntax
module Md = Markdown
module Js = Yojson.Basic.Util

open Data
open Kernel_main
open Kernel_ast

let page = Doc.page `Kernel ~title:"Property Services" ~filename:"properties.md"

(* -------------------------------------------------------------------------- *)
(* --- Property Kind                                                      --- *)
(* -------------------------------------------------------------------------- *)

module PropKind =
struct
  type t = string
  let syntax = Sy.publish ~page
      ~name:"propkind"
      ~descr:(Md.plain "Property Kind")
      ~synopsis:Sy.string ()
  open Property
  let kind = function
    | IPPredicate _ -> "predicate"
    | IPExtended { ie_ext={ ext_name } } -> ext_name
    | IPAxiomatic _ -> "axiomatic"
    | IPAxiom _ -> "axiom"
    | IPLemma _ -> "lemma"
    | IPBehavior _ -> "behavior"
    | IPComplete _ -> "complete"
    | IPDisjoint _ -> "disjoint"
    | IPCodeAnnot { ica_ca={ annot_content } } ->
      begin match annot_content with
        | AAssert _ -> "assert"
        | AStmtSpec _ -> "stmt-contract"
        | AInvariant(_,false,_) -> "code-invariant"
        | AInvariant(_,true,_) -> "loop-invariant"
        | AVariant _ -> "loop-variant"
        | AAssigns _ -> "loop-assigns"
        | AAllocation _ -> "loop-allocatation"
        | APragma _ -> "loop-pragma"
        | AExtended(_,_,{ext_name}) -> "loop-" ^ ext_name
      end
    | IPAllocation _ -> "allocation"
    | IPAssigns _ -> "assigns"
    | IPFrom _ -> "froms"
    | IPDecrease _ -> "decrease"
    | IPReachable _ -> "reachable"
    | IPPropertyInstance _ -> "instance"
    | IPTypeInvariant _ -> "type-invariant"
    | IPGlobalInvariant _ -> "invariant"
    | IPOther { io_name } -> io_name
  let to_json = Jstring.to_json
end

(* -------------------------------------------------------------------------- *)
(* --- Property Model                                                     --- *)
(* -------------------------------------------------------------------------- *)

let model = States.model ()

let () = States.column ~model ~name:"descr"
    ~descr:(Md.plain "Description")
    ~data:(module Jstring)
    ~get:(fun ip -> Format.asprintf "%a" Property.pretty ip) ()

let () = States.column ~model ~name:"kind"
    ~descr:(Md.plain "Kind")
    ~data:(module PropKind)
    ~get:(PropKind.kind) ()

let () = States.column ~model ~name:"status"
    ~descr:(Md.plain "Status")
    ~data:(module Jstring)
    ~get:(fun ip ->
        let st = Property_status.Feedback.get ip
        in Format.asprintf "%a" Property_status.Feedback.pretty st) ()

let () = States.column ~model ~name:"function"
    ~descr:(Md.plain "Function")
    ~data:(module Kf.Joption) ~get:Property.get_kf ()

let () = States.column ~model ~name:"kinstr"
    ~descr:(Md.plain "Instruction")
    ~data:(module Ki) ~get:Property.get_kinstr ()

let () = States.column ~model ~name:"source"
    ~descr:(Md.plain "Position")
    ~data:(module LogSource)
    ~get:(fun ip -> Property.location ip |> fst) ()

let array =
  States.register_array
    ~page
    ~name:"kernel.properties"
    ~descr:(Md.plain "Registered Properties")
    ~key:(Property.Names.get_prop_name_id)
    ~iter:(Property_status.iter)
    ~add_update_hook:Property_status.register_property_add_hook
    ~add_remove_hook:Property_status.register_property_remove_hook
    model

(* -------------------------------------------------------------------------- *)
