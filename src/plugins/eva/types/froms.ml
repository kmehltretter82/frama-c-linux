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

open Locations

module DepsOrUnassigned = struct

  type deps_or_unassigned =
    | DepsBottom
    | Unassigned
    | AssignedFrom of Deps.t
    | MaybeAssignedFrom of Deps.t

  module DatatypeDeps = Datatype.Make(struct
      type t = deps_or_unassigned

      let name = "Function_Froms.Deps.deps"

      let pretty fmt = function
        | DepsBottom -> Format.pp_print_string fmt "DEPS_BOTTOM"
        | Unassigned -> Format.pp_print_string fmt "UNASSIGNED"
        | AssignedFrom fd -> Deps.pretty_precise fmt fd
        | MaybeAssignedFrom fd ->
          (* '(or UNASSIGNED)' would be a better pretty-printer, we use
             '(and SELF)' only for compatibility reasons *)
          Format.fprintf fmt "%a (and SELF)" Deps.pretty_precise fd

      let hash = function
        | DepsBottom -> 3
        | Unassigned -> 17
        | AssignedFrom fd -> 37 + 13 * Deps.hash fd
        | MaybeAssignedFrom fd -> 57 + 123 * Deps.hash fd

      let compare d1 d2 = match d1, d2 with
        | DepsBottom, DepsBottom
        | Unassigned, Unassigned -> 0
        | AssignedFrom fd1, AssignedFrom fd2
        | MaybeAssignedFrom fd1, MaybeAssignedFrom fd2 ->
          Deps.compare fd1 fd2
        | DepsBottom, (Unassigned | AssignedFrom _ | MaybeAssignedFrom _)
        | Unassigned, (AssignedFrom _ | MaybeAssignedFrom _)
        | AssignedFrom _, MaybeAssignedFrom _ ->
          -1
        | (Unassigned | AssignedFrom _ | MaybeAssignedFrom _), DepsBottom
        | (AssignedFrom _ | MaybeAssignedFrom _), Unassigned
        | MaybeAssignedFrom _, AssignedFrom _ ->
          1

      let equal = Datatype.from_compare

      let reprs = Unassigned :: List.map (fun r -> AssignedFrom r) Deps.reprs

      let structural_descr =
        let d = Deps.packed_descr in
        Structural_descr.t_sum [| [| d |]; [| d |] |]
      let rehash = Datatype.identity

      let mem_project = Datatype.never_any_project

      let copy = Datatype.undefined

    end)

  let join d1 d2 = match d1, d2 with
    | DepsBottom, d | d, DepsBottom -> d
    | Unassigned, Unassigned -> Unassigned
    | Unassigned, AssignedFrom fd | AssignedFrom fd, Unassigned ->
      MaybeAssignedFrom fd
    | Unassigned, (MaybeAssignedFrom _ as d)
    | (MaybeAssignedFrom _ as d), Unassigned ->
      d
    | AssignedFrom fd1, AssignedFrom fd2 ->
      AssignedFrom (Deps.join fd1 fd2)
    | AssignedFrom fd1, MaybeAssignedFrom fd2
    | MaybeAssignedFrom fd1, AssignedFrom fd2
    | MaybeAssignedFrom fd1, MaybeAssignedFrom fd2 ->
      MaybeAssignedFrom (Deps.join fd1 fd2)

  let narrow _ _ = assert false (* not used yet *)

  let is_included d1 d2 = match d1, d2 with
    | DepsBottom, (DepsBottom | Unassigned | AssignedFrom _ |
                   MaybeAssignedFrom _)
    | Unassigned, (Unassigned | AssignedFrom _ | MaybeAssignedFrom _) ->
      true
    | MaybeAssignedFrom fd1, (AssignedFrom fd2 | MaybeAssignedFrom fd2)
    | AssignedFrom fd1, AssignedFrom fd2 ->
      Deps.is_included fd1 fd2
    | (Unassigned | AssignedFrom _ | MaybeAssignedFrom _), DepsBottom
    | (AssignedFrom _ | MaybeAssignedFrom _), Unassigned
    | AssignedFrom _, MaybeAssignedFrom _ ->
      false

  let bottom = DepsBottom
  let top = MaybeAssignedFrom Deps.top
  let default = Unassigned

  include DatatypeDeps

  let to_zone = function
    | DepsBottom | Unassigned -> Zone.bottom
    | AssignedFrom fd | MaybeAssignedFrom fd -> Deps.to_zone fd

  let may_be_unassigned = function
    | DepsBottom | AssignedFrom _ -> false
    | Unassigned | MaybeAssignedFrom _ -> true
end

