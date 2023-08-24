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

open Eval
open MtUtils
open Eva_ast
open Locations
open Concurency



module BuiltinsResults = struct
  module Info = struct
    let initial_values = [ ]
    let dependencies = [ Ast.self ]
  end
  include Hptmap.Make (Cil_datatype.Varinfo_Id) (Value) (Info)
  let cache_name s = Hptmap_sig.PersistentCache (name ^ "." ^ s)

  let top = empty

  let is_included =
    let cache = cache_name "is_included" in
    let decide_fst _b _l = true  (* r is top *) in
    let decide_snd _b _r = false (* l is top *) in
    let decide_both _ l r = Value.is_included l r in
    let decide_fast s t = if s == t then PTrue else PUnknown in
    binary_predicate cache UniversalPredicate
      ~decide_fast ~decide_fst ~decide_snd ~decide_both

  let narrow =
    let cache = cache_name "narrow" in
    let decide _ = Value.narrow in
    join ~cache ~symmetric:true ~idempotent:true ~decide

  let narrow l r = `Value (narrow l r)

  let join =
    let cache = cache_name "join" in
    let decide _ l r = Some (Value.join l r) in
    inter ~cache ~symmetric:true ~idempotent:true ~decide

  let enter_scope kind vars returns =
    let open Abstract_domain in
    match kind with
    | Global | Formal _ | Local _ -> returns
    | Result _ ->
      let write returns var = add var Value.top returns in
      List.fold_left write returns vars

  let leave_scope _ vars returns =
    let remove returns var = remove var returns in
    List.fold_left remove returns vars

  let write return value returns =
    match return with
    | None -> returns
    | Some var ->
      if mem var returns then add var value returns else returns

  let read var returns =
    try find var returns
    with Not_found -> Value.top
end



type memory = { read : Zone.t ; written : Zone.t }
type return = { standard : Value.t }

module State = struct
  type state =
    { threads : MtThread.Register.t
    ; mutexes : MtMutex.Register.t
    ; memory  : memory
    ; return  : return
    ; results : BuiltinsResults.t
    }

  let default =
    { threads = MtThread.Register.empty
    ; mutexes = MtMutex.Register.empty
    ; memory  = Zone.{ read = bottom ; written = bottom }
    ; return  = Value.{ standard = bottom }
    ; results = BuiltinsResults.empty
    }

  let top =
    { threads = MtThread.Register.top
    ; mutexes = MtMutex.Register.top
    ; memory  = Zone.{ read = top ; written = top }
    ; return  = Value.{ standard = top }
    ; results = BuiltinsResults.top
    }

  include Datatype.Make_with_collections (struct
      type t = state
      let name = "Mthread.state"
      let reprs = [ default ; top ]

      let copy state =
        let threads  = MtThread.Register.copy state.threads in
        let mutexes  = MtMutex.Register.copy state.mutexes in
        let written  = Zone.copy state.memory.written in
        let read     = Zone.copy state.memory.read in
        let memory   = { read ; written } in
        let standard = Value.copy state.return.standard in
        let return   = { standard } in
        let results  = BuiltinsResults.copy state.results in
        { threads ; mutexes ; memory ; return ; results }

      let structural_descr =
        let open Structural_descr in
        let ths = MtThread.Register.packed_descr in
        let mxs = MtMutex.Register.packed_descr in
        let mem = pack (t_record Zone.[| packed_descr ; packed_descr |]) in
        let ret = pack (t_record Value.[| packed_descr |]) in
        let results = BuiltinsResults.packed_descr in
        t_record [| ths ; mxs ; mem ; ret ; results |]

      let pretty fmt state =
        Format.fprintf fmt "Threads :@.  @[<v>%a@]@."
          MtThread.Register.pretty state.threads ;
        Format.fprintf fmt "Mutexes :@.  @[<v>%a@]@."
          MtMutex.Register.pretty state.mutexes ;
        Format.fprintf fmt "Memory  :@.  Read    : %a@.  Written : %a@."
          Zone.pretty state.memory.read Zone.pretty state.memory.written ;
        Format.fprintf fmt "Return  :@.  Standard : %a@."
          Value.pretty state.return.standard

      let compare_memory l r =
        let open Locations.Zone in
        compare l.read r.read <?> lazy (compare l.written r.written)

      let compare_return l r =
        let open Value in
        compare l.standard r.standard

      let compare l r =
        MtThread.Register.compare l.threads r.threads
        <?> lazy (MtMutex.Register.compare l.mutexes r.mutexes)
        <?> lazy (compare_memory l.memory r.memory)
        <?> lazy (compare_return l.return r.return)
        <?> lazy (BuiltinsResults.compare l.results r.results)

      let equal l r = compare l r = 0

      let hash_memory t =
        Hashtbl.hash (Locations.Zone.hash t.read, Locations.Zone.hash t.written)

      let hash_return t =
        Value.hash t.standard

      let hash t =
        Hashtbl.hash (
          MtThread.Register.hash t.threads,
          MtMutex.Register.hash t.mutexes,
          hash_memory t.memory,
          hash_return t.return,
          BuiltinsResults.hash t.results)
      let rehash = Datatype.identity
      let mem_project = Datatype.never_any_project
    end)

  let threads t = t.threads
  let mutexes t = t.mutexes
  let memory t = t.memory
  let return t = t.return
end



let reset state =
  let open State in
  let memory = Zone.{ read = bottom ; written = bottom } in
  let return = { standard = Value.bottom } in
  { state with memory ; return }



module Datatype_with_Lattice = struct
  include State

  let is_included l r =
    MtThread.Register.is_included l.threads r.threads
    && MtMutex.Register.is_included l.mutexes r.mutexes
    && Zone.is_included l.memory.read r.memory.read
    && Zone.is_included l.memory.written r.memory.written
    && Value.is_included l.return.standard r.return.standard
    && BuiltinsResults.is_included l.results r.results

  let join l r =
    let threads = MtThread.Register.join l.threads r.threads in
    let mutexes = MtMutex.Register.join l.mutexes r.mutexes in
    let read = Zone.join l.memory.read r.memory.read in
    let written = Zone.join l.memory.written r.memory.written in
    let memory = { read ; written } in
    let standard = Value.join l.return.standard r.return.standard in
    let return = { standard } in
    let results = BuiltinsResults.join l.results r.results in
    { threads ; mutexes ; memory ; return ; results }

  let widen _ _ pre post =
    let threads = MtThread.Register.join pre.threads post.threads in
    let mutexes = MtMutex.Register.join pre.mutexes post.mutexes in
    let read = Locations.Zone.join pre.memory.read post.memory.read in
    let written = Locations.Zone.join pre.memory.written post.memory.written in
    let memory = { read ; written } in
    let standard = Value.widen pre.return.standard post.return.standard in
    let return = { standard } in
    let results = BuiltinsResults.join pre.results post.results in
    { threads ; mutexes ; memory ; return ; results }

  let narrow l r =
    let open Lattice_bounds.Bottom.Operators in
    let threads = MtThread.Register.narrow l.threads r.threads in
    let mutexes = MtMutex.Register.narrow l.mutexes r.mutexes in
    let read = Zone.narrow l.memory.read r.memory.read in
    let written = Zone.narrow l.memory.written r.memory.written in
    let memory = { read ; written } in
    let standard = Value.narrow l.return.standard r.return.standard in
    let return = { standard } in
    let+ results = BuiltinsResults.narrow l.results r.results in
    { threads ; mutexes ; memory ; return ; results }
end



module Cache = struct
  open Datatype_with_Lattice
  include Cil_datatype.Stmt.Hashtbl
  let cache : State.t t = create 17
  let copy () = copy cache
  let reset () = reset cache
  let merge l r =
    let threads = MtThread.Register.narrow l.threads r.threads in
    let mutexes = MtMutex.Register.narrow l.mutexes r.mutexes in
    let read = Zone.join l.memory.read r.memory.read in
    let written = Zone.join l.memory.written r.memory.written in
    let memory = { read ; written } in
    let standard = Value.join l.return.standard r.return.standard in
    let return = { standard } in
    let results = BuiltinsResults.join l.results r.results in
    { threads ; mutexes ; memory ; return ; results }
  let add stmt state =
    match find_opt cache stmt with
    | None -> add cache stmt state
    | Some state' -> replace cache stmt (merge state state')
  let save stmt state = add stmt state ; `Value state
