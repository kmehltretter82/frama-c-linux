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

module Md = Markdown

open Data
open Kernel_main
open Kernel_ast

let page = Doc.page `Kernel ~title:"Property Services" ~filename:"properties.md"

(* -------------------------------------------------------------------------- *)
(* --- Property Kind                                                      --- *)
(* -------------------------------------------------------------------------- *)

module PropKind =
struct
  let kinds = Enum.dictionary ~page
      ~name:"propkind" ~title:"Kind"
      ~descr:(Md.plain "Property Kind")
      ()

  let t_kind name descr = Enum.tag kinds ~name ~descr:(Md.plain descr) ()
  let t_clause name = t_kind name (Printf.sprintf "Clause `@%s`" name)
  let t_loop name =
    t_kind ("loop-" ^ name) (Printf.sprintf "Clause `@loop %s`" name)

  let t_behavior = t_kind "behavior" "Contract behavior"
  let t_complete = t_kind "complete" "Complete behaviors clause"
  let t_disjoint = t_kind "disjoint" "Disjoint behaviors clause"

  let t_assumes = t_clause "assumes"
  let t_requires = t_clause "requires"
  let t_breaks = t_clause "breaks"
  let t_continues = t_clause "continues"
  let t_returns = t_clause "returns"
  let t_exits = t_clause "exits"
  let t_ensures = t_clause "ensures"
  let t_terminates = t_clause "terminates"
  let t_allocates = t_clause "allocates"
  let t_decreases = t_clause "decreases"
  let t_assigns = t_clause "assigns"
  let t_froms = t_kind "froms" "Clause `@assigns … \\from …`"

  let t_assert = t_clause "assert"
  let t_loop_invariant = t_loop "invariant"
  let t_loop_assigns = t_loop "assigns"
  let t_loop_variant = t_loop "variant"
  let t_loop_allocates = t_loop "allocates"
  let t_loop_pragma = t_loop "pragma"

  let t_reachable = t_kind "reachable" "Reachable statement"
  let t_code_contract = t_kind "code-contract" "Statement Contract"
  let t_code_invariant = t_kind "code-invariant" "Generalized loop invariant"
  let t_type_invariant = t_kind "type-invariant" "Type invariant"
  let t_global_invariant = t_kind "global-invariant" "Global invariant"

  let t_axiomatic = t_kind "axiomatic" "Axiomatic definitions"
  let t_axiom = t_kind "axiom" "Logical axiom"
  let t_lemma = t_kind "lemma" "Logical lemma"

  let p_ext = Enum.prefix kinds ~prefix:"ext" ~var:"<clause>"
      ~descr:(Md.plain "ACSL extension `<clause>`") ()

  let p_loop_ext = Enum.prefix kinds ~prefix:"loop-ext" ~var:"<clause>"
      ~descr:(Md.plain "ACSL loop extension `loop <clause>`") ()

  let p_other = Enum.prefix kinds ~prefix:"prop" ~var:"<prop>"
      ~descr:(Md.plain "Plugin Specific properties") ()

  open Property

  let rec tag = function
    | IPPredicate { ip_kind } ->
      begin match ip_kind with
        | PKRequires _ -> t_requires
        | PKAssumes _ -> t_assumes
        | PKEnsures(_,Normal) -> t_ensures
        | PKEnsures(_,Exits) -> t_exits
        | PKEnsures(_,Breaks) -> t_breaks
        | PKEnsures(_,Continues) -> t_continues
        | PKEnsures(_,Returns) -> t_returns
        | PKTerminates -> t_terminates
      end
    | IPExtended { ie_ext={ ext_name } } -> Enum.instance p_ext ext_name
    | IPAxiomatic _ -> t_axiomatic
    | IPAxiom _ -> t_axiom
    | IPLemma _ -> t_lemma
    | IPBehavior _ -> t_behavior
    | IPComplete _ -> t_complete
    | IPDisjoint _ -> t_disjoint
    | IPCodeAnnot { ica_ca={ annot_content } } ->
      begin match annot_content with
        | AAssert _ -> t_assert
        | AStmtSpec _ -> t_code_contract
        | AInvariant(_,false,_) -> t_code_invariant
        | AInvariant(_,true,_) -> t_loop_invariant
        | AVariant _ -> t_loop_variant
        | AAssigns _ -> t_loop_assigns
        | AAllocation _ -> t_loop_allocates
        | APragma _ -> t_loop_pragma
        | AExtended(_,_,{ext_name}) -> Enum.instance p_loop_ext ext_name
      end
    | IPAllocation _ -> t_allocates
    | IPAssigns _ -> t_assigns
    | IPFrom _ -> t_froms
    | IPDecrease _ -> t_decreases
    | IPReachable _ -> t_reachable
    | IPPropertyInstance { ii_ip } -> tag ii_ip
    | IPTypeInvariant _ -> t_type_invariant
    | IPGlobalInvariant _ -> t_global_invariant
    | IPOther { io_name } -> Enum.instance p_other io_name

  let data = Enum.publish kinds ~tag ()
  let () = Request.dictionary kinds

  include (val data : S with type t = Property.t)
end

let register_propkind ~name ~kind ?label ~descr () =
  let open PropKind in
  let prefix = match kind with
    | `Clause -> p_ext
    | `Loop -> p_loop_ext
    | `Other -> p_other
  in ignore @@ Enum.extends kinds prefix ~name ?label ~descr ()

