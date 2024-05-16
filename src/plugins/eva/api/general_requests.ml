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
  Package.package
    ~plugin:"eva"
    ~name:"general"
    ~title:"Eva General Services"
    ()

module ComputationState = struct
  type t = Self.computation_state
  let jtype =
    Data.declare ~package
      ~name:"computationStateType"
      ~descr:(Markdown.plain "State of the computation of Eva Analysis.")
      Package.(Junion [
          Jtag "not_computed" ;
          Jtag "computing" ;
          Jtag "computed" ;
          Jtag "aborted" ])
  let to_json = function
    | Self.NotComputed -> `String "not_computed"
    | Computing -> `String "computing"
    | Computed -> `String "computed"
    | Aborted -> `String "aborted"
end

let computation_signal =
  States.register_framac_value ~package
    ~name:"computationState"
    ~descr:(Markdown.plain "The current computation state of the analysis.")
    ~output:(module ComputationState)
    (module Self.ComputationState)

(* ----- Callers & Callees -------------------------------------------------- *)

module CallSite =
struct
  type t = kernel_function * stmt
  let jtype = Data.declare ~package ~name:"CallSite"
      ~descr:(Markdown.plain "Callee function and caller stmt")
      (Jrecord [
          "call", Kernel_ast.Decl.jtype;
          "stmt", Kernel_ast.Stmt.jtype;
        ])
  let to_json (kf,stmt) = `Assoc [
      "call", Kernel_ast.Decl.to_json (SFunction kf);
      "stmt", Kernel_ast.Stmt.to_json stmt;
    ]
  let of_json _ = failwith "CallSite"
end

let callers = function
  | Printer_tag.SFunction kf ->
    let list = Results.callsites kf in
    List.concat (List.map (fun (kf, l) -> List.map (fun s -> kf, s) l) list)
  | _ -> []

let () = Request.register ~package
    ~kind:`GET ~name:"getCallers"
    ~descr:(Markdown.plain "Get the list of call sites for a function")
    ~input:(module Kernel_ast.Decl) ~output:(module Data.Jlist (CallSite))
    ~signals:[computation_signal]
    callers

let eval_callee stmt lval =
  let expr = Eva_utils.lval_to_exp lval in
  Results.(before stmt |> eval_callee expr |> default [])

let callees = function
  | Printer_tag.PLval (_kf, Kstmt stmt, (Mem _, NoOffset as lval))
    when Cil.(isFunctionType (typeOfLval lval)) ->
    List.map (fun kf -> Printer_tag.SFunction kf) @@
    eval_callee stmt lval
  | Printer_tag.PLval (_kf, Kstmt stmt, lval)
    when Cil.(isFunPtrType (Cil.typeOfLval lval)) ->
    List.map (fun kf -> Printer_tag.SFunction kf) @@
    eval_callee stmt (Mem (Eva_utils.lval_to_exp lval), NoOffset)
  | _ -> []