module Memory = struct
  (** A From table is internally represented as a Lmap of [DepsOrUnassigned].
      However, the API mostly hides this fact, and exports access functions
      that take or return [Deps.t] values. This way, the user needs not
      understand the subtleties of DepsBottom/Unassigned/MaybeAssigned. *)

  include Lmap_bitwise.Make_bitwise(DepsOrUnassigned)

  (** This is the auxiliary datastructure used to write the function [find].
      When we iterate over a offsetmap of value [DepsOrUnassigned], we obtain
      two things: (1) some dependencies; (2) some intervals that may have not
      been assigned, and that will appear as data dependencies (once we know
      the base we are iterating on). *)
  type find_offsm = {
    fo_itvs: Int_Intervals.t;
    fo_deps: Deps.t;
  }

  (** Once the base is known, we can obtain something of type [Deps.t] *)
  let convert_find_offsm base fp =
    let z = Zone.inject base fp.fo_itvs in
    Deps.add_data fp.fo_deps z

  let empty_find_offsm = {
    fo_itvs = Int_Intervals.bottom;
    fo_deps = Deps.bottom;
  }

  let join_find_offsm fp1 fp2 =
    if fp1 == empty_find_offsm then fp2
    else if fp2 == empty_find_offsm then fp1
    else {
      fo_itvs = Int_Intervals.join fp1.fo_itvs fp2.fo_itvs;
      fo_deps = Deps.join fp1.fo_deps fp2.fo_deps;
    }

  (** Auxiliary function that collects the dependencies on some intervals of
      an offsetmap. *)
  let find_precise_offsetmap : Int_Intervals.t -> LOffset.t -> find_offsm =
    let cache = Hptmap_sig.PersistentCache "Function_Froms.find_precise" in
    let aux_find_offsm ib ie v =
      (* If the interval can be unassigned, we collect its bound. We also
         return the dependencies stored at this interval. *)
      let default, v = match v with
        | DepsOrUnassigned.DepsBottom -> false, Deps.bottom
        | DepsOrUnassigned.Unassigned -> true, Deps.bottom
        | DepsOrUnassigned.MaybeAssignedFrom v -> true, v
        | DepsOrUnassigned.AssignedFrom v -> false, v
      in
      { fo_itvs =
          if default
          then Int_Intervals.inject_bounds ib ie
          else Int_Intervals.bottom;
        fo_deps = v }
    in
    (* Partial application is important *)
    LOffset.fold_join_itvs
      ~cache aux_find_offsm join_find_offsm empty_find_offsm

  (** Collecting dependencies on a given zone. *)
  let find_precise : t -> Zone.t -> Deps.t =
    let both = find_precise_offsetmap in
    let conv = convert_find_offsm in
    (* We are querying a zone for which no dependency is stored. Hence, every
       base is implicitly bound to [Unassigned]. *)
    let empty_map z = Deps.data z in
    let join = Deps.join in
    let empty = Deps.bottom in
    (* Partial application is important *)
    let f = fold_join_zone ~both ~conv ~empty_map ~join ~empty in
    fun m z ->
      match m with
      | Top -> Deps.top
      | Bottom -> Deps.bottom
      | Map m -> try f z m with Abstract_interp.Error_Top -> Deps.top

  let find_precise_loffset loffset base itv =
    let fo = find_precise_offsetmap itv loffset in
    convert_find_offsm base fo

  let find z m =
    Deps.to_zone (find_precise z m)

  let add_binding_precise_loc ~exact access m loc v =
    let aux_one_loc loc m =
      let loc = Locations.valid_part access loc in
      add_binding_loc ~exact m loc (DepsOrUnassigned.AssignedFrom v)
    in
    Precise_locs.fold aux_one_loc loc m

  let add_binding ~exact m z v =
    add_binding ~exact m z (DepsOrUnassigned.AssignedFrom v)

  let add_binding_loc ~exact m loc v =
    add_binding_loc ~exact m loc (DepsOrUnassigned.AssignedFrom v)
end

type t =
  { deps_return : Deps.t;
    deps_table : Memory.t }

let top = {
  deps_return = Deps.top;
  deps_table = Memory.top;
}

let join x y =
  { deps_return = Deps.join x.deps_return y.deps_return ;
    deps_table = Memory.join x.deps_table y.deps_table }

let outputs { deps_table = t } =
  match t with
  | Memory.Top -> Locations.Zone.top
  | Memory.Bottom -> Locations.Zone.bottom
  | Memory.Map(m) ->
    Memory.fold
      (fun z v acc ->
         let open DepsOrUnassigned in
         match v with
         | DepsBottom | Unassigned -> acc
         | AssignedFrom _ | MaybeAssignedFrom _ -> Locations.Zone.join z acc)
      m Locations.Zone.bottom


let pretty fmt { deps_return = r ; deps_table = t } =
  Format.fprintf fmt "%a@\n\\result FROM @[%a@]@\n"
    Memory.pretty t
    Deps.pretty r

let hash { deps_return = dr ; deps_table = dt } =
  Memory.hash dt + 197 * Deps.hash dr

let equal
    { deps_return = dr ; deps_table = dt }
    { deps_return = dr' ; deps_table = dt' } =
  Memory.equal dt dt'&& Deps.equal dr dr'

include
  (Datatype.Make
     (struct
       type nonrec t = t
       let reprs =
         List.fold_left
           (fun acc o ->
              List.fold_left
                (fun acc m -> { deps_return = o; deps_table = m } :: acc)
                acc
                Memory.reprs)
           []
           Deps.reprs
       let structural_descr =
         Structural_descr.t_record
           [| Deps.packed_descr;
              Memory.packed_descr |]
       let name = "Function_Froms"
       let hash = hash
       let compare = Datatype.undefined
       let equal = equal
       let pretty = pretty
       let rehash = Datatype.identity
       let copy = Datatype.undefined
       let mem_project = Datatype.never_any_project
     end)
   : Datatype.S with type t := t)

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
