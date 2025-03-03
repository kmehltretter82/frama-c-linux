(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

open MtMemory.Types

type id_type = IdThread | IdMutex | IdQueue

let to_string = function
  | IdThread -> "thread"
  | IdMutex -> "mutex"
  | IdQueue -> "queue"

type raw_id = id_type * int

let pretty_raw_id fmt (idt, offset) =
  Format.fprintf fmt "%s_%d" (to_string idt) offset


(* YYY cache this per project *)
let array_threads = MtCil.mthread_global_var "__fc_mthread_threads"
let array_mutexes = MtCil.mthread_global_var "__fc_mthread_mutexes"
let array_queues = MtCil.mthread_global_var "__fc_mthread_queues"

let array_of_idt = function
  | IdThread -> array_threads ()
  | IdMutex -> array_mutexes ()
  | IdQueue -> array_queues ()

let pointer_of_id ((idt, offset): raw_id) : pointer =
  assert (offset > 0);
  let array = array_of_idt idt
  and offset = (offset - 1) * (Machine.sizeof_int ())
  (* Let us not lose the first cell of the array *)
  in
  array, offset


let read_id_state state raw_id =
  let p = pointer_of_id raw_id in
  MtMemory.read_int_pointer p state

let read_id_state_enumerate card state raw_id : _ MtLib.conversion =
  let value = read_id_state state raw_id in
  let failure fmt = Format.fprintf fmt "Id %a contains garbled state %a"
      pretty_raw_id raw_id Cvalue.V.pretty value
  in
  try
    match Locations.Location_Bytes.fold_i (fun b i l -> (b,i) :: l) value []
    with
    | [Base.Null,i]  -> begin
        try
          ignore (Ival.cardinal_less_than i card);
          `Success (Ival.fold_int (fun i l -> Abstract_interp.Int.to_int_exn i :: l) i [])
        with Abstract_interp.Not_less_than -> `Failure failure
      end

    | _ -> `Failure failure
  with Not_found -> `Failure failure


let write_id_state state raw_id v =
  let p = pointer_of_id raw_id in
  MtMemory.write_int_pointer p v state

let replace_id_value state raw_id ~before ~after =
  let p = pointer_of_id raw_id in
  MtMemory.replace_value_at_int_pointer p ~before ~after state

let of_thread th = IdThread, Thread.id th
let of_mutex m = IdMutex, Mutex.id m
let of_queue q = IdQueue, Mqueue.id q