let () = Request.register ~package
    ~kind:`GET ~name:"getCallees"
    ~descr:(Markdown.plain
              "Return the functions pointed to by a function pointer")
    ~input:(module Kernel_ast.Marker)
    ~output:(module Data.Jlist(Kernel_ast.Decl))
    ~signals:[computation_signal]
    callees

(* ----- Functions ---------------------------------------------------------- *)

module Functions =
struct
  let _array : kernel_function States.array =
    let model = States.model () in

    States.column model
      ~name:"eva_analyzed"
      ~descr:(Markdown.plain "Has the function been analyzed by Eva")
      ~data:(module Data.Jbool)
      ~default:false
      ~get:Results.is_called;

    States.register_array model
      ~package
      ~key:Server.Kernel_ast.Functions.key
      ~name:"functions"
      ~descr:(Markdown.plain "AST Functions")
      ~iter:Server.Kernel_ast.Functions.iter
      ~add_reload_hook:(fun f ->
          Analysis.register_computation_hook (fun _ -> f () ))
end



(* ----- Dead code: unreachable and non-terminating statements -------------- *)

type dead_code =
  { kf: Kernel_function.t;
    reached : stmt list;
    unreachable : stmt list;
    non_terminating : stmt list; }

module DeadCode = struct
  open Server.Data

  type record
  let record : record Record.signature = Record.signature ()

  let reached = Record.field record ~name:"reached"
      ~descr:(Markdown.plain "List of statements reached by the analysis.")
      (module Data.Jlist (Kernel_ast.Marker))

  let unreachable = Record.field record ~name:"unreachable"
      ~descr:(Markdown.plain "List of unreachable statements.")
      (module Data.Jlist (Kernel_ast.Marker))

  let non_terminating = Record.field record ~name:"nonTerminating"
      ~descr:(Markdown.plain "List of reachable but non terminating statements.")
      (module Data.Jlist (Kernel_ast.Marker))

  let data = Record.publish record ~package ~name:"deadCode"
      ~descr:(Markdown.plain "Unreachable and non terminating statements.")

  module R : Record.S with type r = record = (val data)
  type t = dead_code
  let jtype = R.jtype

  let to_json dead_code =
    let make_stmt stmt = Printer_tag.PStmt (dead_code.kf, stmt) in
    let make_non_term stmt = Printer_tag.PStmtStart (dead_code.kf, stmt) in
    R.default |>
    R.set reached (List.map make_stmt dead_code.reached) |>
    R.set unreachable (List.map make_stmt dead_code.unreachable) |>
    R.set non_terminating (List.map make_non_term dead_code.non_terminating) |>
    R.to_json

  let of_json _ = Data.failure "DeadCode.of_json not implemented"
end

let all_statements kf =
  try (Kernel_function.get_definition kf).sallstmts
  with Kernel_function.No_Definition -> []

let dead_code = function
  | Printer_tag.SFunction kf ->
    let empty = { kf; reached = []; unreachable = []; non_terminating = [] } in
    let record =
      if Analysis.is_computed () then
        let body = all_statements kf in
        match Analysis.status kf with
        | Unreachable | SpecUsed | Builtin _ -> { empty with unreachable = body }
        | Analyzed NoResults -> empty
        | Analyzed (Partial | Complete) ->
          let classify { kf ; reached ; unreachable ; non_terminating = nt } stmt =
            let before = Results.(before stmt |> is_empty) in
            let after = Results.(after stmt |> is_empty) in
            let unreachable = if before then stmt :: unreachable else unreachable in
            let reached = if not before then stmt :: reached else reached in
            let non_terminating = if not before && after then stmt :: nt else nt in
            { kf ; reached ; unreachable ; non_terminating }
          in
          List.fold_left classify empty body
      else empty
    in
    Some record
  | _ -> None

let () = Request.register ~package
    ~kind:`GET ~name:"getDeadCode"
    ~descr:(Markdown.plain
              "Get the lists of unreachable and of non terminating \
               statements in a function")
    ~input:(module Kernel_ast.Decl)
    ~output:(module Data.Joption (DeadCode))
    ~signals:[computation_signal]
    dead_code

(* ----- Register Eva values information ------------------------------------ *)

type evaluation_point =
  | Initial
  | Pre of kernel_function
  | Stmt of kernel_function * stmt

let post kf =
  if Analysis.use_spec_instead_of_definition kf
  then raise Not_found
  else
    try Stmt (kf, Kernel_function.find_return kf)
    with Kernel_function.No_Statement -> raise Not_found

let request_at = function
  | Initial -> Results.at_start
  | Stmt (_, stmt) -> Results.before stmt
  | Pre kf -> Results.at_start_of kf

