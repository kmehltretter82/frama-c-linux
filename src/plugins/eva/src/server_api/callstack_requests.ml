(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Server

let package =
  let title = "Callstacks analyzed by Eva" in
  Package.package ~plugin:"eva" ~name:"callstack" ~title ()

module Results = Eva__Results


let rec is_compatible_stack st1 st2 =
  match st1, st2 with
  | [], _ | _, [] -> true
  | (kf1, stmt1) :: st1, (kf2, stmt2) :: st2 ->
    Kernel_function.equal kf1 kf2
    && Cil_datatype.Stmt.equal stmt1 stmt2
    && is_compatible_stack st1 st2

(* Returns true if one callstack is prefix of the other. *)
let is_compatible_callstack cs1 cs2 =
  let open Callstack in
  cs1.thread = cs2.thread
  && Kernel_function.equal cs1.entry_point cs2.entry_point
  && is_compatible_stack (List.rev cs1.stack) (List.rev cs2.stack)

let is_compatible callstacks cs =
  List.exists (fun cs' -> is_compatible_callstack cs cs') callstacks

let compatible_filter () =
  match Update.CurrentCallstacks.get () with
  | [] -> None
  | callstacks -> Some (is_compatible callstacks)


let compare_call (kf1, stmt1) (kf2, stmt2) =
  let c = Int.compare stmt1.Cil_types.sid stmt2.Cil_types.sid in
  if c <> 0 then c else Kernel_function.compare kf1 kf2

let compare_reversed_callstack (cs1 : Callstack.t) (cs2 : Callstack.t) =
  let c = Int.compare cs1.thread cs2.thread in
  if c <> 0 then c else
    let c = Kernel_function.compare cs1.entry_point cs2.entry_point in
    if c <> 0 then c else
      List.compare compare_call (cs1.stack) (cs2.stack)

let sort_callstacks list =
  let reverse_stack cs = Callstack.{ cs with stack = List.rev cs.stack } in
  List.map reverse_stack list |>
  List.fast_sort compare_reversed_callstack |>
  List.map reverse_stack

(* -------------------------------------------------------------------------- *)
(* ----- Callstack info                                                 ----- *)
(* -------------------------------------------------------------------------- *)

let fct_decl kf = Kernel_ast.Decl.to_json (Printer_tag.SFunction kf)

module JCallsite = struct
  type t = Callstack.call

  let jtype =
    Server.Data.declare ~package
      ~name:"callsite" ~descr:(Markdown.plain "Call site infos")
      (Jrecord [
          "caller", Kernel_ast.Decl.jtype;
          "callee", Kernel_ast.Decl.jtype;
          "stmt", Kernel_ast.Stmt.jtype;
          "rank", Jnumber;
        ])

  let to_json' ~caller (callee, stmt) =
    `Assoc [
      "caller", fct_decl caller;
      "callee", fct_decl callee;
      "stmt", Kernel_ast.Stmt.to_json stmt;
      "rank", Data.Jint.to_json stmt.sid ;
    ]

  let to_json (callee, stmt) =
    let caller = Kernel_function.find_englobing_kf stmt in
    to_json' ~caller (callee, stmt)

  let of_json _ = Data.failure "JCallsite.of_json not implemented"
end

module JStack = struct
  let jtype = Package.(Jarray JCallsite.jtype)

  let to_json ~entry_point stack =
    let aux (acc, caller) (callee, stmt) =
      JCallsite.to_json' ~caller (callee, stmt) :: acc, callee
    in
    let l, _last_callee = List.fold_left aux ([], entry_point) stack in
    `List l
end

module JCallstackData = struct
  type t = Callstack.t

  let jtype =
    Server.Data.declare ~package
      ~name:"callstackInfo" ~descr:(Markdown.plain "Callstack infos")
      (Jrecord [
          "thread" , Jstring;
          "entryPoint" , Kernel_ast.Decl.jtype;
          "stack" , JStack.jtype;
          "analyzed", Jboolean;
        ])

  let thread_label id =
    match Thread.find id with
    | Some thread -> Thread.label thread
    | None -> string_of_int id

  let analyzed callstack =
    let kf = Callstack.top_kf callstack in
    match Analysis.status kf with
    | Analyzed _ -> not (Kernel_function.is_in_libc kf)
    | Unreachable | SpecUsed | Builtin _ -> false

  let to_json (cs: t) =
    let entry_point = cs.entry_point in
    `Assoc [
      "thread", Data.Jstring.to_json (thread_label cs.thread);
      "entryPoint", fct_decl entry_point;
      "stack", JStack.to_json ~entry_point (List.rev cs.stack);
      "analyzed", Data.Jbool.to_json (analyzed cs);
    ]
end

(* -------------------------------------------------------------------------- *)
(* ----- Requests                                                       ----- *)
(* -------------------------------------------------------------------------- *)

module JCallstack : Data.S with type t = Callstack.t =
  Data.Index
    (Callstack.Map)
    (struct
      let package = package
      let name = "callstack"
      let descr = Markdown.plain "Callstack identifier"
    end)

let () =
  Request.register
    ~package ~kind:`GET
    ~name:"getCallstackInfo"
    ~descr:(Markdown.plain "Callstack Description")
    ~signals:[Update.computation_signal]
    ~input:(module JCallstack)
    ~output:(module JCallstackData)
    (fun cs -> cs)

(* Registers a request returning a sorted list of callstacks. *)
let register_list_request ~descr f =
  Request.register ~package ~kind:`GET
    ~descr:(Markdown.plain descr)
    ~signals:[Update.computation_signal]
    ~output:(module Data.Jlist (JCallstack))
    (fun elt -> f elt |> sort_callstacks)

let all_callstacks () =
  let aux kf acc =
    if Results.is_called kf
    then Results.(at_start_of kf |> callstacks) @ acc
    else acc
  in
  Globals.Functions.fold aux []

let () =
  register_list_request
    ~name:"getAllCallstacks"
    ~descr:"Returns the list of all callstacks analyzed"
    ~input:(module Data.Junit)
    all_callstacks

let fct_callstacks = function
  | Printer_tag.SFunction kf -> Results.(at_start_of kf |> callstacks)
  | _ -> []

let () =
  register_list_request
    ~name:"getFunctionCallstacks"
    ~descr:"Returns the list of all callstacks analyzed for a given function"
    ~input:(module Kernel_ast.Decl)
    fct_callstacks

let marker_callstacks marker =
  match Printer_tag.ki_of_localizable marker with
  | Kstmt stmt -> Results.(before stmt |> callstacks)
  | Kglobal ->
    match Printer_tag.kf_of_localizable marker with
    | Some kf -> Results.(at_start_of kf |> callstacks)
    | None -> []

let markers_callstacks markers =
  let aux acc marker =
    marker_callstacks marker |> Callstack.Set.of_list |> Callstack.Set.union acc
  in
  let callstack_set = List.fold_left aux Callstack.Set.empty markers in
  let callstack_list = Callstack.Set.elements callstack_set in
  match compatible_filter () with
  | None -> callstack_list
  | Some filter -> List.filter filter callstack_list

let () =
  register_list_request
    ~name:"getMarkersCallstacks"
    ~descr:"Return the list of all callstacks analyzed for"
    ~input:(module Data.Jlist (Kernel_ast.Marker))
    markers_callstacks

(* -------------------------------------------------------------------------- *)
(* ----- Current callstacks                                             ----- *)
(* -------------------------------------------------------------------------- *)

let _current_callstack_signal =
  States.register_framac_state ~package
    ~name:"currentCallstacks"
    ~descr:(Markdown.plain "List of the currently selected callstacks, if any")
    ~data:(Data.jlist (module JCallstack))
    (module Update.CurrentCallstacks)
