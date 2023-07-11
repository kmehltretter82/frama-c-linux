(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Cil_types
open Cil_datatype
open Extlib

let register r f = r := f

let register_compute name deps r f =
  let name = "!Db." ^ name in
  let compute, self = State_builder.apply_once name deps f in
  r := compute;
  self

let register_guarded_compute is_computed r f =
  let compute () = if not (is_computed ()) then f () in
  r := compute

module Main = struct
  include Hook.Make(struct end)
  let play = mk_fun "Main.play"
end

module Toplevel = struct

  let run = ref (fun f -> f ())

end

(* ************************************************************************* *)
(** {2 Inouts} *)
(* ************************************************************************* *)

module type INOUTKF = sig
  type t
  val self_internal: State.t ref
  val self_external: State.t ref
  val compute : (kernel_function -> unit) ref

  val get_internal : (kernel_function -> t) ref
  val get_external : (kernel_function -> t) ref

  val display : (Format.formatter -> kernel_function -> unit) ref
  val pretty : Format.formatter -> t -> unit
end
module type INOUT = sig
  include INOUTKF
  val statement : (stmt -> t) ref
  val kinstr : kinstr -> t option
end

(** State_builder.of outputs
    - over-approximation of zones written by each function. *)
module Outputs = struct
  type t = Locations.Zone.t
  let self_internal = ref State.dummy
  let self_external = ref State.dummy
  let compute = mk_fun "Out.compute"
  let display = mk_fun "Out.display"
  let display_external = mk_fun "Out.display_external"
  let get_internal = mk_fun "Out.get_internal"
  let get_external = mk_fun "Out.get_external"
  let statement = mk_fun "Out.statement"
  let kinstr ki = match ki with
    | Kstmt s -> Some (!statement s)
    | Kglobal -> None

  let pretty = Locations.Zone.pretty
end

(** State_builder.of read inputs
    - over-approximation of locations read by each function. *)
module Inputs = struct
  (*       What about [Inputs.statement] ? *)
  type t = Locations.Zone.t
  let self_internal = ref State.dummy
  let self_external = ref State.dummy
  let self_with_formals = ref State.dummy
  let compute = mk_fun "Inputs.compute"
  let display = mk_fun "Inputs.display"
  let display_with_formals = mk_fun "Inputs.display_with_formals"
  let get_internal = mk_fun "Inputs.get_internal"
  let get_external = mk_fun "Inputs.get_external"
  let get_with_formals = mk_fun "Inputs.get_with_formals"
  let statement = mk_fun "Inputs.statement"
  let expr = mk_fun "Inputs.expr"
  let kinstr ki = match ki with
    | Kstmt s -> Some (!statement s)
    | Kglobal -> None

  let pretty = Locations.Zone.pretty
end

(** State_builder.of operational inputs
    - over-approximation of zones whose input values are read by each function,
      State_builder.of sure outputs
    - under-approximation of zones written by each function. *)
module Operational_inputs = struct
  type t = Inout_type.t
  let self_internal = ref State.dummy
  let self_external = ref State.dummy
  let compute = mk_fun "Operational_inputs.compute"
  let display = mk_fun "Operational_inputs.display"
  let get_internal = mk_fun "Operational_inputs.get_internal"
  let get_internal_precise = ref (fun ?stmt:_ _ ->
      failwith ("Db.Operational_inputs.get_internal_precise not implemented"))
  let get_external = mk_fun "Operational_inputs.get_external"

  module Record_Inout_Callbacks =
    Hook.Build (struct type t = Eva_types.Callstack.t * Inout_type.t end)
  [@@alert "-db_deprecated"]

  let pretty fmt x =
    Format.fprintf fmt "@[<v>";
    Format.fprintf fmt "@[<v 2>Operational inputs:@ @[<hov>%a@]@]@ "
      Locations.Zone.pretty (x.Inout_type.over_inputs);
    Format.fprintf fmt "@[<v 2>Operational inputs on termination:@ @[<hov>%a@]@]@ "
      Locations.Zone.pretty (x.Inout_type.over_inputs_if_termination);
    Format.fprintf fmt "@[<v 2>Sure outputs:@ @[<hov>%a@]@]"
      Locations.Zone.pretty (x.Inout_type.under_outputs_if_termination);
    Format.fprintf fmt "@]";

end

(** Derefs computations *)
module Derefs = struct
  type t = Locations.Zone.t
  let self_internal = ref State.dummy
  let self_external = ref State.dummy
  let compute = mk_fun "Derefs.compute"
  let display = mk_fun "Derefs.display"
  let get_internal = mk_fun "Derefs.get_internal"
  let get_external = mk_fun "Derefs.get_external"
  let statement = mk_fun "Derefs.statement"
  let kinstr ki = match ki with
    | Kstmt s -> Some (!statement s)
    | Kglobal -> None

  let pretty = Locations.Zone.pretty
end


(* ************************************************************************* *)
(** {2 Values} *)
(* ************************************************************************* *)

module Value = struct
  type state = Cvalue.Model.t
  type t = Cvalue.V.t

  (* This function is responsible for clearing completely Value's state
     when the user-supplied initial state or main arguments are changed.
     It is set deep inside Value  for technical reasons *)
  let initial_state_changed = mk_fun "Value.initial_state_changed"

  (* Arguments of the root function of the value analysis *)
  module ListArgs = Datatype.List(Cvalue.V)
  module FunArgs =
    State_builder.Option_ref
      (ListArgs)
      (struct
        let name = "Db.Value.fun_args"
        let dependencies =
          [ Ast.self; Kernel.LibEntry.self; Kernel.MainFunction.self]
      end)
  let () = Ast.add_monotonic_state FunArgs.self


  exception Incorrect_number_of_arguments

  let fun_get_args () = FunArgs.get_option ()

  let fun_set_args l =
    if not (Option.equal ListArgs.equal (Some l) (FunArgs.get_option ())) then
      (!initial_state_changed (); FunArgs.set l)

  let fun_use_default_args () =
    if FunArgs.get_option () <> None then
      (!initial_state_changed (); FunArgs.clear ())

  (* Initial memory state of the value analysis *)
  module VGlobals =
    State_builder.Option_ref
      (Cvalue.Model)
      (struct
        let name = "Db.Value.Vglobals"
        let dependencies = [Ast.self]
      end)

  let globals_set_initial_state state =
    if not (Option.equal Cvalue.Model.equal
              (Some state)
              (VGlobals.get_option ()))
    then begin
      !initial_state_changed ();
      VGlobals.set state
    end


  let globals_use_default_initial_state () =
    if VGlobals.get_option () <> None then
      (!initial_state_changed (); VGlobals.clear ())

  let initial_state_only_globals = mk_fun "Value.initial_state_only_globals"

  let globals_state () =
    match VGlobals.get_option () with
    | Some v -> v
    | None -> !initial_state_only_globals ()

  let globals_use_supplied_state () = not (VGlobals.get_option () = None)

  let dependencies = [ FunArgs.self; VGlobals.self ]
  let proxy = State_builder.Proxy.(create "eva_db" Forward dependencies)
  let self = State_builder.Proxy.get proxy
  let only_self = [ self ]

  let size = 256

  [@@@ alert "-db_deprecated"]
  type callstack = Eva_types.Callstack.callstack

  module States_by_callstack =
    Eva_types.Callstack.Hashtbl.Make(Cvalue.Model)

  module Table_By_Callstack =
    Cil_state_builder.Stmt_hashtbl(States_by_callstack)
      (struct
        let name = "Db.Value.Table_By_Callstack"
        let size = size
        let dependencies = [ self ]
      end)
  module Table =
    Cil_state_builder.Stmt_hashtbl(Cvalue.Model)
      (struct
        let name = "Db.Value.Table"
        let size = size
        let dependencies = [ self ]
      end)
  (* Clear Value's various caches each time [Db.Value.is_computed] is updated,
     including when it is set, reset, or during project change. Some operations
     of Value depend on -ilevel, -plevel, etc, so clearing those caches when
     Value ends ensures that those options will have an effect between two runs
     of Value. *)
  let () = Table_By_Callstack.add_hook_on_update
      (fun _ ->
         Cvalue.V_Offsetmap.clear_caches ();
         Cvalue.Model.clear_caches ();
         Locations.Location_Bytes.clear_caches ();
         Locations.Zone.clear_caches ();
         Function_Froms.Memory.clear_caches ();
      )

  module AfterTable_By_Callstack =
    Cil_state_builder.Stmt_hashtbl(States_by_callstack)
      (struct
        let name = "Db.Value.AfterTable_By_Callstack"
        let size = size
        let dependencies = [ self ]
      end)
  module AfterTable =
    Cil_state_builder.Stmt_hashtbl(Cvalue.Model)
      (struct
        let name = "Db.Value.AfterTable"
        let size = size
        let dependencies = [ self ]
      end)

  let mark_as_computed () =
    Table_By_Callstack.mark_as_computed ()

  let is_computed () = Table_By_Callstack.is_computed ()

  module Conditions_table =
    Cil_state_builder.Stmt_hashtbl
      (Datatype.Int)
      (struct
        let name = "Db.Value.Conditions_table"
        let size = 101
        let dependencies = only_self
      end)

  let merge_conditions h =
    Cil_datatype.Stmt.Hashtbl.iter
      (fun stmt v ->
         try
           let old = Conditions_table.find stmt in
           Conditions_table.replace stmt (old lor v)
         with Not_found ->
           Conditions_table.add stmt v)
      h

  let mask_then = 1
  let mask_else = 2

  let condition_truth_value s =
    try
      let i = Conditions_table.find s in
      ((i land mask_then) <> 0, (i land mask_else) <> 0)
    with Not_found -> false, false

  module Called_Functions_By_Callstack =
    State_builder.Hashtbl(Kernel_function.Hashtbl)
      (States_by_callstack)
      (struct
        let name = "Db.Value.Called_Functions_By_Callstack"
        let size = 11
        let dependencies = only_self
      end)

  module Called_Functions_Memo =
    State_builder.Hashtbl(Kernel_function.Hashtbl)
      (Cvalue.Model)
      (struct
        let name = "Db.Value.Called_Functions_Memo"
        let size = 11
        let dependencies = [ Called_Functions_By_Callstack.self ]
      end)

(*
  let pretty_table () =
   Table.iter
      (fun k v ->
         Kernel.log ~kind:Log.Debug
           "GLOBAL TABLE at %a: %a@\n"
           Kinstr.pretty k
           Cvalue.Model.pretty v)

  let pretty_table_raw () =
    Kinstr.Hashtbl.iter
      (fun k v ->
         Kernel.log ~kind:Log.Debug
           "GLOBAL TABLE at %a: %a@\n"
           Kinstr.pretty k
           Cvalue.Model.pretty v)
*)

  (* -remove-redundant-alarms feature, applied at the end of an Eva analysis,
     fulfilled by the Scope plugin that also depends on Eva. We thus use a
     reference here to avoid a cyclic dependency. *)
  let rm_asserts = mk_fun "Value.rm_asserts"

  let no_results = mk_fun "Value.no_results"

  let update_callstack_table ~after stmt callstack v =
    let open Eva_types in
    let find,add =
      if after
      then AfterTable_By_Callstack.find, AfterTable_By_Callstack.add
      else Table_By_Callstack.find, Table_By_Callstack.add
    in
    try
      let by_callstack = find stmt in
      begin try
          let o = Callstack.Hashtbl.find by_callstack callstack in
          Callstack.Hashtbl.replace by_callstack callstack(Cvalue.Model.join o v)
        with Not_found ->
          Callstack.Hashtbl.add by_callstack callstack v
      end;
    with Not_found ->
      let r = Callstack.Hashtbl.create 7 in
      Callstack.Hashtbl.add r callstack v;
      add stmt r

  let merge_initial_state cs kf state =
    let open Eva_types in
    let by_callstack =
      try Called_Functions_By_Callstack.find kf
      with Not_found ->
        let h = Callstack.Hashtbl.create 7 in
        Called_Functions_By_Callstack.add kf h;
        h
    in
    try
      let old = Callstack.Hashtbl.find by_callstack cs in
      Callstack.Hashtbl.replace by_callstack cs (Cvalue.Model.join old state)
    with Not_found ->
      Callstack.Hashtbl.add by_callstack cs state

  let get_initial_state kf =
    assert (is_computed ()); (* this assertion fails during Eva analysis *)
    try Called_Functions_Memo.find kf
    with Not_found ->
      let state =
        try
          let open Eva_types in
          let by_callstack = Called_Functions_By_Callstack.find kf in
          Callstack.Hashtbl.fold
            (fun _cs state acc -> Cvalue.Model.join acc state)
            by_callstack Cvalue.Model.bottom
        with Not_found -> Cvalue.Model.bottom
      in
      Called_Functions_Memo.add kf state;
      state

  (* This function is used by the Inout plugin during Eva analysis, so it
     should not fail during Eva analysis, even if results are incomplete. *)
  let get_initial_state_callstack kf =
    try Some (Called_Functions_By_Callstack.find kf)
    with Not_found -> None

  let get_fundec_from_stmt stmt =
    let kf =
      try
        Kernel_function.find_englobing_kf stmt
      with Not_found ->
        Kernel.fatal "Unknown statement '%a'" Printer.pp_stmt stmt
    in
    try
      Kernel_function.get_definition kf
    with Kernel_function.No_Definition ->
      Kernel.fatal "No definition for function %a" Kernel_function.pretty kf

  let noassert_get_stmt_state ~after s =
    if !no_results (get_fundec_from_stmt s)
    then Cvalue.Model.top
    else
      let (find, add), find_by_callstack =
        if after
        then AfterTable.(find, add), AfterTable_By_Callstack.find
        else Table.(find, add), Table_By_Callstack.find
      in
      try find s
      with Not_found ->
        let ho = try Some (find_by_callstack s) with Not_found -> None in
        let state =
          match ho with
          | None -> Cvalue.Model.bottom
          | Some h ->
            Eva_types.Callstack.Hashtbl.fold (fun _cs state acc ->
                Cvalue.Model.join acc state
              ) h Cvalue.Model.bottom
        in
        add s state;
        state

  let noassert_get_state ?(after=false) k =
    match k with
    | Kglobal -> globals_state ()
    | Kstmt s ->
      noassert_get_stmt_state ~after s

  let get_stmt_state ?(after=false) s =
    assert (is_computed ()); (* this assertion fails during Eva analysis *)
    noassert_get_stmt_state ~after s

  let get_state ?(after=false) k =
    assert (is_computed ()); (* this assertion fails during Eva analysis *)
    noassert_get_state ~after k

  let get_stmt_state_callstack ~after stmt =
    assert (is_computed ()); (* this assertion fails during Eva analysis *)
    try
      Some (if after then AfterTable_By_Callstack.find stmt else
              Table_By_Callstack.find stmt)
    with Not_found -> None

  let fold_stmt_state_callstack f acc ~after stmt =
    assert (is_computed ()); (* this assertion fails during Eva analysis *)
    match get_stmt_state_callstack ~after stmt with
    | None -> acc
    | Some h -> Eva_types.Callstack.Hashtbl.fold (fun _ -> f) h acc

  let fold_state_callstack f acc ~after ki =
    assert (is_computed ()); (* this assertion fails during Eva analysis *)
    match ki with
    | Kglobal -> f (globals_state ()) acc
    | Kstmt stmt -> fold_stmt_state_callstack f acc ~after stmt

  let is_reachable = Cvalue.Model.is_reachable

  exception Is_reachable
  let is_reachable_stmt stmt =
    if !no_results (get_fundec_from_stmt stmt)
    then true
    else
      let ho = try Some (Table_By_Callstack.find stmt) with Not_found -> None in
      match ho with
      | None -> false
      | Some h ->
        try
          Eva_types.Callstack.Hashtbl.iter
            (fun _cs state ->
               if Cvalue.Model.is_reachable state
               then raise Is_reachable) h;
          false
        with Is_reachable -> true

  let is_accessible ki =
    match ki with
    | Kglobal -> Cvalue.Model.is_reachable (globals_state ())
    | Kstmt stmt -> is_reachable_stmt stmt

  let is_called = mk_fun "Value.is_called"
  let callers = mk_fun "Value.callers"

  let eval_lval =
    ref (fun ?with_alarms:_ _ -> mk_labeled_fun "Value.eval_lval")
  let eval_expr =
    ref (fun ?with_alarms:_ _ -> mk_labeled_fun "Value.eval_expr")

  let eval_expr_with_state =
    ref (fun ?with_alarms:_ _ -> mk_labeled_fun "Value.eval_expr_with_state")

  let reduce_by_cond = mk_fun "Value.reduce_by_cond"

  let find_lv_plus = mk_fun "Value.find_lv_plus"

  let compute = mk_fun "Value.compute"


  let lval_to_loc_with_deps = mk_fun "Value.lval_to_loc_with_deps"
  let lval_to_loc_with_deps_state = mk_fun "Value.lval_to_loc_with_deps_state"
  let lval_to_loc = mk_fun "Value.lval_to_loc"
  let lval_to_offsetmap = mk_fun "Value.lval_to_offsetmap"
  let lval_to_offsetmap_state = mk_fun "Value.lval_to_offsetmap_state"
  let lval_to_loc_state = mk_fun "Value.lval_to_loc_state"
  let lval_to_zone = mk_fun "Value.lval_to_zone"
  let lval_to_zone_state = mk_fun "Value.lval_to_zone_state"
  let lval_to_zone_with_deps_state = mk_fun "Value.lval_to_zone_with_deps_state"
  let lval_to_precise_loc_state =
    ref (fun ?with_alarms:_ _ -> mk_labeled_fun "Value.lval_to_precise_loc")
  let lval_to_precise_loc_with_deps_state =
    mk_fun "Value.lval_to_precise_loc_with_deps_state"

end

(* ************************************************************************* *)
(** {2 Others plugins} *)
(* ************************************************************************* *)

module Security = struct
  let run_whole_analysis = mk_fun "Security.run_whole_analysis"
  let run_ai_analysis = mk_fun "Security.run_ai_analysis"
  let run_slicing_analysis = mk_fun "Security.run_slicing_analysis"
  let self = ref State.dummy
end

module PostdominatorsTypes = struct
  exception Top

  module type Sig = sig
    val compute: (kernel_function -> unit) ref
    val stmt_postdominators:
      (kernel_function -> stmt -> Stmt.Hptset.t) ref
    val is_postdominator:
      (kernel_function -> opening:stmt -> closing:stmt -> bool) ref
    val display: (unit -> unit) ref
    val print_dot : (string -> kernel_function -> unit) ref
  end
end


module Postdominators = struct
  let compute = mk_fun "Postdominators.compute"
  let is_postdominator
    : (kernel_function -> opening:stmt -> closing:stmt -> bool) ref
    = mk_fun "Postdominators.is_postdominator"
  let stmt_postdominators = mk_fun "Postdominators.stmt_postdominators"
  let display = mk_fun "Postdominators.display"
  let print_dot = mk_fun "Postdominators.print_dot"
end

module PostdominatorsValue = struct
  let compute = mk_fun "PostdominatorsValue.compute"
  let is_postdominator
    : (kernel_function -> opening:stmt -> closing:stmt -> bool) ref
    = mk_fun "PostdominatorsValue.is_postdominator"
  let stmt_postdominators = mk_fun "PostdominatorsValue.stmt_postdominators"
  let display = mk_fun "PostdominatorsValue.display"
  let print_dot = mk_fun "PostdominatorsValue.print_dot"
end

(* ************************************************************************* *)
(** {2 GUI} *)
(* ************************************************************************* *)

type daemon = {
  trigger : unit -> unit ;
  on_delayed : (int -> unit) option ;
  on_finished : (unit -> unit) option ;
  debounced : float ; (* in ms *)
  mutable next_at : float ; (* next trigger time *)
  mutable last_yield_at : float ; (* last yield time *)
}

(* ---- Registry ---- *)

let daemons = ref []

let on_progress ?(debounced=0) ?on_delayed ?on_finished trigger =
  let d = {
    trigger ;
    debounced = float debounced *. 0.001 ;
    on_delayed ;
    on_finished ;
    last_yield_at = 0.0 ;
    next_at = 0.0 ;
  } in
  daemons := List.append !daemons [d] ; d

let off_progress d =
  daemons := List.filter (fun d0 -> d != d0) !daemons ;
  match d.on_finished with
  | None -> ()
  | Some f -> f ()

let while_progress ?debounced ?on_delayed ?on_finished progress =
  let d : daemon option ref = ref None in
  let trigger () =
    if not @@ progress () then
      Option.iter off_progress !d
  in
  d := Some (on_progress ?debounced ?on_delayed ?on_finished trigger)

let with_progress ?debounced ?on_delayed ?on_finished trigger job data =
  let d = on_progress ?debounced ?on_delayed ?on_finished trigger in
  let result =
    try job data
    with exn ->
      off_progress d ;
      raise exn
  in
  off_progress d ; result

(* ---- Canceling ---- *)

exception Cancel

(* ---- Triggering ---- *)

let canceled = ref false
let cancel () = canceled := true

let warn_error exn =
  Kernel.failure
    "Unexpected Db.daemon exception:@\n%s"
    (Printexc.to_string exn)

let fire ~warn_on_delayed ~forced ~time d =
  if forced || time > d.next_at then
    begin
      try
        d.next_at <- time +. d.debounced ;
        d.trigger () ;
      with
      | Cancel -> canceled := true
      | exn -> warn_error exn ; raise exn
    end ;
  match d.on_delayed with
  | None -> ()
  | Some warn ->
    if warn_on_delayed && 0.0 < d.last_yield_at then
      begin
        let time_since_last_yield = time -. d.last_yield_at in
        let delay = if d.debounced > 0.0 then d.debounced else 0.1 in
        if time_since_last_yield > delay then
          warn (int_of_float (time_since_last_yield *. 1000.0)) ;
      end ;
    d.last_yield_at <- time

let raise_if_canceled () =
  if !canceled then ( canceled := false ; raise Cancel )

(* ---- Yielding ---- *)

let do_yield ~warn_on_delayed ~forced () =
  match !daemons with
  | [] -> ()
  | ds ->
    begin
      let time = Unix.gettimeofday () in
      List.iter (fire ~warn_on_delayed ~forced ~time) ds ;
      raise_if_canceled () ;
    end

let yield = do_yield ~warn_on_delayed:true ~forced:false
let flush = do_yield ~warn_on_delayed:false ~forced:true

(* ---- Sleeping ---- *)

let rec gcd a b = if b = 0 then a else gcd b (a mod b)

(* n=0 means no periodic daemons (yet) *)
let merge_period n { debounced = p } =
  if p > 0.0 then gcd (int_of_float (p *. 1000.0)) n else n

let sleep ms =
  if ms > 0 then
    let delta = float ms *. 0.001 in
    let period = List.fold_left merge_period 0 !daemons in
    if period = 0 then
      begin
        Unix.sleepf delta ;
        do_yield ~warn_on_delayed:false ~forced:false ()
      end
    else
      let delay = float period *. 0.001 in
      let finished_at = Unix.gettimeofday () +. delta in
      let rec wait_and_trigger () =
        Unix.sleepf delay ;
        let time = Unix.gettimeofday () in
        List.iter
          (fire ~warn_on_delayed:false ~forced:false ~time)
          !daemons ;
        raise_if_canceled () ;
        if time < finished_at then
          if time +. delay > finished_at then
            Unix.sleepf (finished_at -. time)
          else wait_and_trigger ()
      in
      wait_and_trigger ()

(* ---- Deprecated old API ---- *)

let progress = ref (Kernel.deprecated "!Db.progress()" ~now:"Db.yield()" yield)

(* ************************************************************************* *)

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