let property_evaluation_point = function
  | Property.IPCodeAnnot { ica_kf = kf; ica_stmt = stmt }
  | IPPropertyInstance { ii_kf = kf; ii_stmt = stmt } -> Stmt (kf, stmt)
  | IPPredicate {ip_kf; ip_kind = PKEnsures (_, Normal)} -> post ip_kf
  | IPPredicate { ip_kf = kf;
                  ip_kind = PKRequires _ | PKAssumes _ | PKTerminates }
  | IPAssigns {ias_kf = kf} | IPFrom {if_kf = kf} ->
    Pre kf
  | IPPredicate _ | IPComplete _ | IPDisjoint _ | IPDecrease _
  | IPAxiomatic _ | IPLemma _ | IPTypeInvariant _ | IPGlobalInvariant _
  | IPOther _ | IPAllocation _ | IPReachable _ | IPExtended _ | IPBehavior _ ->
    raise Not_found

let marker_evaluation_point = function
  | Printer_tag.PGlobal _ -> Initial
  | PStmt (kf, stmt) | PStmtStart (kf, stmt) -> Stmt (kf, stmt)
  | PVDecl (kf, kinstr, v) when not (v.vformal || v.vglob) ->
    begin
      (* Only evaluate declaration of local variable if it is initialized. *)
      match kf, kinstr with
      | Some kf, Kstmt ({skind = Instr (Local_init _)} as s) -> Stmt (kf, s)
      | _ -> raise Not_found
    end
  | PLval (kf, ki, _) | PExp (kf, ki, _) | PVDecl (kf, ki, _) ->
    begin
      match kf, ki with
      | Some kf, Kstmt stmt -> Stmt (kf, stmt)
      | Some kf, Kglobal -> Pre kf
      | None, Kglobal -> Initial
      | None, Kstmt _ -> assert false
    end
  | PTermLval (_, _, prop, _) | PIP prop -> property_evaluation_point prop
  | PType _ -> raise Not_found

let term_lval_to_lval kf tlval =
  try
    let result = Option.bind kf Eva_utils.find_return_var in
    Logic_to_c.term_lval_to_lval ?result tlval
  with Logic_to_c.No_conversion -> raise Not_found

let print_value fmt loc =
  let is_scalar = Cil.isScalarType in
  let evaluation_point = marker_evaluation_point loc in
  let request = request_at evaluation_point in
  let eval =
    match loc with
    | Printer_tag.PLval (_, _, lval) when is_scalar (Cil.typeOfLval lval) ->
      Results.eval_lval lval
    | Printer_tag.PExp (_, _, expr) when is_scalar (Cil.typeOf expr) ->
      Results.eval_exp expr
    | PVDecl (_, _, vi) when is_scalar vi.vtype ->
      Results.eval_var vi
    | PTermLval (kf, _, _ip, tlval) ->
      let lval = term_lval_to_lval kf tlval in
      if is_scalar (Cil.typeOfLval lval)
      then Results.eval_lval lval
      else raise Not_found
    | _ -> raise Not_found
  in
  let pretty = Cvalue.V_Or_Uninitialized.pretty in
  let eval_cvalue at = Results.(eval at |> as_cvalue_or_uninitialized) in
  let before = eval_cvalue request in
  match evaluation_point with
  | Initial | Pre _ -> pretty fmt before
  | Stmt (_, stmt) ->
    let after = eval_cvalue (Results.after stmt) in
    if Cvalue.V_Or_Uninitialized.equal before after
    then pretty fmt before
    else Format.fprintf fmt "Before: %a@\nAfter:  %a" pretty before pretty after

let () =
  Server.Kernel_ast.Information.register
    ~id:"eva.value"
    ~label:"Value"
    ~title:"Possible values inferred by Eva"
    ~enable:Analysis.is_computed
    print_value



(* ----- Register Eva taints information ------------------------------------ *)

let expr_of_lval v = Cil.new_exp ~loc:Cil_datatype.Location.unknown (Lval v)

