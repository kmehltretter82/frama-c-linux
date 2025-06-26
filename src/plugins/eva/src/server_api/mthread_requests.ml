(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Server

let package =
  Package.package
    ~plugin:"eva"
    ~name:"mthread"
    ~title:"Eva Mthread Services"
    ()

module Enum (X: sig type t end) =
struct
  module Enum = Data.Enum
  let dictionary: X.t Enum.dictionary = Enum.dictionary ()
  let tag name descr = Enum.tag ~name ~descr:(Markdown.plain descr) dictionary
  let publish lookup name descr =
    Enum.set_lookup dictionary lookup;
    Request.dictionary ~package ~name ~descr:(Markdown.plain descr) dictionary
end

module Jaccess_kind = struct
  module AccessKind = Mt_shared_vars_types.AccessKind
  include Enum (struct type t = AccessKind.t end)

  let access_read = tag "read" "Read access"
  let access_write = tag "write" "Write access"

  let lookup (access_kind : AccessKind.t) =
    match access_kind with
    | AccessRead -> access_read
    | AccessWrite -> access_write

  include (val publish lookup "accessKind" "Kind of access")
end

module Jprotection_kind = struct
  module ProtectionKind = Mt_shared_vars_types.ProtectionKind
  include Enum (struct type t = ProtectionKind.t end)

  let unprotected = tag "unprotected" "Unprotected access"
  let maybe_protected = tag "maybe_protected" "Maybe protected access"
  let protected = tag "protected" "Protected access"

  let lookup (protection_kind : ProtectionKind.t) =
    match protection_kind with
    | Unprotected -> unprotected
    | MaybeProtected _ -> maybe_protected
    | Protected _ -> protected

  include (val publish lookup "protectionKind" "Kind of access protection")
end

module Jkeyed_value = Data.Jpair (Data.Jint) (Data.Jstring)
module Jlist_of_keyed_value = Data.Jlist (Jkeyed_value)

let lockset_to_keyed_stringlist lockset =
  Mutex.Set.fold
    (fun mutex acc -> (Mutex.id mutex, Mutex.label mutex) :: acc)
    lockset
    []

let mqueueset_to_keyed_stringlist mqueueset =
  Mqueue.Set.fold
    (fun mqueue acc -> (Mqueue.id mqueue, Mqueue.label mqueue) :: acc)
    mqueueset
    []

let zoneset_to_stringlist zoneset =
  Locations.Zone.Set.fold
    (fun zone acc -> Format.asprintf "%a" Locations.Zone.pretty zone :: acc)
    zoneset
    []

let _thread_summary =
  let model = States.model () in

  States.column model ~name:"thread"
    ~descr:(Markdown.plain "Thread")
    ~data:(module Jkeyed_value)
    ~get:(fun (th, _) -> Thread.id th, Thread.label th);

  States.column model ~name:"locksTaken"
    ~descr:(Markdown.plain "Locks taken by thread")
    ~data:(module Jlist_of_keyed_value)
    ~get:(fun (_, (th_summary : Mt_summary.thread_summary)) ->
        lockset_to_keyed_stringlist th_summary.locks.taken);

  States.column model ~name:"locksReleased"
    ~descr:(Markdown.plain "Locks released by thread")
    ~data:(module Jlist_of_keyed_value)
    ~get:(fun (_, (th_summary : Mt_summary.thread_summary)) ->
        lockset_to_keyed_stringlist th_summary.locks.released);

  States.column model ~name:"mqueuesCreated"
    ~descr:(Markdown.plain "Message queues created by thread")
    ~data:(module Jlist_of_keyed_value)
    ~get:(fun (_, (th_summary : Mt_summary.thread_summary)) ->
        mqueueset_to_keyed_stringlist th_summary.mqueues.created);

  States.column model ~name:"mqueuesSenders"
    ~descr:(Markdown.plain "Message queues sending some messages by thread")
    ~data:(module Jlist_of_keyed_value)
    ~get:(fun (_, (th_summary : Mt_summary.thread_summary)) ->
        mqueueset_to_keyed_stringlist th_summary.mqueues.senders);

  States.column model ~name:"mqueuesReceivers"
    ~descr:(Markdown.plain "Message queues receiving some messages by thread")
    ~data:(module Jlist_of_keyed_value)
    ~get:(fun (_, (th_summary : Mt_summary.thread_summary)) ->
        mqueueset_to_keyed_stringlist th_summary.mqueues.receivers);

  States.column model ~name:"sharedVarsRead"
    ~descr:(Markdown.plain "Shared variables read by thread")
    ~data:(module Data.Jlist (Data.Jstring))
    ~get:(fun (_, (th_summary : Mt_summary.thread_summary)) ->
        zoneset_to_stringlist th_summary.shared_vars.read);

  States.column model ~name:"sharedVarsWritten"
    ~descr:(Markdown.plain "Shared varaibles written by thread")
    ~data:(module Data.Jlist (Data.Jstring))
    ~get:(fun (_, (th_summary : Mt_summary.thread_summary)) ->
        zoneset_to_stringlist th_summary.shared_vars.written);

  States.register_framac_array
    ~package
    ~name:"mtThreadsSummary"
    ~descr:(Markdown.plain "Data for Mthread summary")
    ~key:(fun th -> Format.asprintf "%d" (Thread.id th))
    model (module Mt_summary.ThreadTable)

let _shared_var_summary =
  let open Mt_shared_vars_types in

  let model = States.model () in

  States.column model ~name:"bases"
    ~descr:(Markdown.plain "")
    ~data:(module Data.Jlist (Data.Jstring))
    ~get:(fun ((protected_access : Mt_summary.protected_access), _) ->
        let bases = Locations.Zone.get_bases protected_access.zone in
        Base.SetLattice.fold
          (fun base acc ->
             Format.asprintf "%a" Base.pretty base :: acc)
          bases
          []);

  States.column model ~name:"zones"
    ~descr:(Markdown.plain "")
    ~data:(module Data.Jstring)
    ~get:(fun ((protected_access : Mt_summary.protected_access), _) ->
        Format.asprintf "%a" Locations.Zone.pretty protected_access.zone);

  States.column model ~name:"accessKind"
    ~descr:(Markdown.plain "")
    ~data:(module Jaccess_kind)
    ~get:(fun ((protected_access : Mt_summary.protected_access), _) ->
        protected_access.access_kind);

  States.column model ~name:"protectionKind"
    ~descr:(Markdown.plain "")
    ~data:(module Jprotection_kind)
    ~get:(fun ((protected_access : Mt_summary.protected_access), _) ->
        protected_access.protection_kind);

  States.column model ~name:"protectionMutexes"
    ~descr:(Markdown.plain "")
    ~data:(module Jlist_of_keyed_value)
    ~get:(fun ((protected_access : Mt_summary.protected_access), _) ->
        match protected_access.protection_kind with
        | Unprotected -> []
        | MaybeProtected mutexes | Protected mutexes ->
          lockset_to_keyed_stringlist mutexes);

  States.column model ~name:"markers"
    ~descr:(Markdown.plain "")
    ~data:(module Data.Jlist (Kernel_ast.Marker))
    ~get:(fun (_, locations) ->
        AccessLocationSet.fold
          (fun location acc ->
             let pos = fst location in
             let marker = Printer_tag.loc_to_localizable pos in
             match marker with
             | Some marker -> marker :: acc
             | None -> acc)
          locations
          []);

  States.register_framac_array ~package
    ~name:"mtSharedVarsSummary"
    ~descr:(Markdown.plain "Data for Mthread shared var summary")
    ~key:(fun protected_access -> Format.asprintf "%a" Mt_summary.ProtectedAccessDatatype.pretty protected_access)
    model (module Mt_summary.AccessTable)
