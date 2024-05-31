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
open Abstract_interp
open Locations
open Cvalue
open Lattice_bounds

let dkey = Self.register_category "malloc"

let wkey_weak_alloc = Self.register_warn_category "malloc:weak"
let () = Self.set_warn_status wkey_weak_alloc Log.Winactive

let wkey_imprecise_alloc = Self.register_warn_category
    "malloc:imprecise"

(* Allocation sites are the keys used to partition the sets allocated bases *)
module AllocSite = struct
  include Callstack
end

(* Call sites are the statements used in the callstack *)
module CallSite = struct 
  include Cil_datatype.Stmt
end

(* ---------------------- Dynamically allocated bases ----------------------- *)

module Base_hptmap = Hptmap.Make
    (Base.Base)
    (AllocSite)
    (Hptmap.Comp_unused)
    (struct let v = [ [ ] ] end)
    (struct let l = [ Ast.self ] end)

module Dynamic_Alloc_Bases =
  State_builder.Ref
    (Base_hptmap)
    (struct
      let dependencies = [Ast.self] (* TODO: should probably depend on Value
                                       itself *)
      let name = "Value.Builtins_malloc.Dynamic_Alloc_Bases"
      let default () = Base_hptmap.empty
    end)
let () = Ast.add_monotonic_state Dynamic_Alloc_Bases.self