module EvaTaints = struct
  open Results

  let evaluate expr request =
    let (let+) = Option.bind in
    let Deps.{ data ; indirect } = expr_dependencies expr request in
    let+ data = is_tainted data request |> Result.to_option in
    let+ indirect = is_tainted indirect request |> Result.to_option in
    Some (data, indirect)

  let expr_of_marker = let open Printer_tag in function
      | PLval (_, Kstmt stmt, lval) -> Some (expr_of_lval lval, stmt)
      | PExp (_, Kstmt stmt, expr) -> Some (expr, stmt)
      | PVDecl (_, Kstmt stmt, vi) -> Some (expr_of_lval (Var vi, NoOffset), stmt)
      | PTermLval (kf, Kstmt stmt, _, tlval) ->
        Some (term_lval_to_lval kf tlval |> expr_of_lval, stmt)
      | _ -> None

  let of_marker marker =
    let (let+) = Option.bind in
    let+ expr, stmt = expr_of_marker marker in
    let+ before = evaluate expr (before stmt) in
    let+ after  = evaluate expr (after  stmt) in
    Some (before, after)

  let to_string = function
    | Untainted -> "untainted"
    | Direct -> "direct taint"
    | Indirect -> "indirect taint"

  let pp fmt = function
    | taint, Untainted -> Format.fprintf fmt "%s" (to_string taint)
    | data, indirect ->
      let sep = match data with Untainted -> "but" | _ -> "and" in
      Format.fprintf fmt
        "%s to the value, %s %s to values used to compute lvalues adresses"
        (to_string data) sep (to_string indirect)

  let print_taint fmt marker =
    match of_marker marker with
    | None -> raise Not_found
    | Some (before, after) ->
      if before = after
      then Format.fprintf fmt "%a" pp before
      else Format.fprintf fmt "Before: %a@\nAfter: %a" pp before pp after

  let eva_taints_descr =
    "Taint status:\n\
     - Direct taint: data dependency from values provided by the attacker, \
     meaning that the attacker may be able to alter this value\n\
     - Indirect taint: the attacker cannot directly alter this value, but he \
     may be able to impact the path by which its value is computed.\n\
     - Untainted: cannot be modified by the attacker."

  let () =
    let taint_computed = Taint_domain.Store.is_computed in
    let enable () = Analysis.is_computed () && taint_computed () in
    Server.Kernel_ast.Information.register
      ~id:"eva.taint" ~label:"Taint" ~title: "Taint status according to Eva"
      ~descr:eva_taints_descr ~enable print_taint

  let update = Server.Kernel_ast.Information.update
  let () = Analysis.register_computation_hook (fun _ -> update ())
end



(* ----- Taint statuses ----------------------------------------------------- *)

module TaintStatus = struct
  open Server.Data

  type taint = Results.taint = Direct | Indirect | Untainted
  type error = NotComputed | Irrelevant | LogicError

  let dictionary = Enum.dictionary ()

  let tag value name label short_descr long_descr =
    Enum.tag ~name
      ~label:(Markdown.plain label)
      ~descr:(Markdown.bold (short_descr ^ ": ") @ Markdown.plain long_descr)
      ~value dictionary

  let tag_not_computed =
    tag (Error NotComputed) "not_computed" "" "Not computed"
      "the Eva taint domain has not been enabled, \
       or the Eva analysis has not been run"

  let tag_error =
    tag (Error LogicError) "error" "Error" "Error"
      "the memory zone on which this property depends could not be computed"

  let tag_not_applicable =
    tag (Error Irrelevant) "not_applicable" "—" "Not applicable"
      "no taint for this kind of property"

  let tag_direct_taint =
    tag (Ok Direct) "direct_taint" "Tainted (direct)" "Direct taint"
      "this property is related to a memory location that can be affected \
       by an attacker"

  let tag_indirect_taint =
    tag (Ok Indirect) "indirect_taint" "Tainted (indirect)" "Indirect taint"
      "this property is related to a memory location whose assignment depends \
       on path conditions that can be affected by an attacker"

  let tag_untainted =
    tag (Ok Untainted) "not_tainted" "Untainted" "Untainted property"
      "this property is safe"

  let () = Enum.set_lookup dictionary @@ function
    | Error NotComputed -> tag_not_computed
    | Error Irrelevant -> tag_not_applicable
    | Error LogicError -> tag_error
    | Ok Direct -> tag_direct_taint
    | Ok Indirect -> tag_indirect_taint
    | Ok Untainted -> tag_untainted

  let data = Request.dictionary ~package ~name:"taintStatus"
      ~descr:(Markdown.plain "Taint status of logical properties") dictionary

  include (val data : S with type t = (taint, error) result)