end



module Queries = struct
  let extract_expr ~oracle:_ _ _ _ = `Value (Value.top, None), Alarmset.all
  let extract_lval ~oracle:_ _ state lval _ =
    let State.{ results } = state in
    let value =
      match lval.node with
      | Var var, NoOffset -> BuiltinsResults.read var results
      | _ -> Value.top
    in
    `Value (value, None), Alarmset.all
end



module Transfer = struct
  open State

  module Builtins = Datatype.String.Hashtbl
  type builtin =
    t -> Cil_types.stmt -> (Value.t * exp) list -> (t * Value.t) Result.t
  let builtins : builtin Builtins.t = Builtins.create 17
  let find_builtin name = Builtins.find_opt builtins name
  let add_builtin name f = Builtins.add builtins name f

  let update _ state = `Value state

  let loc_of_lval valuation lv =
    match valuation.Abstract_domain.find_loc lv with
    | `Value loc -> loc.loc
    | `Top -> Precise_locs.loc_top

  (* Internal function filtering a zone to only keep global bases. *)
  let keep_globals_only zone =
    let test f v = Option.(map f v |> value ~default:false) in
    let volatile b =
      Base.typeof b
      |> test (Ast_types.has_qualifier "volatile")
    in
    let keep b = Base.is_global b && not (volatile b) in
    try Locations.Zone.filter_base keep zone
    with Abstract_interp.Error_Top -> Locations.Zone.top

  (* Internal function computing written and indirectly read zones of a
     lvalue. *)
  let compute_zones lval to_loc =
    match lval.node with
    | Var vi, NoOffset ->
      Locations.(zone_of_varinfo vi |> keep_globals_only, Zone.bottom)
    | _ ->
      let ploc = to_loc lval in
      let loc = Precise_locs.imprecise_location ploc in
      let lv_zone = Locations.(enumerate_valid_bits Write loc) in
      let lv_indirect_zone = Eva_ast.indirect_zone_of_lval to_loc lval in
      keep_globals_only lv_zone, keep_globals_only lv_indirect_zone

  let assign_memory lval exp valuation memory =
    let to_loc = loc_of_lval valuation in
    let written_zone, lv_indirect_zone = compute_zones lval to_loc in
    let exp_zone = Eva_ast.zone_of_exp to_loc exp |> keep_globals_only in
    let read_zone = Locations.Zone.join lv_indirect_zone exp_zone in
    let read = Locations.Zone.join memory.read read_zone in
    let written = Locations.Zone.join memory.written written_zone in
    { read ; written }

  let assign_return lval result return =
    let main_return = MtThread.return_lval (Thread.current ()) in
    if Option.equal Eva_ast.Lval.equal main_return (Some lval) then
      let bottom = Value.{ standard = bottom } in
      let f value = { standard = value } in
      Bottom.(map f result |> value ~bottom)
    else return

  let assign kinstr { lval } exp assigned valuation state =
    match kinstr with
    | Cil_types.Kglobal -> `Value state
    | Kstmt stmt ->
      let { memory ; return } = reset state in
      let return = assign_return lval (Eval.value_assigned assigned) return in
      let memory = assign_memory lval exp valuation memory in
      let state = { state with memory ; return } in
      Cache.save stmt state

  let assume stmt exp _ valuation state =
    let to_loc = loc_of_lval valuation in
    let { memory } = reset state in
    let read_zone = Eva_ast.zone_of_exp to_loc exp |> keep_globals_only in
    let read = Locations.Zone.join memory.read read_zone in
    let state = { state with memory = { memory with read } } in
    Cache.save stmt state

  let start_call stmt call _ valuation state =
    let { memory } = reset state in
    let var = Eva_ast.Build.var in
    let assign varinfo exp = assign_memory (var varinfo) exp valuation in
    let f s { formal ; concrete } = assign formal concrete s in
    let memory = List.fold_left f memory call.arguments in
    let state = { state with memory } in
    Cache.save stmt state

  let map_non_bottom f xs =
    let module E = struct exception Bottom end in
    let f v = match f v with `Value v -> v | `Bottom -> raise E.Bottom in
    try `Value (List.map f xs) with E.Bottom -> `Bottom

  let finalize_call stmt call _ ~pre:_ ~post =
    let name = Kernel_function.get_name call.kf in
    match find_builtin name with
    | None -> Cache.save stmt post
    | Some f ->
      let open Lattice_bounds.Bottom.Operators in
      let extract_arg arg = arg.concrete, arg.avalue in
      let arguments = List.map extract_arg call.arguments @ call.rest in
      let extract (exp, v) = Eval.value_assigned v >>-: fun v -> v, exp in
      let* params = map_non_bottom extract arguments in
      let error = (post, Value.top) in
      let (state, ret) = f post stmt params |> Result.log ~error in
      let results = BuiltinsResults.write call.return ret state.results in
      { state with results } |> Cache.save stmt

