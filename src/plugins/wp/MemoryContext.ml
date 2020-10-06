(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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
(* --- Variable Partitionning                                             --- *)
(* -------------------------------------------------------------------------- *)

type param = NotUsed | ByAddr | ByValue | ByShift | ByRef | InContext | InArray

let pp_param fmt = function
  | NotUsed -> Format.pp_print_string fmt "not used"
  | ByAddr -> Format.pp_print_string fmt "in heap"
  | ByValue -> Format.pp_print_string fmt "by value"
  | ByShift -> Format.pp_print_string fmt "by value with shift"
  | ByRef -> Format.pp_print_string fmt "by ref."
  | InContext -> Format.pp_print_string fmt "in context"
  | InArray -> Format.pp_print_string fmt "in array"

(* -------------------------------------------------------------------------- *)
(* --- Separation Hypotheses                                              --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types

type zone =
  | Var of varinfo   (* &x     - the cell x *)
  | Ptr of varinfo   (* p      - the cell pointed by p *)
  | Arr of varinfo   (* p+(..) - the cell and its neighbors pointed by p *)

type partition = {
  globals : zone list ; (* [ &G , G[...], ... ] *)
  to_heap : zone list ; (* [ p, ... ] *)
  context : zone list ; (* [ p+(..), ... ] *)
  by_addr : zone list ;
}

(* -------------------------------------------------------------------------- *)
(* --- Partition                                                          --- *)
(* -------------------------------------------------------------------------- *)

let empty = {
  globals = [] ;
  context = [] ;
  to_heap = [] ;
  by_addr = [] ;
}

let set x p w =
  match p with
  | NotUsed -> w
  | ByAddr -> { w with by_addr = Var x :: w.by_addr }
  | ByRef | InContext ->
      if Cil.isFunctionType x.vtype then w else
        { w with context = Ptr x :: w.context }
  | InArray ->
      if Cil.isFunctionType x.vtype then w else
        { w with context = Arr x :: w.context }
  | ByValue | ByShift ->
      if x.vghost then w else
      if Cil.isFunctionType x.vtype then w else
      if x.vglob && (x.vstorage <> Static || x.vaddrof) then
        let z = if Cil.isArrayType x.vtype then Arr x else Var x in
        { w with globals = z :: w.globals }
      else
      if x.vformal && Cil.isPointerType x.vtype then
        let z = if p = ByShift then Arr x else Ptr x in
        { w with to_heap = z :: w.to_heap }
      else w

(* -------------------------------------------------------------------------- *)
(* ANNOTS                                                                     *)
(* -------------------------------------------------------------------------- *)

open Logic_const


let rec ptr_of = function
  | Ctype t -> Ctype (TPtr(t, []))
  | t when Logic_typing.is_set_type t ->
      let t = Logic_typing.type_of_set_elem t in
      Logic_const.make_set_type (ptr_of t)
  | _ -> assert false

let rec addr_of_lval ?loc term =
  let typ = ptr_of term.term_type in
  match term.term_node with
  | TLval lv ->
      Logic_utils.mk_logic_AddrOf ?loc lv typ
  | TCastE (_, t) | TLogic_coerce (_, t) ->
      addr_of_lval ?loc t
  | Tif(c, t, e) ->
      let t = addr_of_lval ?loc t in
      let e = addr_of_lval ?loc e in
      Logic_const.term ?loc (Tif(c, t, e)) typ
  | Tat( _, _) ->
      term
  | Tunion l ->
      let l = List.map (addr_of_lval ?loc) l in
      Logic_const.term ?loc (Tunion l) typ
  | Tinter l ->
      let l = List.map (addr_of_lval ?loc) l in
      Logic_const.term ?loc (Tinter l) typ
  | Tcomprehension (t, qs, p) ->
      let t = addr_of_lval ?loc t in
      Logic_const.term ?loc (Tcomprehension (t,qs,p)) typ
  | _ -> term

let type_of_zone = function
  | Ptr vi -> vi.vtype
  | Var vi -> TPtr(vi.vtype, [])
  | Arr vi when Cil.isPointerType vi.vtype -> vi.vtype
  | Arr vi -> TPtr(Cil.typeOf_array_elem vi.vtype, [])

let zone_to_term ?(to_char=false) loc zone =
  let typ = Ctype (type_of_zone zone) in
  let lval vi = TVar (Cil.cvar_to_lvar vi), TNoOffset in
  let loc_range ptr =
    if not to_char then ptr
    else
      let pointed =
        match typ with
        | (Ctype (TPtr (t, []))) -> t
        | _ -> assert false (* typ has been generated by type_of_zone *)
      in
      let len = Logic_utils.expr_to_term (Cil.sizeOf ~loc pointed) in
      let last = term (TBinOp(MinusA, len, tinteger ~loc 1)) len.term_type in
      let range = trange ~loc (Some (tinteger ~loc 0), Some last) in
      let ptr = Logic_utils.mk_cast ~loc Cil.charPtrType ptr in
      term ~loc (TBinOp(PlusPI, ptr, range)) ptr.term_type
  in
  match zone with
  | Var vi -> loc_range (term ~loc (TAddrOf(lval vi)) typ)
  | Ptr vi -> loc_range (term ~loc (TLval(lval vi)) typ)
  | Arr vi ->
      let ptr =
        if Cil.isArrayType vi.vtype
        then term ~loc (TStartOf (lval vi)) typ
        else term ~loc (TLval(lval vi)) typ
      in
      let ptr =
        if not to_char then ptr
        else Logic_utils.mk_cast ~loc Cil.charPtrType ptr
      in
      let range = trange ~loc (None, None) in
      term ~loc (TBinOp(PlusPI, ptr, range)) ptr.term_type

let region_to_term loc = function
  | [] -> term ~loc Tempty_set (Ctype Cil.charPtrType)
  | [z] -> zone_to_term loc z
  | x :: tl as l ->
      let fst = type_of_zone x in
      let tl = List.map type_of_zone tl in
      let to_char = not (List.for_all (Cil_datatype.Typ.equal fst) tl) in
      let set_typ =
        make_set_type (Ctype (if to_char then Cil.charPtrType else fst))
      in
      term ~loc (Tunion (List.map (zone_to_term ~to_char loc) l)) set_typ

let separated_list ?loc = function
  | [] | [ _ ] -> ptrue
  | l ->
      let comp = Cil_datatype.Term.compare in
      pseparated ?loc (List.sort comp l)

let term_separated_from_regions loc assigned l =
  separated_list ~loc (assigned :: List.map (region_to_term loc) l)

let valid_region loc r =
  let t = region_to_term loc r in
  pvalid ~loc (here_label, t)

let global_zones partition =
  List.map (fun z -> [z]) partition.globals

let context_zones partition =
  List.map (fun z -> [z]) partition.context

let addr_of_zones partition =
  let comp a b = Cil_datatype.Typ.compare (type_of_zone a) (type_of_zone b) in
  List.sort comp partition.by_addr

let heap_zones partition =
  let comp a b = Cil_datatype.Typ.compare (type_of_zone a) (type_of_zone b) in
  List.sort comp partition.to_heap

(* Note that this function does not return separated zone lists, but well-typed
   zone lists.
*)
let well_type_zones zone_function partition =
  let rec partition_by_type t acc l =
    match l, acc with
    | [], _ ->
        acc
    | x :: l, [] ->
        partition_by_type (type_of_zone x) [[x]] l
    | x :: l, p :: acc' when Cil_datatype.Typ.equal t (type_of_zone x) ->
        partition_by_type t ((x :: p) :: acc') l
    | x :: l, acc ->
        partition_by_type (type_of_zone x) ([x] :: acc) l
  in
  partition_by_type Cil.voidType [] (zone_function partition)

let heaps = well_type_zones heap_zones

let main_separation loc globals context heaps =
  match heaps, context with
  | [], [] ->
      (* In this case, separation is completely trivial *)
      [ ptrue ]
  | [], context ->
      let zones = globals @ context in
      [ separated_list ~loc (List.map (region_to_term loc) zones) ]
  | heaps, context ->
      let for_typed_heap h =
        let zones = h :: globals @ context in
        separated_list ~loc (List.map (region_to_term loc) zones)
      in
      List.map for_typed_heap heaps

let assigned_locations kf filter =
  let add_from l (e, _ds) =
    if filter e.it_content then e :: l else l
  in
  let add_assign _emitter assigns l = match assigns with
    | WritesAny -> l
    | Writes froms -> List.fold_left add_from l froms
  in
  Annotations.fold_assigns add_assign kf Cil.default_behavior_name []

let assigned_via_pointers kf =
  let rec assigned_via_pointer t =
    match t.term_node with
    | TLval (TMem _, _) ->
        true
    | TCastE (_, t) | TLogic_coerce (_, t)
    | Tcomprehension(t, _, _) | Tat (t, _) ->
        assigned_via_pointer t
    | Tunion l | Tinter l ->
        List.exists assigned_via_pointer l
    | Tif (_, t1, t2) ->
        assigned_via_pointer t1 || assigned_via_pointer t2
    | _ ->
        false
  in
  assigned_locations kf assigned_via_pointer

let post_term t =
  let exception Post_value in
  let v = object
    inherit Cil.nopCilVisitor
    method! vlogic_label = function
      | BuiltinLabel(Post) -> raise Post_value
      | _ -> Cil.SkipChildren
    method! vterm_lval = function
      | TResult _, _ -> raise Post_value
      | _ -> Cil.DoChildren
  end in
  try ignore (Cil.visitCilTerm v t) ; false
  with Post_value -> true

let simpl_pred_list l =
  List.sort_uniq Logic_utils.compare_predicate
    (List.filter (fun p -> not(Logic_utils.is_trivially_true p)) l)

let clauses_of_partition kf loc p =
  let globals = global_zones p in
  let main_sep =
    main_separation loc globals (context_zones p) (heaps p)
  in
  let assigns_sep_req, assigns_sep_ens =
    let addr_of t = addr_of_lval ~loc t.it_content in
    let folder (req, ens) t =
      let sep = term_separated_from_regions loc (addr_of t) globals in
      if post_term t.it_content then (req, sep :: ens) else (sep :: req, ens)
    in
    List.fold_left folder ([],[]) (assigned_via_pointers kf)
  in
  let context_validity = List.map (valid_region loc) (context_zones p) in
  let reqs = main_sep @ assigns_sep_req @ context_validity in
  let reqs = simpl_pred_list reqs in
  let ens = simpl_pred_list assigns_sep_ens in
  reqs, ens

let addr_of_vars = well_type_zones addr_of_zones

let ptr_or_ptr_set { term_type = t } =
  let open Logic_typing in
  is_pointer_type t || (is_set_type t && is_pointer_type (type_of_element t))

let escaping_formals kf loc p =
  let ret_t = Kernel_function.get_return_type kf in
  let addr_of t = addr_of_lval ~loc t.it_content in
  let asgnd_ptrs =
    Extlib.filter_map
      (* Search assigned pointers via a pointer,
         e.g. 'assigns *p ;' with '*p' of type pointer or set of pointers *)
      (fun t -> ptr_or_ptr_set t.it_content) addr_of (assigned_via_pointers kf)
  in
  let asgnd_ptrs =
    if Cil.isPointerType ret_t then tresult ~loc ret_t :: asgnd_ptrs
    else asgnd_ptrs
  in
  let local_zone = function Var v -> v.vformal | _ -> false in
  let local_partition = { p with by_addr = List.filter local_zone p.by_addr } in
  let locals = addr_of_vars local_partition in
  simpl_pred_list
    (List.map (fun t -> term_separated_from_regions loc t locals) asgnd_ptrs)

module Table =
  State_builder.Hashtbl
    (Cil_datatype.Kf.Hashtbl)
    (Datatype.Option(Cil_datatype.Funbehavior))
    (struct
      let name = "MemoryContext.Table"
      let size = 17
      let dependencies = [ Ast.self ]
    end)

let compute_behavior kf name hypotheses_computer =
  let partition = hypotheses_computer kf in
  let loc = Kernel_function.get_location kf in
  let reqs, ens = clauses_of_partition kf loc partition in
  let ens = escaping_formals kf loc partition @ ens in
  let reqs = List.map new_predicate reqs in
  let ens = List.map (fun p -> Normal, new_predicate p) ens in
  match reqs, ens with
  | [], [] -> None
  | reqs, ens ->
      Some {
        b_name = name ;
        b_requires = reqs ;
        b_assumes = [] ;
        b_post_cond = ens ;
        b_assigns = WritesAny ;
        b_allocation = FreeAllocAny ;
        b_extended = []
      }

let compute name hypotheses_computer =
  Globals.Functions.iter
    (fun kf -> ignore (compute_behavior kf name hypotheses_computer))

let get_behavior kf name hypotheses_computer =
  Table.memo
    begin fun kf ->
      AssignsCompleteness.warn kf ;
      compute_behavior kf name hypotheses_computer
    end
    kf

let print_memory_context kf bhv fmt =
  begin
    let printer = new Printer.extensible_printer () in
    let pp_vdecl = printer#without_annot printer#vdecl in
    Format.fprintf fmt "@[<hv 0>@[<hv 3>/*@@@ %a" Cil_printer.pp_behavior bhv ;
    let vkf = Kernel_function.get_vi kf in
    Format.fprintf fmt "@ @]*/@]@\n@[<hov 2>%a;@]@\n"
      pp_vdecl vkf ;
  end

let warn kf name hyp_computer =
  match get_behavior kf name hyp_computer with
  | None -> ()
  | Some bhv ->
      Wp_parameters.warning
        ~current:false ~once:true ~source:(fst(Kernel_function.get_location kf))
        "@[<hv 0>Memory model hypotheses for function '%s':@ %t@]"
        (Kernel_function.get_name kf)
        (print_memory_context kf bhv)

let emitter =
  Emitter.(create "Wp.Hypotheses" [Funspec] ~correctness:[] ~tuning:[])

module RegisteredHypotheses =
  State_builder.Set_ref
    (Cil_datatype.Kf.Set)
    (struct
      let name = "Wp.MemoryContext.RegisteredHypotheses"
      let dependencies = [Ast.self]
    end)

let add_behavior kf name hypotheses_computer =
  if RegisteredHypotheses.mem kf then ()
  else begin
    begin match get_behavior kf name hypotheses_computer with
      | None -> ()
      | Some bhv -> Annotations.add_behaviors emitter kf [bhv]
    end ;
    RegisteredHypotheses.add kf
  end