end



(* ----- Tainted lvalues ---------------------------------------------------- *)

module LvalueTaints = struct
  module Table = Cil_datatype.Lval.Hashtbl

  module Status = struct
    type record
    let record: record Data.Record.signature = Data.Record.signature ()
    let field name d = Data.Record.field record ~name ~descr:(Markdown.plain d)
    let lval_field = field "lval" "tainted lvalue" (module Kernel_ast.Lval)
    let taint_field = field "taint" "taint status" (module TaintStatus)
    let name, descr = "LvalueTaints", Markdown.plain "Lvalue taint status"
    let publication = Data.Record.publish record ~package ~name ~descr
    include (val publication: Data.Record.S with type r = record)
    let create lval taint = set lval_field lval @@ set taint_field taint default
  end

  let current_project () = Visitor_behavior.inplace ()
  class tainted_lvalues taints = object (self)
    inherit Visitor.generic_frama_c_visitor (current_project ())
    method! vlval lval =
      let expr = expr_of_lval lval in
      match self#current_stmt with
      | None -> Cil.DoChildren
      | Some stmt ->
        match Results.after stmt |> EvaTaints.evaluate expr with
        | Some (Results.Untainted, _) -> DoChildren
        | Some (t, _) -> Table.add taints lval (Kstmt stmt, t) ; Cil.DoChildren
        | None -> Cil.DoChildren
  end

  let get_tainted_lvals kf =
    try
      let fn = Kernel_function.get_definition kf in
      let taints = Table.create 17 in
      Visitor.visitFramacFunction (new tainted_lvalues taints) fn |> ignore ;
      let fn lval (ki, taint) acc = Status.create (ki, lval) (Ok taint) :: acc in
      Table.fold fn taints [] |> List.rev
    with Kernel_function.No_Definition -> []

  let () = Request.register ~package ~kind:`GET ~name:"taintedLvalues"
      ~descr:(Markdown.plain "Get the tainted lvalues of a given function")
      ~input:(module (Kernel_ast.Decl))
      ~output:(module (Data.Jlist (Status)))
      ~signals:[computation_signal]
      (function SFunction kf -> get_tainted_lvals kf | _ -> [])

end

(* ----- Red and tainted alarms --------------------------------------------- *)

module PropertiesData = struct
  open TaintStatus

  let zone_of_predicate kinstr predicate =
    let state = Results.(before_kinstr kinstr |> get_cvalue_model) in
    let env = Eval_terms.env_only_here state in
    let logic_deps = Eval_terms.predicate_deps env predicate in
    match Option.map Cil_datatype.Logic_label.Map.bindings logic_deps with
    | Some [ BuiltinLabel Here, zone ] -> Ok zone
    | _ -> Error LogicError

  let get_predicate = function
    | Property.IPCodeAnnot ica ->
      begin
        match ica.ica_ca.annot_content with
        | AAssert (_, predicate) | AInvariant (_, _, predicate) ->
          Ok predicate.tp_statement
        | _ -> Error Irrelevant
      end
    | IPPropertyInstance { ii_pred = None } -> Error LogicError
    | IPPropertyInstance { ii_pred = Some ip } -> Ok ip.ip_content.tp_statement
    | _ -> Error Irrelevant

  let is_tainted_property ip =
    if Analysis.is_computed () && Taint_domain.Store.is_computed () then
      let (let+) = Result.bind in
      let kinstr = Property.get_kinstr ip in
      let+ predicate = get_predicate ip in
      let+ zone = zone_of_predicate kinstr predicate in
      let result = Results.(before_kinstr kinstr |> is_tainted zone) in
      Result.map_error (fun _ -> NotComputed) result
    else Error NotComputed

  let () =
    let model = States.model () in
    let descr = "Is the property invalid in some context of the analysis?" in
    States.column model
      ~name:"priority"
      ~descr:(Markdown.plain descr)
      ~data:(module Data.Jbool)
      ~get:Red_statuses.is_red ;
    let descr = "Is the property tainted according to the Eva taint domain?" in
    States.column model
      ~name:"taint"
      ~descr:(Markdown.plain descr)
      ~data:(module TaintStatus)
      ~get:is_tainted_property ;
    let add_reload_hook hook =
      Analysis.register_computation_hook ~on:Computed (fun _ -> hook ())
    and add_update_hook hook =
      Red_statuses.register_hook (function Prop p -> hook p | Alarm _ -> ())
    in
    ignore @@ States.register_array
      ~package
      ~name:"properties"
      ~descr:(Markdown.plain "Status of Registered Properties")
      ~key:(fun ip -> Kernel_ast.Marker.index (PIP ip))
      ~keyType:Kernel_ast.Marker.jtype
      ~iter:Property_status.iter
      ~add_update_hook
      ~add_reload_hook
      model
end



(* ----- Analysis statistics ------------------------------------------------ *)

module AlarmCategory = struct
  open Server.Data

  module Tags =
  struct
    let dictionary = Enum.dictionary ()

    (* Give a normal representation of the category *)
    let repr =
      let e = List.hd Cil_datatype.Exp.reprs in
      let lv = List.hd Cil_datatype.Lval.reprs in
      function
      | Summary.Division_by_zero -> Alarms.Division_by_zero e
      | Memory_access -> Memory_access (lv, For_reading)
      | Index_out_of_bound-> Index_out_of_bound (e, None)
      | Invalid_shift -> Invalid_shift (e, None)
      | Overflow -> Overflow (Signed, e, Integer.one, Lower_bound)
      | Uninitialized -> Uninitialized lv
      | Dangling -> Dangling lv
      | Nan_or_infinite -> Is_nan_or_infinite (e, FFloat)
      | Float_to_int -> Float_to_int (e, Integer.one, Lower_bound)
      | Other -> assert false

    let register alarm_category =
      let name, descr = match alarm_category with
        | Summary.Other -> "other", "Any other alarm"
        | alarm_category ->
          let alarm = repr alarm_category in
          Alarms.(get_short_name alarm, get_description alarm)
      in
      Enum.tag dictionary
        ~name
        ~label:(Markdown.plain name)
        ~descr:(Markdown.plain descr)

    let division_by_zero = register Division_by_zero
    let memory_access = register Memory_access
    let index_out_of_bound = register Index_out_of_bound
    let invalid_shift = register Invalid_shift
    let overflow = register Overflow
    let uninitialized = register Uninitialized
    let dangling = register Dangling
    let nan_or_infinite = register Nan_or_infinite
    let float_to_int = register Float_to_int
    let other = register Other

    let () = Enum.set_lookup dictionary
        begin function
          | Summary.Division_by_zero -> division_by_zero
          | Memory_access -> memory_access
          | Index_out_of_bound -> index_out_of_bound
          | Invalid_shift -> invalid_shift
          | Overflow -> overflow
          | Uninitialized -> uninitialized
          | Dangling -> dangling
          | Nan_or_infinite -> nan_or_infinite
          | Float_to_int -> float_to_int
          | Other -> other
        end
  end

  let name = "alarmCategory"
  let descr = Markdown.plain
      "The alarms are counted after being grouped by these categories"
  let data = Request.dictionary ~package ~name ~descr Tags.dictionary

  include (val data : S with type t = Summary.alarm_category)
end

module Coverage =
struct
  open Summary
  type t = coverage
  let jtype = Package.(
      Jrecord [
        "reachable",Jnumber ;
        "dead",Jnumber ;
      ])
  let to_json x = `Assoc [
      "reachable", `Int x.reachable ;
      "dead", `Int x.dead ;
    ]
