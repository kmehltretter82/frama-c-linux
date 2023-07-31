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

open Cil_types
open MtIds
open MtTypes



(** Sets of zone accesses (used in cfg nodes) *)
module SetZoneAccess: sig
  include Datatype.Set with type elt = rw * Locations.Zone.t

  val pretty_sep: sep:Pretty_utils.sformat -> Format.formatter -> t -> unit
end



(** Type of a full access operation to a variable : read or write, statement at
    which the access takes place, thread that does the operation *)
module StmtIdAccess : Datatype.S with type t = rw * stmt * id

(** More than one full access to a variable. The boolean indicates
    whether all accesses are dummy ones, ie present just to ensure
    convergence of the algorithm *)
module SetStmtIdAccess: sig
  include Lattice_type.Lattice_Set with type O.elt = StmtIdAccess.t

  val pretty_aux:
    StmtIdAccess.t Pretty_utils.formatter -> t Pretty_utils.formatter
end

(** Maps from zones to variables accesses *)
module AccessesByZone: sig
  include Lmap_bitwise.Location_map_bitwise with type v = SetStmtIdAccess.t

  val pretty_map: map Pretty_utils.formatter
end
