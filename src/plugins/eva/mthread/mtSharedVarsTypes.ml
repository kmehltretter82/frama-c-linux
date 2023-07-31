(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

open MtCil
open MtIds
open MtTypes



(* Sets of zone accesses (used in cfg nodes) *)
module SetZoneAccess = struct

  module P = Datatype.Pair(RW)(Locations.Zone)

  include Datatype.Set(Set.Make(P))(P)

  let to_two_zones (s: t) =
    let aux (rw, z) (r, w) =
      match rw with
      | Read -> (Locations.Zone.join r z, w)
      | Write _ -> (r, Locations.Zone.join w z)
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

  include Datatype.Triple_with_collections(RW)(Cil_datatype.Stmt)(Id)

  let pretty fmt ((op, stmt, th) : t) =
    Format.fprintf fmt "%a@ by %a@ at %a"
      RW.pretty op Id.pretty th pretty_stmt stmt

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