end

module Events =
struct
  open Summary
  let jtype = Package.(
      Jrecord [
        "errors",Jnumber ;
        "warnings",Jnumber ;
      ])
  let to_json x = `Assoc [
      "errors", `Int x.errors ;
      "warnings", `Int x.warnings ;
    ]
end

module Statuses =
struct
  open Summary
  type t = statuses
  let jtype =
    Data.declare ~package
      ~name:"statusesEntry"
      ~descr:(Markdown.plain "Statuses count.")
      Package.(Jrecord [
          "valid",Jnumber ;
          "unknown",Jnumber ;
          "invalid",Jnumber ;
        ])
  let to_json x = `Assoc [
      "valid", `Int x.valid ;
      "unknown", `Int x.unknown ;
      "invalid", `Int x.invalid ;
    ]
end

module AlarmEntry =
struct
  let jtype =
    Data.declare ~package
      ~name:"alarmEntry"
      ~descr:(Markdown.plain "Alarm count for each alarm category.")
      Package.(Jrecord [
          "category", AlarmCategory.jtype ;
          "count", Jnumber ])
  let to_json (a,c) =  `Assoc [
      "category", AlarmCategory.to_json a ;
      "count", `Int c ]
end

module Alarms =
struct
  type t = (AlarmCategory.t * int) list
  let jtype = Package.Jarray AlarmEntry.jtype
  let to_json x = `List (List.map AlarmEntry.to_json x)
end

module Statistics = struct
  open Summary
  type t = program_stats
  let jtype =
    Data.declare ~package
      ~name:"programStatsType"
      ~descr:(Markdown.plain "Statistics about an Eva analysis.")
      Package.(Jrecord [
          "progFunCoverage",Coverage.jtype ;
          "progStmtCoverage",Coverage.jtype ;
          "progAlarms", Alarms.jtype ;
          "evaEvents",Events.jtype ;
          "kernelEvents",Events.jtype ;
          "alarmsStatuses",Statuses.jtype ;
          "assertionsStatuses",Statuses.jtype ;
          "precondsStatuses",Statuses.jtype ])
  let to_json x = `Assoc [
      "progFunCoverage", Coverage.to_json x.prog_fun_coverage ;
      "progStmtCoverage", Coverage.to_json x.prog_stmt_coverage ;
      "progAlarms", Alarms.to_json x.prog_alarms ;
      "evaEvents", Events.to_json x.eva_events ;
      "kernelEvents", Events.to_json x.kernel_events ;
      "alarmsStatuses", Statuses.to_json x.alarms_statuses ;
      "assertionsStatuses", Statuses.to_json x.assertions_statuses ;
      "precondsStatuses", Statuses.to_json x.preconds_statuses ]
end

let _computed_signal =
  States.register_value ~package
    ~name:"programStats"
    ~descr:(Markdown.plain
              "Statistics about the last Eva analysis for the whole program")
    ~output:(module Statistics)
    ~get:Summary.compute_stats
    ~add_hook:(Analysis.register_computation_hook ~on:Computed)
    ()

let _functionStats =
  let open Summary in
  let model = States.model () in

  States.column model ~name:"fctName"
    ~descr:(Markdown.plain "Function name")
    ~data:(module Data.Jalpha)
    ~get:(fun (kf,_) -> Kernel_function.get_name kf);

  States.column model ~name:"coverage"
    ~descr:(Markdown.plain "Coverage of the Eva analysis")
    ~data:(module Coverage)
    ~get:(fun (_kf,stats) -> stats.fun_coverage);

  States.column model ~name:"alarmCount"
    ~descr:(Markdown.plain "Alarms raised by the Eva analysis by category")
    ~data:(module Alarms)
    ~get:(fun (_kf,stats) -> stats.fun_alarm_count);

  States.column model ~name:"alarmStatuses"
    ~descr:(Markdown.plain "Alarms statuses emitted by the Eva analysis")
    ~data:(module Statuses)
    ~get:(fun (_kf,stats) -> stats.fun_alarm_statuses);

  States.register_framac_array
    ~package
    ~name:"functionStats"
    ~descr:(Markdown.plain
              "Statistics about the last Eva analysis for each function")
    ~key:(fun kf -> Kernel_ast.Decl.index (SFunction kf))
    ~keyType:(Kernel_ast.Decl.jtype)
    model (module FunctionStats)



(* ----- Domains states ----------------------------------------------------- *)

let compute_lval_deps request lval =
  let zone = Results.lval_deps lval request in
  Locations.Zone.get_bases zone

let compute_expr_deps request expr =
  let zone = Results.expr_deps expr request in
  Locations.Zone.get_bases zone

let compute_instr_deps request = function
  | Set (lval, expr, _) ->
    Base.SetLattice.join
      (compute_lval_deps request lval)
      (compute_expr_deps request expr)
  | Local_init (vi, AssignInit (SingleInit expr), _) ->
    Base.SetLattice.join
      (Base.SetLattice.inject_singleton (Base.of_varinfo vi))
      (compute_expr_deps request expr)
  | _ -> Base.SetLattice.empty

let compute_stmt_deps request stmt =
  match stmt.skind with
  | Instr (instr) -> compute_instr_deps request instr
  | If (expr, _, _, _) -> compute_expr_deps request expr
  | _ -> Base.SetLattice.empty

let compute_marker_deps request = function
  | Printer_tag.PStmt (_, stmt)
  | PStmtStart (_, stmt) -> compute_stmt_deps request stmt
  | PLval (_, _, lval) -> compute_lval_deps request lval
  | PExp (_, _, expr) -> compute_expr_deps request expr
  | PVDecl (_, _, vi) -> Base.SetLattice.inject_singleton (Base.of_varinfo vi)
  | _ -> Base.SetLattice.empty

let get_filtered_state request marker =
  let bases = compute_marker_deps request marker in
  match bases with
  | Base.SetLattice.Top -> Results.print_states request
  | Base.SetLattice.Set bases ->
    if Base.Hptset.is_empty bases
    then []
    else Results.print_states ~filter:bases request

let get_state filter request marker =
  if filter
  then get_filtered_state request marker
  else Results.print_states request

let get_states (marker, filter) =
  let kinstr = Printer_tag.ki_of_localizable marker in
  match kinstr with
  | Kglobal -> []
  | Kstmt stmt ->
    let states_before = get_state filter (Results.before stmt) marker in
    let states_after = get_state filter (Results.after stmt) marker in
    match states_before, states_after with
    | [], _ -> List.map (fun (name, after) -> name, "", after) states_after
    | _, [] -> List.map (fun (name, before) -> name, before, "") states_before
    | _, _ ->
      let join (name, before) (name', after) =
        assert (name = name');
        name, before, after
      in
      List.rev_map2 join states_before states_after

let () = Request.register ~package
    ~kind:`GET ~name:"getStates"
    ~descr:(Markdown.plain "Get the domain states about the given marker")
    ~input:(module Data.Jpair (Kernel_ast.Marker) (Data.Jbool))
    ~output:(module Data.Jlist
          (Data.Jtriple (Data.Jstring) (Data.Jstring) (Data.Jstring)))
    ~signals:[computation_signal]
    get_states

(* -------------------------------------------------------------------------- *)
