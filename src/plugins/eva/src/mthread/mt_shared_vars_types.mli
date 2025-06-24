(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Mt_types



(** Sets of zone accesses (used in cfg nodes) *)
module SetZoneAccess: sig
  include Datatype.Set with type elt = rw * Locations.Zone.t

  val pretty_sep: sep:Pretty_utils.sformat -> Format.formatter -> t -> unit
end



(** Type of a full access operation to a variable : read or write, statement at
    which the access takes place, thread that does the operation *)
module StmtIdAccess : Datatype.S with type t = rw * stmt * Thread.t

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

(** Kind of protected access, read or write. *)
module AccessKind : sig
  type t = AccessRead | AccessWrite
  include Datatype.S_with_collections with type t := t
end

(** Kind of protection, unprotected, maybe protected with associated mutexes or
    fully protected with associated mutexes. *)
module ProtectionKind : sig
  type t =
    | Unprotected
    | MaybeProtected of Mutex.Set.t
    | Protected of Mutex.Set.t
  include Datatype.S_with_collections with type t := t
end

(** Protected access: the association of a kind of access and a kind of
    protection. *)
module ProtectedAccess : sig
  type t = AccessKind.t * ProtectionKind.t
  include Datatype.S_with_collections with type t := t
end

(** Set of Cil locations as [Hptset]. *)
module AccessLocationSet : Hptset.S with type elt = Cil_datatype.Location.t

(** Map of protected access to Cil locations. *)
module LocationsByAccess : sig
  include Hptmap_sig.S
    with type key = ProtectedAccess.t
     and type v = AccessLocationSet.t

  val join : t -> t -> t
end

