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