end



module Domain = struct
  type value = Value.t
  type location = Precise_locs.precise_location
  type origin = unit

  include Datatype_with_Lattice
  include Queries
  include Transfer
  include Domain_builder.Complete (Datatype_with_Lattice)

  let value_dependencies = Main_values.cval
  let location_dependencies = Main_locations.ploc

  let create_main_thread state =
    let open Result in
    let threads = state.threads in
    let* (threads, r) = MtThread.Register.register [Thread.main] threads in
    let+ (threads, _) = MtThread.Register.start r threads in
    { state with threads }

  let empty () =
    let state = default in
    create_main_thread state |> Result.log ~error:state
  let logic_assign _ _ state = state
  let initialize_variable _ _ ~initialized:_ _ state = state
  let initialize_variable_using_type _ _ state  = state
  let relate _ _ _ = Base.SetLattice.empty
  let log_category = Self.register_category "d-mthread"

  let post_analysis _ =
    let pp stmt state =
      Self.debug ~dkey:log_category
        "At statement %a@.  @[%a@]@."
        Cil_datatype.Stmt.pretty stmt
        State.pretty state
    in
    Cache.iter pp Cache.cache

  let enter_scope kind vars state =
    let state = reset state in
    let results = BuiltinsResults.enter_scope kind vars state.results in
    { state with results }

  let leave_scope kf vars state =
    let state = reset state in
    let results = BuiltinsResults.leave_scope kf vars state.results in
    { state with results }

  let thread_create state stmt = function
    | (name, _) :: (func, _) :: args ->
      let open Result in
      let name = Name.of_cvalue name in
      let* func = Value.extract_fun func in
      let args = List.map fst args in
      let aloc = (stmt, Eva_utils.current_call_stack ()) in
      let th_list = Thread.spawn aloc name func args in
      let+ threads, return = MtThread.Register.register th_list state.threads in
      { state with threads }, return
    | _ -> Result.error "Invalid parameters@."

  let thread_update f state _ = function
    | (id, _) :: [] ->
      let open Result in
      let+ (threads, return) = f id state.threads in
      { state with threads }, return
    | _ -> Result.error "Invalid parameters@."

  let thread_start   = thread_update MtThread.Register.start
  let thread_suspend = thread_update MtThread.Register.suspend
  let thread_cancel  = thread_update MtThread.Register.cancel

  let thread_id state _ = function
    | [] -> Result.ok (state, Thread.current () |> Thread.id |> Value.of_int)
    | _ -> Result.error "Invalid parameters@."

  let mutex_init state stmt = function
    | (name, _) :: [] ->
      let open Result in
      let name = Name.of_cvalue name in
      let aloc = (stmt, Eva_utils.current_call_stack ()) in
      let mutex = Mutex.create aloc name in
      let+ (mutexes, return) = MtMutex.Register.register [mutex] state.mutexes in
      { state with mutexes }, return
    | _ -> Result.error "Invalid parameters@."

  let mutex_lock state _ = function
    | (id, _) :: [] ->
      let open Result in
      let+ (mutexes, return) = MtMutex.Register.lock id state.mutexes in
      { state with mutexes }, return
    | _ -> Result.error "Invalid parameters@."

  let mutex_unlock state _ = function
    | (id, _) :: [] ->
      let open Result in
      let+ (mutexes, return) = MtMutex.Register.unlock id state.mutexes in
      { state with mutexes }, return
    | _ -> Result.error "Invalid parameters@."

  let () = add_builtin "__FRAMAC_THREAD_CREATE" thread_create
  let () = add_builtin "__FRAMAC_THREAD_START" thread_start
  let () = add_builtin "__FRAMAC_THREAD_SUSPEND" thread_suspend
  let () = add_builtin "__FRAMAC_THREAD_CANCEL" thread_cancel
  let () = add_builtin "__FRAMAC_THREAD_ID" thread_id
  let () = add_builtin "__FRAMAC_MUTEX_INIT" mutex_init
  let () = add_builtin "__FRAMAC_MUTEX_LOCK" mutex_lock
  let () = add_builtin "__FRAMAC_MUTEX_UNLOCK" mutex_unlock
end

let domain =
  let name = "mthread" in
  let descr = "Mthread domain" in
  let experimental = true in
  Abstractions.Domain.register ~name ~descr ~experimental (module Domain)