(* -------------------------------------------------------------------------- *)
(* --- Property Status                                                    --- *)
(* -------------------------------------------------------------------------- *)

module PropStatus =
struct

  let status = Enum.dictionary ~page
      ~name:"propstatus" ~title:"Status"
      ~descr:(Md.plain "Property Status (consolidated)") ()

  let t_status value name ?label descr =
    Enum.tag status ~name
      ?label:(Extlib.opt_map Md.plain label)
      ~descr:(Md.plain descr) ~value ()

  open Property_status.Feedback

  let t_unknown =
    t_status Unknown "unknown" "Unknown status"
  let t_never_tried =
    t_status Never_tried "never_tried"
      ~label:"Never tried" "Unknown status (never tried)"
  let t_inconsistent =
    t_status Inconsistent "inconsistent" "Inconsistent status"
  let t_valid =
    t_status Valid "valid" "Valid property"
  let t_valid_under_hyp =
    t_status Valid_under_hyp "valid_under_hyp"
      ~label:"Valid (?)" "Valid (under hypotheses)"
  let t_considered_valid =
    t_status Considered_valid "considered_valid"
      ~label:"Valid (!)" "Valid (external assumption)"
  let t_invalid =
    t_status Invalid "invalid" "Invalid property (counter example found)"
  let t_invalid_under_hyp =
    t_status Invalid_under_hyp "invalid_under_hyp"
      ~label:"Invalid (?)" "Invalid property (under hypotheses)"
  let t_invalid_but_dead =
    t_status Invalid_but_dead "invalid_but_dead"
      ~label:"Invalid (✝)" "Dead property (but invalid)"
  let t_valid_but_dead =
    t_status Valid_but_dead "valid_but_dead"
      ~label:"Valid (✝)" "Dead property (but valid)"
  let t_unknown_but_dead =
    t_status Unknown_but_dead "unknown_but_dead"
      ~label:"Unknown (✝)" "Dead property (but unknown)"

  let tag = function
    | Valid -> t_valid
    | Invalid -> t_invalid
    | Unknown -> t_unknown
    | Never_tried -> t_never_tried
    | Valid_under_hyp -> t_valid_under_hyp
    | Valid_but_dead -> t_valid_but_dead
    | Considered_valid -> t_considered_valid
    | Invalid_under_hyp -> t_invalid_under_hyp
    | Invalid_but_dead -> t_invalid_but_dead
    | Unknown_but_dead -> t_unknown_but_dead
    | Inconsistent -> t_inconsistent

  let data = Enum.publish status ~tag ()
  let () = Request.dictionary status

  include (val data : S with type t = Property_status.Feedback.t)
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
    ~get:(fun ip -> ip) ()

let () = States.column ~model ~name:"status"
    ~descr:(Md.plain "Status")
    ~data:(module PropStatus)
    ~get:(Property_status.Feedback.get) ()

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
    ~key:(fun ip -> Kernel_ast.Marker.create (PIP ip))
    ~iter:(Property_status.iter)
    ~add_update_hook:Property_status.register_property_add_hook
    ~add_remove_hook:Property_status.register_property_remove_hook
    model

let reload () = States.reload array

(* -------------------------------------------------------------------------- *)
