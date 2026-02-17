(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Mt_types



(* Sets of zone accesses (used in cfg nodes) *)
module SetZoneAccess = struct

  module P = Datatype.Pair(RW)(Locations.Zone)

  include Datatype.Set(Set.Make(P))(P)

  let to_two_zones (s: t) =
    let aux (rw, z) (r, w) =
      match rw with
      | Read -> (Locations.Zone.join r z, w)
      | Write _ -> (r, Locations.Zone.join w z)
      | ReadPos _ -> (Locations.Zone.join r z, w)
      | WritePos _ -> (r, Locations.Zone.join w z)
    in
    fold aux s (Locations.Zone.bottom, Locations.Zone.bottom)


  let pretty_sep ~sep fmt s =
    let r, w = to_two_zones s in
    match Locations.Zone.(is_bottom r, is_bottom w) with
    | true, true -> ()
    | false, true -> Format.fprintf fmt "reads %a" Locations.Zone.pretty r
    | true, false -> Format.fprintf fmt "writes %a" Locations.Zone.pretty w
    | false, false ->
      Format.fprintf fmt "reads %a%(%)writes %a"
        Locations.Zone.pretty r sep Locations.Zone.pretty w

  let pretty = pretty_sep ~sep:",@,"
end



module StmtIdAccess = struct

  include Datatype.Triple_with_collections(RW)(Cil_datatype.Stmt)(Thread)

  let pretty fmt ((op, stmt, th) : t) =
    let loc = Cil_datatype.Stmt.loc stmt in
    match op with
    | Read | Write _ ->
      Format.fprintf fmt "%a@ by %a@ at %a"
        RW.pretty op Thread.pretty th Printer.pp_location loc
    | ReadPos _ | WritePos _ ->
      Format.fprintf fmt "%a@ by %a@ at %a"
        RW.pretty_op op
        Thread.pretty th
        RW.pretty_loc op

end


module SetStmtIdAccess = struct
  include Abstract_interp.Make_Lattice_Set (StmtIdAccess) (StmtIdAccess.Set)

  let pretty = Pretty_utils.pp_iter ~pre:"@[<v>" ~sep:"@ " iter
      (fun fmt v -> Format.fprintf fmt "@[<hov 2>%a@]" StmtIdAccess.pretty v)
  ;;

  let pretty_aux _f = pretty

end

module AccessesByZone = struct
  include Lmap_bitwise.Make_bitwise(
    struct
      include SetStmtIdAccess
      let default = bottom
      let default_is_bottom = true
    end)

  let pretty_map fmt m =
    Format.fprintf fmt "@[<v>";
    fold_fuse_same
      (fun z s () ->
         if not (SetStmtIdAccess.(equal empty s)) then
           Format.fprintf fmt "@[<hov 2>%a:@ %a@]@ "
             Locations.Zone.pretty z (SetStmtIdAccess.pretty) s
      ) m ();
    Format.fprintf fmt "@]";
  ;;

  let pretty fmt = function
    | Top -> Format.pp_print_string fmt "TOP ACCESSES"
    | Bottom -> Format.pp_print_string fmt "BOTTOM ACCESSES"
    | Map m -> pretty_map fmt m

end

type access_kind = AccessRead | AccessWrite [@@deriving eq, ord]

module AccessKindPrototype = struct
  include Datatype.Serializable_undefined
  type t = access_kind [@@deriving eq, ord]
  let name = "Eva.Mt_shared_vars_types.AccessKind"
  let reprs = [AccessRead; AccessWrite]
  let structural_descr = Structural_descr.t_sum [| |]
  let hash = Hashtbl.hash
  let pretty fmt = function
    | AccessRead -> Format.fprintf fmt "read"
    | AccessWrite -> Format.fprintf fmt "write"
end

module AccessKind = Datatype.Make_with_collections (AccessKindPrototype)

type protection =
  | Unprotected
  | MaybeProtected of Mutex.Set.t
  | Protected of Mutex.Set.t
[@@deriving eq, ord]

module ProtectionPrototype = struct
  include Datatype.Serializable_undefined
  type t = protection [@@deriving eq, ord]
  let name = "Eva.Mt_shared_vars_types.ProtectionKind"
  let reprs = [ Unprotected ]
  let structural_descr =
    let mutex_descr = [| Mutex.Set.packed_descr |] in
    Structural_descr.t_sum [| mutex_descr; mutex_descr |]

  let hash = function
    | Unprotected -> Hashtbl.hash 0
    | MaybeProtected set -> Hashtbl.hash (1, Mutex.Set.hash set)
    | Protected set -> Hashtbl.hash (2, Mutex.Set.hash set)

  let pretty fmt = function
    | Unprotected -> Format.fprintf fmt "unprotected"
    | MaybeProtected set ->
      Format.fprintf fmt "maybe protected with %a" Mutex.Set.pretty set
    | Protected set ->
      Format.fprintf fmt "protected with %a" Mutex.Set.pretty set
end

module Protection = Datatype.Make_with_collections (ProtectionPrototype)