(* 
We save a pair of sets of bases for each function:
  - the first set contains the bases that are currently allocated for the analyzed function, it is erased at the end of the function
  - the second set contains all the bases that have been allocated in the analyzed function, it is kept for the whole analysis   
*)
module Kf_Alloc_Bases = struct
  include Cil_state_builder.Kernel_function_hashtbl
      (Datatype.Pair (Base.Hptset) (Base.Hptset))
      (struct
        let size = 97
        let name = "Value.Builtins_malloc.Kf_Alloc_Bases"
        let dependencies = [ Ast.self ]
      end)

  let get_cur_alloc_bases kf =
    let (b, _) = try find kf
      with Not_found -> (Base.Hptset.empty, Base.Hptset.empty) in
    b

  let get_all_alloc_bases kf =
    let (_, b') = try find kf
      with Not_found -> (Base.Hptset.empty, Base.Hptset.empty) in
    b'

  let clear_cur_alloc_bases kf =
    match find_opt kf with
    | None -> ()
    | Some (_, b') -> replace kf (Base.Hptset.empty, b')

  let update_alloc_bases kf base =
    let (b, b') = try find kf
      with Not_found -> (Base.Hptset.empty, Base.Hptset.empty) in
    replace kf (Base.Hptset.add base b, Base.Hptset.add base b')

end
let () = Ast.add_monotonic_state Kf_Alloc_Bases.self


(* We save a set of call site for each function
   - They are used to keep track of the call sites where the malloc function is called   
*)
module Kf_Call_Sites =
  Cil_state_builder.Kernel_function_hashtbl
    (Cil_datatype.Stmt.Set)
    (struct
      let size = 97
      let name = "Value.Builtins_malloc.Kf_Call_Sites"
      let dependencies = [ Ast.self ]
    end)
let () = Ast.add_monotonic_state Kf_Call_Sites.self


(* We save a set of alloc sites for each function
   - They are used to keep track of the alloc sites where the malloc function is called
*)
module Kf_Alloc_Sites =
  Cil_state_builder.Kernel_function_hashtbl
    (AllocSite.Set)
    (struct
      let size = 97
      let name = "Value.Builtins_malloc.Kf_Alloc_Sites"
      let dependencies = [ Ast.self ]
    end)
let () = Ast.add_monotonic_state Kf_Alloc_Sites.self

(* -------------------------- Auxiliary functions  -------------------------- *)

let current_call_site () =
  match Callstack.top_callsite (Eva_utils.current_call_stack ()) with
  | Kglobal -> Cil.dummyStmt
  | Kstmt stmt -> stmt

(* Remove some parts of the callstack:
   - Remove the bottom of the call tree until we get to the call site
     of the call to the first malloc function. The idea is that each of
     these call site correspond to a different use of a malloc function,
     so it is interesting to keep their bases separated. *)
let call_stack_no_wrappers () =
  let cs = Eva_utils.current_call_stack () in
  let wrappers = Parameters.AllocFunctions.get () in
  let rec bottom_filter = function
    | [] | [_] as stack -> stack
    | (kf,_)::((kf', _):: _ as rest) as stack ->
      if Datatype.String.Set.mem (Kernel_function.get_name kf) wrappers
      && Datatype.String.Set.mem (Kernel_function.get_name kf') wrappers
      then bottom_filter rest
      else stack
  in
  { cs with stack = bottom_filter cs.stack }

(* Our current allocation site key is the callstack of the call to malloc
   - We can remove the stmts from the callstack to be able to import more allocation sites when the stmts have changed inside the function   
*)
let get_allocation_site_key () = 
  let remove_stmt_from_callstack (cs: Callstack.t) =
    let map (kf, _stmt) = (kf, Cil.dummyStmt) in
    { cs with stack = List.map map cs.stack }
  in
  let cs = call_stack_no_wrappers () in
  match Parameters.CallstackNoStmt.get () with
  | true -> 
    Self.warning ~once:true
      "Using callstack without stmts for allocation site partitionning";
    remove_stmt_from_callstack cs
  | false -> cs

let register_malloced_base ~stack b =
  let stack_without_top =
    Option.value ~default:stack (Callstack.pop stack)
  in
  Dynamic_Alloc_Bases.set
    (Base_hptmap.add b stack_without_top (Dynamic_Alloc_Bases.get ()))

(* Update all functions in callstack to keep track of new allocation informations 
   - Add generated base, alloc_key (callstack) and alloc_key_without_top (callstack without top) to all functions in callstack 
*)
let update_kf_malloced_base (alloc_key: AllocSite.t) (base: Base.t) = 
  let cs = Eva_utils.current_call_stack () in
  (* We intend to use it at callsite, not inside the function *)
  let stmt_list = Callstack.to_stmt_list cs in
  let kf_list = Callstack.to_kf_list cs in
  let call_list = List.map (fun stmt -> 
      let kf = Kernel_function.find_englobing_kf stmt in
      (kf, stmt)) stmt_list in
  let alloc_key_without_top =
    Option.value ~default:alloc_key (Callstack.pop alloc_key)
  in
  begin
    List.iter (fun kf ->
        (* Add base to all kfs *)
        let _ = Kf_Alloc_Bases.update_alloc_bases kf base in
        let call_sites = 
          try 
            Kf_Alloc_Sites.find kf 
          with Not_found -> 
            AllocSite.Set.empty in
        (* Add alloc key to all kfs .... For MallocedByStack *)
        let call_sites = AllocSite.Set.add alloc_key call_sites in
        (* Add alloc key without top to all kfs .... For Dynamic_Alloc_Bases*) 
        let call_sites = AllocSite.Set.add alloc_key_without_top call_sites in
        Kf_Alloc_Sites.replace kf call_sites) kf_list;

    (* Add call_sites to all kfs *)
    List.iter (fun (kf, stmt) -> 
        let stmt_set = try Kf_Call_Sites.find kf 
          with Not_found -> CallSite.Set.empty in
        let stmt_set = CallSite.Set.add stmt stmt_set in
        Kf_Call_Sites.replace kf stmt_set) call_list;
  end

let fold_dynamic_bases (f: Base.t -> Callstack.t -> 'a -> 'a) init =
  Base_hptmap.fold f (Dynamic_Alloc_Bases.get ()) init

let is_automatically_deallocated base =
  match base with
  | Base.Allocated (_, (Base.Alloca | Base.VLA), _) -> true
  | Base.Allocated (_, Base.Malloc, _)
  | Base.Var _
  | Base.CLogic_Var _
  | Base.Null
  | Base.String _ -> false

(* Extracts the minimum/maximum sizes (in bytes) for malloc/realloc/calloc,
   respecting the bounds of size_t.
   Note that the value returned for maximum size corresponds to one past
   the last valid index. *)
let extract_size sizev_bytes =
  let max = Bit_utils.max_byte_size () in
  try
    let sizei_bytes = Cvalue.V.project_ival sizev_bytes in
    begin match Ival.min_and_max sizei_bytes with
      | Some smin, Some smax ->
        assert (Integer.(ge smin zero));
        smin, Integer.min smax max
      | _ -> assert false (* Cil invariant: cast to size_t *)
    end
  with V.Not_based_on_null -> (* size is a garbled mix *)
    Integer.zero, max

(* Name of the base that will be given to a malloced variable, determined
   using the callstack. *)
let base_name prefix cs =
  let stmt_line stmt = (fst (Cil_datatype.Stmt.loc stmt)).Filepath.pos_lnum in
  match cs.Callstack.stack with
  | [] ->
    (* Degenerate case *)
    Format.asprintf "__%s_%a" prefix Kernel_function.pretty cs.entry_point
  | (_, callsite) :: qstack ->
    (* Use the whole call-stack to generate the name *)
    let rec loop_full = function
      | [] -> Format.sprintf "_%s" (Kernel_function.get_name cs.entry_point)
      | (kf, line) :: b ->
        let line = stmt_line line in
        let node_str = Format.asprintf "_l%d__%a"
            line Kernel_function.pretty kf
        in
        (loop_full b) ^ node_str
    in
    (* Use only the name of the caller to malloc for the name *)
    let caller =
      let kf = Callstack.top_kf { cs with stack = qstack } in
      Format.asprintf "_%a" Kernel_function.pretty kf
    in
    let full_name = false in
    Format.asprintf "__%s%s_l%d"
      prefix
      (if full_name then loop_full qstack else caller)
      (stmt_line callsite)

type var = Weak | Strong

let create_new_variable_name stack prefix weak =
  let prefix = match weak with
    | Weak -> prefix ^ "_w"
    | Strong -> prefix
  in
  Cabs2cil.fresh_global (base_name prefix stack)

(* This function adds a "_w" information to a variable. It should be used
   when a variable becomes weak, and supposes that the variable has been
   created by one of the functions of this module. Mutating variables name
   is not a good idea in general, but we take the risk here. *)
let mutate_name_to_weak vi =
  Self.warning ~wkey:wkey_weak_alloc ~current:true ~once:false
    "@[marking variable `%s' as weak@]%t" vi.vname
    Eva_utils.pp_callstack;
  try
    let prefix, remainder =
      Scanf.sscanf vi.vname "__%s@_%s" (fun s1 s2 -> (s1, s2))
    in
    let name' = Printf.sprintf "__%s_w_%s" prefix remainder in
    vi.vname <- name'
  with End_of_file | Scanf.Scan_failure _ -> ()

(* This type represents the size requested to malloc/realloc and co. *)
type typed_size = {
  min_bytes: Integer.t (* minimum size requested, in bytes *);
  max_bytes: Integer.t (* maximum size requested, in bytes *);
  elem_typ: typ (* "guessed type" for the elements of the new variable *);
  nb_elems: Integer.t option (* number of elements of size [sizeof(elem_typ)].
                                None if [min<>max] *);
}

(* Guess the intended type for the cell returned by malloc, given [sizev ==
   [size_min .. size_max] (in bytes). We look for [T *v = malloc(foo)], then
   check that [size_min] and [size_max] are multiples of [sizeof(T)].
   Note that [sizeof(T)] can be zero (e.g. an empty struct).
   If no information can be found, we use char for the base type. If the size
   cannot change later ([constant_size]), we also compute the number of
   elements that are allocated. *)
(* TODO: this is not perfect because we can have an overflow in computations
   such as [foo * t = malloc (i * sizeof(foo))] *)
let guess_intended_malloc_type stack sizev constant_size =
  let size_min, size_max = extract_size sizev in
  let nb_elems elem_size =
    if constant_size && Int.equal size_min size_max
    then Some (if Int.(equal elem_size zero) then Int.zero
               else Int.e_div size_min elem_size)
    else None
  in
  let mk_typed_size t =
    match Cil.unrollType t with
    | TPtr (t, _) when not (Cil.isVoidType t) ->
      let s = Int.of_int (Cil.bytesSizeOf t) in
      if Int.(equal s zero) ||
         (Int.equal (Int.e_rem size_min s) Int.zero &&
          Int.equal (Int.e_rem size_max s) Int.zero)
      then
        { min_bytes = size_min; max_bytes = size_max;
          elem_typ = t; nb_elems = nb_elems s }
      else raise Exit
    | _ -> raise Exit
  in
  try
    match Callstack.top_callsite stack with
    | Kstmt {skind = Instr (Call (Some lv, _, _, _))} ->
      mk_typed_size (Cil.typeOfLval lv)
    | Kstmt {skind = Instr(Local_init(vi, _, _))} -> mk_typed_size vi.vtype
    | _ -> raise Exit
  with Exit | Cil.SizeOfError _ -> (* Default, use char *)
    { min_bytes = size_min; max_bytes = size_max; elem_typ = Cil.charType;
      nb_elems = nb_elems Int.one }

(* Helper function to create the best type for a new base.  Builds an
   array type with the appropriate number of elements if needed.  When
   the number of elements cannot be determined, build an array with
   imprecise size. This is not a problem in practice, because in C you
   annot obtain the size of an allocated block, and \block_length
   handles Allocated variables through their validity. *)
let type_from_nb_elems tsize =
  let typ = tsize.elem_typ in
  match tsize.nb_elems with
  | None -> TArray (typ, None, [])
  | Some nb ->
    if Int.equal Int.one nb
    then typ
    else
      let loc = Current_loc.get () in
      let esize_arr = Cil.kinteger64 ~loc nb in (* [nb] fits in size_t *)
      TArray (typ, Some esize_arr, [])

(* Generalize a type into an array type without size. Useful for variables
   whose size is mutated. *)
let weaken_type typ =
  match Cil.unrollType typ with
  | TArray (_, None, _) -> typ
  | TArray (typ, Some _, _) | typ ->
    TArray (typ, None, [])

(* size for which the base is certain to be valid *)
let size_sure_valid b = match Base.validity b with
  | Base.Invalid | Base.Empty | Base.Unknown (_, None, _) -> Integer.zero
  | Base.Known (_, up) | Base.Unknown (_, Some up, _)
  | Base.Variable { Base.min_alloc = up } -> Integer.succ up

(* Create a new offsetmap initialized to [bottom] on the entire allocable
   range, with the first [max_alloc] bits set to [v].
   [v] must be an isotropic value. *)
let offsm_with_v v validity max_alloc =
  let size = Bottom.non_bottom (V_Offsetmap.size_from_validity validity) in
  let offsm = V_Offsetmap.create_isotropic ~size V_Or_Uninitialized.bottom in
  (* max_alloc is -1 when allocating an empty base *)
  if Int.(lt max_alloc zero) then
    (* malloc(0) => nothing to uninitialize *)
    offsm
  else (* malloc(i > 0) => uninitialize i bytes *)
    V_Offsetmap.add ~exact:true (Int.zero, max_alloc)
      (v, Int.one, Rel.zero) offsm

(* add [v] as a possible value for the bits [0..max_valid_bits] of
   [base] in [state].
   [v] must be an isotropic value. *)
let add_v v state base max_valid_bits =
  let validity = Base.validity base in
  let offsm = offsm_with_v v validity max_valid_bits in
  let new_offsm =
    try
      let cur = match Model.find_base_or_default base state with
        | `Top -> assert false (* Value never passes Top as state *)
        | `Bottom -> assert false (* offsm_with_v never returns Bottom *)
        | `Value m -> m
      in
      V_Offsetmap.join offsm cur
    with Not_found -> offsm
  in
  Model.add_base base new_offsm state

let add_uninitialized = add_v V_Or_Uninitialized.uninitialized
let add_zeroes = add_v (V_Or_Uninitialized.initialized Cvalue.V.singleton_zero)

(* Applies the possibility of failure when allocating/reallocating a base.
   [ret]: result in case of success (e.g. a new base in case of malloc);
   [orig_state]: state before any allocation, returned in case of failure;
   [state_after_alloc]: state in case the allocation is successful;
   [returns_null]: if given, forces the result to consider/ignore the
   possibility of failure, despite -eva-alloc-returns-null. *)
let wrap_fallible_alloc ?returns_null ret orig_state state_after_alloc =
  let default_returns_null = Parameters.AllocReturnsNull.get () in
  let returns_null = Option.value ~default:default_returns_null returns_null in
  let success = Some ret, state_after_alloc in
  if returns_null
  then
    let failure = Some Cvalue.V.singleton_zero, orig_state in
    [ success ; failure ]
  else [ success ]

let pp_validity fmt (v1, v2) =
  if Int.equal v1 v2
  then Format.fprintf fmt "0..%a" Int.pretty v1
  else Format.fprintf fmt "0..%a/%a" Int.pretty v1 Int.pretty v2


(* --------------------------------- Malloc --------------------------------- *)

(* Create a new variable of size [sizev] with deallocation type [deallocation].
   Returns the new base, and its maximum validity.
   Note that [_state] is not used, but it is present to ensure a compatible
   signature with [alloc_by_stack]. *)
let alloc_fresh weak deallocation prefix sizev _state =
  let stack = get_allocation_site_key () in
  let tsize = guess_intended_malloc_type stack sizev (weak = Strong) in
  let typ = type_from_nb_elems tsize in
  let name = create_new_variable_name stack prefix weak in
  let size_char = Bit_utils.sizeofchar () in
  (* Sizes are in bits *)
  let min_alloc = Int.(pred (mul size_char tsize.min_bytes)) in
  let max_alloc = Int.(pred (mul size_char tsize.max_bytes)) in
  let weak = match weak with Weak -> true | Strong -> false in
  let kind = deallocation in
  let var, new_base =
    Special_variables.create_allocated name typ ~weak ~min_alloc ~max_alloc ~kind
  in
  Self.result ~current:true ~once:true
    "@[allocating %svariable %a@]%t"
    (if weak then "weak " else "") Printer.pp_varinfo var
    Eva_utils.pp_callstack;
  register_malloced_base ~stack new_base;
  new_base, max_alloc

module Base_with_Size = Datatype.Pair (Base.Base) (Datatype.Integer)

(* Extremely aggressive and imprecise allocation: a single weak base for each
   region. *)
module MallocedSingleMalloc =
  State_builder.Option_ref (Base_with_Size)
    (struct
      let name = "Value.Builtins_malloc.MallocedSingleMalloc"
      let dependencies = [Ast.self]
    end)
let () = Ast.add_monotonic_state MallocedSingleMalloc.self

module MallocedSingleVLA =
  State_builder.Option_ref (Base_with_Size)
    (struct
      let name = "Value.Builtins_malloc.MallocedSingleVLA"
      let dependencies = [Ast.self]
    end)
let () = Ast.add_monotonic_state MallocedSingleVLA.self

module MallocedSingleAlloca =
  State_builder.Option_ref (Base_with_Size)
    (struct
      let name = "Value.Builtins_malloc.MallocedSingleAlloca"
      let dependencies = [Ast.self]
    end)
let () = Ast.add_monotonic_state MallocedSingleAlloca.self

let string_of_region = function
  | Base.Malloc -> "via malloc/calloc/realloc"
  | Base.VLA -> "related to variable-length arrays"
  | Base.Alloca -> "via alloca"

(* Only called when the 'weakest base' needs to be allocated. *)
let create_weakest_base region =
  let stack = { (Eva_utils.current_call_stack ()) with stack = [] } in
  let typ = TArray (Cil.charType, None, []) in
  let name = create_new_variable_name stack "alloc" Weak in
  let min_alloc = Int.minus_one in
  let max_alloc = Bit_utils.max_bit_address () in
  let var, new_base =
    Special_variables.create_allocated name typ
      ~weak:true ~min_alloc ~max_alloc ~kind:region
  in
  Self.warning ~wkey:wkey_imprecise_alloc ~current:true ~once:true
    "allocating a single weak variable for ALL dynamic allocations %s: %a"
    (string_of_region region) Printer.pp_varinfo var;
  register_malloced_base ~stack new_base;
  new_base, max_alloc

(* used by calloc_abstract *)
let alloc_weakest_base region =
  let memo =
    match region with
    | Base.Malloc -> MallocedSingleMalloc.memo
    | Base.VLA -> MallocedSingleVLA.memo
    | Base.Alloca -> MallocedSingleAlloca.memo
  in
  memo (fun () -> create_weakest_base region)

(* Variables that have been returned by a call to an allocation function
   at this callstack. The first allocated variable is at the top of the
   stack. Currently, the callstacks are truncated according to
   [-eva-alloc-functions]. *)
module MallocedByStack = (* varinfo list Callstack.hashtbl *)
  State_builder.Hashtbl (AllocSite.Hashtbl)
    (Datatype.List (Base))
    (struct
      let name = "Value.Builtins_malloc.MallocedByStack"
      let size = 17
      let dependencies = [Ast.self]
    end)
let () = Ast.add_monotonic_state MallocedByStack.self

(* Performs an abstract allocation on an existing allocated variable,
   its validity. If [make_weak], the variable is marked as being weak. *)
let update_variable_validity ?(make_weak=false) base sizev =
  let size_min, size_max = extract_size sizev in
  match base with
  | Base.Allocated (vi, _deallocation, (Base.Variable variable_v)) ->
    if make_weak && (variable_v.Base.weak = false) then
      mutate_name_to_weak vi;
    let min_sure_bits = Int.(pred (mul eight size_min)) in
    let max_valid_bits = Int.(pred (mul eight size_max)) in
    if not (Int.equal variable_v.Base.min_alloc min_sure_bits) ||
       not (Int.equal variable_v.Base.max_alloc max_valid_bits)
    then begin
      Self.result ~dkey ~current:true ~once:false
        "@[resizing variable `%a'@ (%a) to fit %a@]"
        Printer.pp_varinfo vi
        pp_validity (variable_v.Base.min_alloc, variable_v.Base.max_alloc)
        pp_validity (min_sure_bits, max_valid_bits);
      (* Mutating the type of a varinfo is not exactly a good idea. This is
         probably fine here, because the type of a malloced variable is
         almost never used. *)
      Cil.update_var_type vi (weaken_type vi.vtype);
    end;
    Base.update_variable_validity variable_v
      ~weak:make_weak ~min_alloc:min_sure_bits ~max_alloc:max_valid_bits;
    base, max_valid_bits
  | _ -> Self.fatal "base is not Allocated: %a" Base.pretty base

(* Checks if we should allocate a new base.
   We should allocate new base when the number of allocated bases on the allocation site
   is less than or equal to the threshold [mlevel] *)
let must_allocate_new_variable nb max_level =
  nb <= max_level

(* Checks if we should reuse the weak base.
   It should be the last allocated variable when 
   the threshold [mlevel] is reached  *)
let must_reuse_weak_variable nb max_level =
  nb = max_level

(* Returns the type of the new variable to be allocated *)
let new_variable_type nb max_level =
  if nb = max_level || (max_level <= 1) then Weak else Strong

(* A previously allocated strong variable [b] can be reused if it is not present in the [state] anymore.
   Which should be the case when a strong free has been performed on it. 
*)
let can_reuse_strong_variable b state =
  try
    ignore (Model.find_base b state);
    false
  with Not_found -> true

(* Allocates a new variable for the given region, prefix and size. *)

let alloc_by_stack region prefix sizev state =
  let stack = get_allocation_site_key () in
  let max_level = Parameters.MallocLevel.get () in
  let all_vars =
    try MallocedByStack.find stack
    with Not_found -> []
  in
  let rec aux nb vars =
    match vars with
    | [] -> (* must allocate a new variable *)
      assert (must_allocate_new_variable nb max_level);
      let v = new_variable_type nb max_level in
      let b, _ as r = alloc_fresh v region prefix sizev state in
      let _ = update_kf_malloced_base stack b in
      MallocedByStack.replace stack (all_vars @ [b]);
      r
    | b :: q ->
      match can_reuse_strong_variable b state with
      | false -> 
        if must_reuse_weak_variable nb max_level then 
          begin (* variable already used and should be weak *)
            assert (Base.is_weak b);
            let _ = update_kf_malloced_base stack b in
            update_variable_validity ~make_weak:false b sizev
          end
        else aux (nb+1) q
      | true ->
        (* Can reuse this (strong) variable *)
        let _ = update_kf_malloced_base stack b in
        update_variable_validity ~make_weak:false b sizev
  in
  aux 0 all_vars

let choose_base_allocation () =
  let open Eva_annotations in
  match get_allocation (current_call_site ()) with
  | Fresh -> alloc_fresh Strong
  | Fresh_weak -> alloc_fresh Weak
  | By_stack -> alloc_by_stack
  | Imprecise -> fun region _ _ _ -> alloc_weakest_base region

let register_malloc ?replace name ?returns_null prefix region cacheable =
  let builtin state args =
    let size = match args with
      | [ _, size ] -> size
      | _ -> raise (Builtins.Invalid_nb_of_args 1)
    in
    let allocate_base = choose_base_allocation () in
    let new_base, max_alloc = allocate_base region prefix size state in
    let new_state = add_uninitialized state new_base max_alloc in
    let ret = V.inject new_base Ival.zero in
    let c_values = wrap_fallible_alloc ?returns_null ret state new_state in
    let c_clobbered = Base.SetLattice.bottom in
    Builtins.Full { c_values; c_clobbered; c_assigns = None; }
  in
  let name = "Frama_C_" ^ name in
  let typ () = Cil.voidPtrType, [Cil.theMachine.Cil.typeOfSizeOf] in
  Builtins.register_builtin ?replace name cacheable builtin ~typ

let () =
  register_malloc ~replace:"malloc" "malloc" "malloc" Base.Malloc Eval.MallocedCall;
  register_malloc ~replace:"__fc_vla_alloc" "vla_alloc" "malloc" Base.VLA Eval.NoCacheCallers
    ~returns_null:false;
  register_malloc ~replace:"alloca" "alloca" "alloca" Base.Alloca Eval.NoCacheCallers
    ~returns_null:false

(* --------------------------------- Calloc --------------------------------- *)

let zero_to_max_bytes () = Ival.inject_range
    (Some Integer.zero) (Some (Bit_utils.max_byte_size ()))

let alloc_size_ok intended_size =
  try
    let size = Cvalue.V.project_ival intended_size in
    let ok_size = zero_to_max_bytes () in
    if Ival.is_included size ok_size then Alarmset.True
    else if Ival.intersects size ok_size then Alarmset.Unknown
    else Alarmset.False
  with Cvalue.V.Not_based_on_null -> Alarmset.Unknown (* garbled mix in size *)

let calloc_builtin state args =
  let nmemb, sizev =
    match args with
    | [(_, nmemb); (_, size)] -> nmemb, size
    | _ -> raise (Builtins.Invalid_nb_of_args 2)
  in
  let size = Cvalue.V.mul nmemb sizev in
  let size_ok = alloc_size_ok size in
  if size_ok <> Alarmset.True then
    Eva_utils.warning_once_current
      "calloc out of bounds: assert(nmemb * size <= SIZE_MAX)";
  let c_values =
    if size_ok = Alarmset.False (* size always overflows *)
    then [Some Cvalue.V.singleton_zero, state]
    else
      let allocate_base = choose_base_allocation () in
      let base, max_valid = allocate_base Base.Malloc "calloc" size state in
      let new_state = add_zeroes state base max_valid in
      let returns_null =
        if size_ok = Alarmset.Unknown then Some true else None
      in
      let ret = V.inject base Ival.zero in
      wrap_fallible_alloc ?returns_null ret state new_state
  in
  let c_clobbered = Base.SetLattice.bottom in
  Builtins.Full { c_values; c_clobbered; c_assigns = None; }

let () =
  let name = "Frama_C_calloc" in
  let replace = "calloc" in
  let typ () =
    let sizeof_typ = Cil.theMachine.Cil.typeOfSizeOf in
    Cil.voidPtrType, [ sizeof_typ; sizeof_typ ]
  in
  Builtins.register_builtin ~replace name NoCacheCallers calloc_builtin ~typ

(* ---------------------------------- Free ---------------------------------- *)

(* Change all references to bases into ESCAPINGADDR into the given state,
   and remove those bases from the state entirely when [exact] holds *)
let free ~exact bases state =
  let changed = ref Locations.Zone.bottom in
  (* Uncomment this code to simulate the fact that free "writes" the bases
     it deallocates
     Base_hptmap.iter (fun b ->
      changed := Zone.join !changed (enumerate_bits (loc_of_base b))
     ) bases; *)
  (* No need to remove the freed bases from the state if [exact] is false,
     because they must remain for the 'inexact' case *)
  let state =
    if exact then Base.Hptset.fold Cvalue.Model.remove_base bases state
    else state
  in
  let escaping = bases in
  let on_escaping ~b ~itv ~v:_ =
    let z = Locations.Zone.inject b (Int_Intervals.inject_itv itv) in
    changed := Locations.Zone.join !changed z
  in
  let within = Base.SetLattice.top in
  let state =
    Locals_scoping.make_escaping ~exact ~escaping ~on_escaping ~within state
  in
  let from_changed =
    let m = Assigns.Memory.(add_binding ~exact empty !changed Deps.bottom) in
    Assigns.{ memory = m; return = Deps.bottom }
  in
  state, (from_changed, if exact then !changed else Zone.bottom)

let freeable arg =
  (* Categorizes the bases in arg *)
  let f base offset (all_ok, one_ok) =
    if Base_hptmap.mem base (Dynamic_Alloc_Bases.get ()) &&
       not (is_automatically_deallocated base)
    then
      all_ok && Ival.is_zero offset,
      one_ok || Ival.contains_zero offset
    else (false, one_ok)
  in
  match Cvalue.V.fold_topset_ok f arg (true, false) with
  | true, true -> True
  | false, true -> Unknown
  | false, false -> False
  | true, false ->
    assert (V.is_bottom arg); True


let resolve_bases_to_free arg =
  (* Categorizes the bases in arg *)
  let f base offset (acc, card, null) =
    let allocated_base = Base_hptmap.mem base (Dynamic_Alloc_Bases.get ()) in
    (* Collect the bases to remove from the memory state.
       Also count the number of freeable bases (including NULL). *)
    if Ival.contains_zero offset
    then begin
      let base_card = match Base.validity base with
        | Base.Variable { Base.weak = true } -> 2
        (* weak validity has "infinite" cardinality; but here we use 2 since
           any value > 1 leads to a weak update anyway *)
        | _ -> 1
      in
      if allocated_base
      then Base.Hptset.add base acc, card + base_card, null
      else if Base.is_null base
      then acc, card + base_card, true
      else acc, card, null
    end
    else acc, card, null
  in
  Cvalue.V.fold_topset_ok f arg (Base.Hptset.empty, 0, false)

let free_aux state ~strong bases_to_remove  =
  (* TODO: reduce on arg if it is an lval *)
  if strong then begin
    Self.debug ~current:true ~dkey "strong free on bases: %a"
      Base.Hptset.pretty bases_to_remove;
    free ~exact:true bases_to_remove state
  end else begin
    Self.debug ~current:true ~dkey "weak free on bases: %a"
      Base.Hptset.pretty bases_to_remove;
    free ~exact:false bases_to_remove state
  end

(* Builtin for [free] function *)
let frama_c_free state actuals =
  match actuals with
  | [ _, arg ] ->
    let bases_to_remove, card_to_remove, _null = resolve_bases_to_free arg in
    let c_clobbered = Base.SetLattice.bottom in
    if card_to_remove = 0 then
      Builtins.Full { c_values = []; c_clobbered; c_assigns = None; }
    else
      let strong = card_to_remove <= 1 in
      let state, changed = free_aux state ~strong bases_to_remove in
      let c_values = [None, state] in
      Builtins.Full { c_values; c_clobbered; c_assigns = Some changed; }
  | _ -> raise (Builtins.Invalid_nb_of_args 1)

let () =
  Builtins.register_builtin ~replace:"free" "Frama_C_free" Cacheable
    frama_c_free ~typ:(fun () -> (Cil.voidType, [Cil.voidPtrType]))

(* built-in for [__fc_vla_free] function. By construction, VLA should always
   be mapped to a single base. *)
let frama_c_vla_free state actuals =
  match actuals with
  | [ _, arg ] ->
    let bases_to_remove, _card_to_remove, _null = resolve_bases_to_free arg in
    let state, changed = free_aux state ~strong:true bases_to_remove in
    let c_values = [None, state] in
    let c_clobbered = Base.SetLattice.bottom in
    Builtins.Full { c_values; c_clobbered; c_assigns = Some changed; }
  | _ -> raise (Builtins.Invalid_nb_of_args 1)

let () =
  Builtins.register_builtin
    ~replace:"__fc_vla_free" "Frama_C_vla_free" Cacheable frama_c_vla_free
    ~typ:(fun () -> (Cil.voidType, [Cil.voidPtrType]))

let free_automatic_bases stack state =
  (* free automatic bases that were allocated in the current function *)
  let bases_to_free =
    Base_hptmap.fold (fun base stack' acc ->
        if is_automatically_deallocated base &&
           Callstack.equal stack stack'
        then Base.Hptset.add base acc
        else acc
      ) (Dynamic_Alloc_Bases.get ()) Base.Hptset.empty
  in
  if Base.Hptset.is_empty bases_to_free then state
  else begin
    Self.result ~current:true ~once:true
      "freeing automatic bases: %a" Base.Hptset.pretty bases_to_free;
    let state', _changed = free_aux state ~strong:true bases_to_free in
    (* TODO: propagate 'freed' bases for From? *)
    state'
  end

(* -------------------------------- Realloc --------------------------------- *)

(* Note: realloc never fails during read/write operations, hence we can
   always ignore the validity of locations. (We craft them ourselves anyway.)
   The only possible cause of failure is a pointer that was not malloced. *)

(* Auxiliary function for [realloc], that copies the [size] first bytes of
   [b] (or less if [b] is too small) in [src_state], then pastes them in
   [new_base] in [dst_state], which is supposed to be big enough for [size].
   This function always perform weak updates, in case multiple bases are
   copied to [new_base]. *)
let realloc_copy_one size ~src_state ~dst_state new_base b =
  let size_char = Bit_utils.sizeofchar () in
  let size_bits = Integer.mul size size_char in
  let up = match Base.validity b with
    | Base.Known (_, up) | Base.Unknown (_, _, up)
    | Base.Variable { Base.max_alloc = up } -> up
    | Base.Invalid | Base.Empty -> Integer.zero

  in
  let size_to_copy = Int.min (Int.succ up) size_bits in
  let src = Location_Bits.inject b Ival.zero in
  match Cvalue.Model.copy_offsetmap src size_to_copy src_state with
  | `Bottom -> assert false
  | `Value offsetmap ->
    if Int.gt size_to_copy Int.zero then
      Cvalue.Model.paste_offsetmap
        ~from:offsetmap ~dst_loc:new_base ~size:size_to_copy
        ~exact:false dst_state
    else dst_state

(* Auxiliary function for [realloc], that performs the allocation of a new
   variable, and copy the pointers being reallocated inside the new base.
   [size] is the size to realloc. [bases_to_realloc] are the pointers to the
   memory to copy. [null_in_arg] indicates that [realloc] was called with
   [null] in its argument. [weak] indicates which type of variable must
   be created: if [Weak], convergence is ensured using a malloc builtin
   that converges.  If [Strong], a new base is created for each call. *)
let realloc_alloc_copy weak bases_to_realloc null_in_arg sizev state =
  Self.debug ~dkey "bases_to_realloc: %a"
    Base.Hptset.pretty bases_to_realloc;
  assert (not (Model.(equal state bottom || equal state top)));
  let _size_valid, size_max = extract_size sizev in (* bytes everywhere *)
  let base, max_valid =
    let prefix = "realloc" in
    match weak with
    | Strong -> alloc_fresh Strong Base.Malloc prefix sizev state
    | Weak -> alloc_by_stack Base.Malloc prefix sizev state
  in
  (* Make sure that [ret] will be present in the result: we bind it at least
     to bottom everywhere *)
  let dst_state = add_uninitialized state base Int.minus_one in
  let ret = V.inject base Ival.zero in
  let loc_bits = Locations.loc_bytes_to_loc_bits ret in
  (* get bases to free and copy *)
  let lbases = Base.Hptset.elements bases_to_realloc in
  let dst_state =
    (* uninitialized on all reallocated valid bits *)
    let uninit = V_Or_Uninitialized.uninitialized in
    let offsm = offsm_with_v uninit (Base.validity base) max_valid in
    let offsm =
      if null_in_arg then offsm (* In this case, realloc may copy nothing *)
      else
        (* Compute the maximal size that is guaranteed to be copied across all
           bases *)
        let aux_valid size b = Integer.min size (size_sure_valid b) in
        let size_new_loc = Integer.mul size_max (Bit_utils.sizeofchar ()) in
        let size_sure_valid = List.fold_left aux_valid size_new_loc lbases in
        (* Replace the bits [0..size_sure_valid] by [bottom]. Those [bottom]
           will be overwritten in the call to [realloc_copy_one]. *)
        if Int.gt size_sure_valid Int.zero then
          V_Offsetmap.add (Int.zero, Int.pred size_sure_valid)
            (V_Or_Uninitialized.bottom, Int.one, Rel.zero) offsm
        else offsm
    in
    Cvalue.Model.paste_offsetmap
      ~from:offsm ~dst_loc:loc_bits ~size:(Int.succ max_valid) ~exact:false
      dst_state
  in
  (* Copy the old bases *)
  let copy_one dst_state b =
    realloc_copy_one size_max ~src_state:state ~dst_state loc_bits b
  in
  let state = List.fold_left copy_one dst_state lbases in
  ret, state

(* Auxiliary function for [realloc]. All the bases in [bases] are realloced
   one by one, plus NULL if [null] holds. This function acts as if we had
   first made a disjunction on the pointer passed to [realloc]. *)
let realloc_multiple bases null size state =
  (* this function should never be used with weak allocs *)
  let aux_bases b acc = Base.Hptset.singleton b :: acc in
  let lbases = Base.Hptset.fold aux_bases bases [] in
  (* This function reallocates the base [b] alone, but does not free it.
     We cannot free yet, because [b] would leak in the states corresponding
     to the variables different from [b]. *)
  let realloc_one_base b = realloc_alloc_copy Strong b false size state in
  let join (ret1, st1) (ret2, st2) = V.join ret1 ret2, Model.join st1 st2 in
  let aux_one_base acc b = join (realloc_one_base b) acc in
  let res = List.fold_left aux_one_base (V.bottom, state) lbases in
  (* Add another base for realloc(NULL) if needed. *)
  if null then
    join res (realloc_alloc_copy Strong Base.Hptset.empty true size state)
  else res

let realloc_imprecise_weakest _bases _null _size state =
  let new_base, max_alloc = alloc_weakest_base Base.Malloc in
  let state = add_uninitialized state new_base max_alloc in
  let ret = V.inject new_base Ival.zero in
  ret, state

let choose_bases_reallocation () =
  let open Eva_annotations in
  match get_allocation (current_call_site ()) with
  | Fresh | Fresh_weak -> realloc_multiple
  | By_stack -> realloc_alloc_copy Weak
  | Imprecise -> realloc_imprecise_weakest

let realloc_builtin_aux state ptr size =
  let bases, card_ok, null = resolve_bases_to_free ptr in
  if card_ok > 0 then
    let realloc = choose_bases_reallocation () in
    let ret, new_state = realloc bases null size state in
    (* Maybe the calls above made [ret] weak, and it
       was among the arguments. In this case, do not free it entirely! *)
    let strong = card_ok <= 1 && not Base.(Hptset.exists is_weak bases) in
    (* free old bases. *)
    let new_state, changed = free_aux new_state ~strong bases in
    let c_values = wrap_fallible_alloc ret state new_state in
    let c_clobbered = Builtins.clobbered_set_from_ret new_state ret in
    Builtins.Full { c_values; c_clobbered; c_assigns = Some changed; }
  else (* Invalid call. *)
    let c_clobbered = Base.SetLattice.bottom in
    Builtins.Full { c_values = []; c_clobbered; c_assigns = None; }

let realloc_builtin state args =
  let ptr, size =
    match args with
    | [ (_, ptr); (_, size) ] -> ptr, size
    | _ -> raise (Builtins.Invalid_nb_of_args 2)
  in
  realloc_builtin_aux state ptr size

let () =
  let name = "Frama_C_realloc" in
  let replace = "realloc" in
  let typ () = Cil.(voidPtrType, [voidPtrType; theMachine.typeOfSizeOf]) in
  Builtins.register_builtin ~replace name NoCacheCallers realloc_builtin ~typ

let reallocarray_builtin state args =
  let ptr, nmemb, sizev =
    match args with
    | [ (_, ptr); (_, nmemb); (_, sizev) ] -> ptr, nmemb, sizev
    | _ -> raise (Builtins.Invalid_nb_of_args 3)
  in
  let size = Cvalue.V.mul nmemb sizev in
  let size_ok = alloc_size_ok size in
  if size_ok <> Alarmset.True then
    Eva_utils.warning_once_current
      "reallocarray out of bounds: assert(nmemb * size <= SIZE_MAX)";
  if size_ok = Alarmset.False (* size always overflows *)
  then Builtins.Result [Cvalue.V.singleton_zero]
  else
    let valid_size =
      Cvalue.V.narrow (Cvalue.V.inject_ival (zero_to_max_bytes ())) size
    in
    let res = realloc_builtin_aux state ptr valid_size in
    if size_ok = Alarmset.Unknown then
      (* include failure case among possible results *)
      match res with
      | Builtins.Full cr ->
        let c_values = (Some Cvalue.V.singleton_zero, state) :: cr.c_values in
        Builtins.Full { cr with c_values }
      | _ -> assert false (* realloc_builtin_aux always returns Full *)
    else res

let () =
  let name = "Frama_C_reallocarray" in
  let replace = "reallocarray" in
  let typ () =
    Cil.(voidPtrType,
         [voidPtrType; theMachine.typeOfSizeOf; theMachine.typeOfSizeOf])
  in
  Builtins.register_builtin
    ~replace name NoCacheCallers reallocarray_builtin ~typ

(* ----------------------------- Leak detection ----------------------------- *)

(* Experimental, not to be released, leak detection built-in. *)
(* Check if the base_to_check is present in one of
   the offsetmaps of the state *)
exception Not_leaked
let check_if_base_is_leaked base_to_check state =
  match state with
  | Model.Bottom -> false
  | Model.Top -> true
  | Model.Map m ->
    try
      Cvalue.Model.fold
        (fun base offsetmap () ->
           if not (Base.equal base_to_check base) then
             Cvalue.V_Offsetmap.iter_on_values
               (fun v ->
                  if Locations.Location_Bytes.may_reach base_to_check
                      (V_Or_Uninitialized.get_v v) then raise Not_leaked)
               offsetmap)
        m
        ();
      true
    with Not_leaked -> false

(* Does not detect leaked cycles within malloc'ed bases.
   The complexity is very far from being optimal. *)
let check_leaked_malloced_bases state _ =
  let alloced_bases = Dynamic_Alloc_Bases.get () in
  Base_hptmap.iter
    (fun base _ -> if check_if_base_is_leaked base state then
        Eva_utils.warning_once_current "memory leak detected for %a"
          Base.pretty base)
    alloced_bases;
  let c_clobbered = Base.SetLattice.bottom in
  Builtins.Full { c_values = [None,state]; c_clobbered; c_assigns = None; }

let () =
  Builtins.register_builtin "Frama_C_check_leak" NoCacheCallers
    check_leaked_malloced_bases



(* ----------------------------- Memexec utils ----------------------------- *)
let get_kf_allocated_bases kf =
  Kf_Alloc_Bases.get_cur_alloc_bases kf

let clear_kf_allocated_bases kf =
  Kf_Alloc_Bases.clear_cur_alloc_bases kf

let register_reused_base _stack _b =
  let kfs = Callstack.to_kf_list _stack in 
  List.iter (fun kf -> 
      Kf_Alloc_Bases.update_alloc_bases kf _b) kfs

let get_base_allocation_site base =
  let bases = Dynamic_Alloc_Bases.get () in
  try Base_hptmap.find base bases
  with Not_found -> assert false

(* Incremental analysis utils *)

let import_kf kf =
  match Ast_diff.Kernel_function.find kf with
  | `Same kf' | `Partial(kf', _) -> kf'
  | _ -> raise Not_found

let import_stmt stmt = 
  match Ast_diff.Stmt.find stmt with
  | `Same stmt -> stmt
  | _ -> raise Not_found

let import_dynamic_bases project =
  let gather () = Base_hptmap.fold (fun base cs acc -> (base, cs) :: acc) (Dynamic_Alloc_Bases.get ()) []
  in
  let list = Project.on project gather () in
  let import (base, cs) = 
    try
      let base = Eva_diff.import_base base in
      let cs = AllocSite.import cs in
      let new_map = Base_hptmap.add base cs (Dynamic_Alloc_Bases.get ()) in
      Dynamic_Alloc_Bases.set new_map
    with Not_found -> 
      ()
  in
  List.iter import list

let import_malloced_by_stack project =
  let gather () = MallocedByStack.fold (fun cs bases acc -> (cs, bases) :: acc) []
  in
  let list = Project.on project gather () in
  let import (cs, bases) = 
    try
      let cs = AllocSite.import cs in
      let bases = List.map Eva_diff.import_base bases in
      MallocedByStack.add cs bases
    with Not_found -> 
      ()
  in
  List.iter import list


let import_kf_alloc_sites project tbl =
  let gather () = Kf_Alloc_Sites.fold (fun kf stmts acc -> (kf, stmts) :: acc) [] in
  let list = Project.on project gather () in
  let import (kf, stmts) = 
    try
      let kf = import_kf kf in
      let sites = AllocSite.Set.fold (fun site acc -> 
          let site = AllocSite.import site in
          AllocSite.Set.add site acc)
          stmts AllocSite.Set.empty in
      Kf_Alloc_Sites.add kf sites
    with Not_found ->
      Kernel_function.Hashtbl.add tbl kf ()
  in
  List.iter import list

let import_kf_call_sites project tbl =
  let gather () = Kf_Call_Sites.fold (fun kf call_sites acc -> (kf, call_sites) :: acc) [] in
  let list = Project.on project gather () in
  let import (kf, call_sites) = 
    try
      let kf = import_kf kf in
      let call_sites = CallSite.Set.fold (fun stmt acc -> 
          let stmt = import_stmt stmt in
          CallSite.Set.add stmt acc)
          call_sites CallSite.Set.empty in
      Kf_Call_Sites.add kf call_sites
    with Not_found ->
      Kernel_function.Hashtbl.add tbl kf ()
  in
  List.iter import list


let import_kf_alloc_bases project tbl =
  let gather () = Kf_Alloc_Bases.fold (fun kf bases acc -> (kf, bases) :: acc) [] in
  let list = Project.on project gather () in
  let import_bases bases =
    Base.Hptset.fold (fun base acc -> 
        let base = Eva_diff.import_base base in
        Base.Hptset.add base acc)
      bases Base.Hptset.empty
  in
  let import (kf, (_, b')) = 
    try
      let kf = import_kf kf in
      (* Fst should always be empty after an analysis *)
      let bases = 
        Base.Hptset.empty, import_bases b' in
      Kf_Alloc_Bases.add kf bases
    with Not_found ->
      Kernel_function.Hashtbl.add tbl kf ()
  in
  List.iter import list

let clear () = 
  begin 
    Kf_Alloc_Bases.clear (); 
    Kf_Alloc_Sites.clear ();
    Kf_Call_Sites.clear ();
    MallocedByStack.clear ();
    Dynamic_Alloc_Bases.clear ();
  end


let import project =
  let _ = clear () in
  let not_imported_kf = Kernel_function.Hashtbl.create 1 in
  let _ = import_dynamic_bases project in
  let _ = import_malloced_by_stack project in
  let _ = import_kf_alloc_sites project not_imported_kf in
  let _ = import_kf_call_sites project not_imported_kf in
  let _ = import_kf_alloc_bases project not_imported_kf in
  not_imported_kf

let print_summary fmt  = 
  let kfs = Kf_Alloc_Sites.fold (fun kf _ acc -> kf::acc) [] in
  let print_allocated_bases kf = 
    let bases = Kf_Alloc_Bases.get_all_alloc_bases kf in
    Format.fprintf fmt "All allocated bases: %a@." Base.Hptset.pretty bases
  in
  let print_alloc_sites kf =
    let stmts = match Kf_Alloc_Sites.find_opt kf with
      | None -> AllocSite.Set.empty
      | Some stmts -> stmts in
    Format.fprintf fmt "Allocation sites: %a@." AllocSite.Set.pretty stmts
  in
  let print_call_sites kf = 
    let call_sites = try Kf_Call_Sites.find kf 
      with Not_found -> CallSite.Set.empty in
    Format.fprintf fmt "Call sites: %a@." CallSite.Set.pretty call_sites
  in
  let print_dynamic_alloc_bases () = 
    let bases = Dynamic_Alloc_Bases.get () in
    Format.fprintf fmt "Dynamic allocated bases: %a@." Base_hptmap.pretty bases
  in
  let print_malloced_by_stack () = 
    MallocedByStack.iter (fun cs bases -> 
        Format.fprintf fmt "Malloced by stack: %a -> %a@." Callstack.pretty cs (Pretty_utils.pp_list ~sep:", " Base.pretty) bases)
  in
  let print fmt kf = 
    Format.fprintf fmt "Kernel function: %a@." Kernel_function.pretty kf;
    print_allocated_bases kf;
    print_alloc_sites kf;
    print_call_sites kf;
    Format.fprintf fmt "@."
  in List.iter (print fmt) kfs;
  print_dynamic_alloc_bases ();
  print_malloced_by_stack ()

let print_summary () =
  let dkey = Self.dkey_alloc_summary in
  let header fmt = Format.fprintf fmt " ====== DYNAMIC ALLOCATION SUMMARY ======" in
  Self.printf ~header ~dkey ~level:1 "  @[<v>%t@]" print_summary
(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
