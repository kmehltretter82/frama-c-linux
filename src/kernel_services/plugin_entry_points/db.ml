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
open Cil_datatype
open Extlib

let register r f = r := f

let register_compute name deps r f =
  let name = "!Db." ^ name in
  let compute, self = State_builder.apply_once name deps f in
  r := compute;
  self

let register_guarded_compute is_computed r f =
  let compute () = if not (is_computed ()) then f () in
  r := compute

module Main = struct
  include Hook.Make()
  let play = mk_fun "Main.play"
end

module Toplevel = struct

  let run = ref (fun f -> f ())

end

(* ************************************************************************* *)
(** {2 Others plugins} *)
(* ************************************************************************* *)

module Security = struct
  let run_whole_analysis = mk_fun "Security.run_whole_analysis"
  let run_ai_analysis = mk_fun "Security.run_ai_analysis"
  let run_slicing_analysis = mk_fun "Security.run_slicing_analysis"
  let self = ref State.dummy
end

module PostdominatorsTypes = struct
  exception Top

  module type Sig = sig
    val compute: (kernel_function -> unit) ref
    val stmt_postdominators:
      (kernel_function -> stmt -> Stmt.Hptset.t) ref
    val is_postdominator:
      (kernel_function -> opening:stmt -> closing:stmt -> bool) ref
    val display: (unit -> unit) ref
    val print_dot : (string -> kernel_function -> unit) ref
  end
end


module Postdominators = struct
  let compute = mk_fun "Postdominators.compute"
  let is_postdominator
    : (kernel_function -> opening:stmt -> closing:stmt -> bool) ref
    = mk_fun "Postdominators.is_postdominator"
  let stmt_postdominators = mk_fun "Postdominators.stmt_postdominators"
  let display = mk_fun "Postdominators.display"
  let print_dot = mk_fun "Postdominators.print_dot"
end

module PostdominatorsValue = struct
  let compute = mk_fun "PostdominatorsValue.compute"
  let is_postdominator
    : (kernel_function -> opening:stmt -> closing:stmt -> bool) ref
    = mk_fun "PostdominatorsValue.is_postdominator"
  let stmt_postdominators = mk_fun "PostdominatorsValue.stmt_postdominators"
  let display = mk_fun "PostdominatorsValue.display"
  let print_dot = mk_fun "PostdominatorsValue.print_dot"
end

(* ************************************************************************* *)
(** {2 GUI} *)
(* ************************************************************************* *)

type daemon = {
  trigger : unit -> unit ;
  on_delayed : (int -> unit) option ;
  on_finished : (unit -> unit) option ;
  debounced : float ; (* in ms *)
  mutable next_at : float ; (* next trigger time *)
  mutable last_yield_at : float ; (* last yield time *)
}

(* ---- Registry ---- *)

let daemons = ref []

let on_progress ?(debounced=0) ?on_delayed ?on_finished trigger =
  let d = {
    trigger ;
    debounced = float debounced *. 0.001 ;
    on_delayed ;
    on_finished ;
    last_yield_at = 0.0 ;
    next_at = 0.0 ;
  } in
  daemons := List.append !daemons [d] ; d

let off_progress d =
  daemons := List.filter (fun d0 -> d != d0) !daemons ;
  match d.on_finished with
  | None -> ()
  | Some f -> f ()

let while_progress ?debounced ?on_delayed ?on_finished progress =
  let d : daemon option ref = ref None in
  let trigger () =
    if not @@ progress () then
      Option.iter off_progress !d
  in
  d := Some (on_progress ?debounced ?on_delayed ?on_finished trigger)

let with_progress ?debounced ?on_delayed ?on_finished trigger job data =
  let d = on_progress ?debounced ?on_delayed ?on_finished trigger in
  let result =
    try job data
    with exn ->
      off_progress d ;
      raise exn
  in
  off_progress d ; result

(* ---- Canceling ---- *)

exception Cancel

(* ---- Triggering ---- *)

let canceled = ref false
let cancel () = canceled := true

let warn_error exn =
  Kernel.failure
    "Unexpected Db.daemon exception:@\n%s"
    (Printexc.to_string exn)

let fire ~warn_on_delayed ~forced ~time d =
  if forced || time > d.next_at then
    begin
      try
        d.next_at <- time +. d.debounced ;
        d.trigger () ;
      with
      | Cancel -> canceled := true
      | exn -> warn_error exn ; raise exn
    end ;
  match d.on_delayed with
  | None -> ()
  | Some warn ->
    if warn_on_delayed && 0.0 < d.last_yield_at then
      begin
        let time_since_last_yield = time -. d.last_yield_at in
        let delay = if d.debounced > 0.0 then d.debounced else 0.1 in
        if time_since_last_yield > delay then
          warn (int_of_float (time_since_last_yield *. 1000.0)) ;
      end ;
    d.last_yield_at <- time

let raise_if_canceled () =
  if !canceled then ( canceled := false ; raise Cancel )

(* ---- Yielding ---- *)

let do_yield ~warn_on_delayed ~forced () =
  match !daemons with
  | [] -> ()
  | ds ->
    begin
      let time = Unix.gettimeofday () in
      List.iter (fire ~warn_on_delayed ~forced ~time) ds ;
      raise_if_canceled () ;
    end

let yield = do_yield ~warn_on_delayed:true ~forced:false
let flush = do_yield ~warn_on_delayed:false ~forced:true

(* ---- Sleeping ---- *)

let rec gcd a b = if b = 0 then a else gcd b (a mod b)

(* n=0 means no periodic daemons (yet) *)
let merge_period n { debounced = p } =
  if p > 0.0 then gcd (int_of_float (p *. 1000.0)) n else n

let sleep ms =
  if ms > 0 then
    let delta = float ms *. 0.001 in
    let period = List.fold_left merge_period 0 !daemons in
    if period = 0 then
      begin
        Unix.sleepf delta ;
        do_yield ~warn_on_delayed:false ~forced:false ()
      end
    else
      let delay = float period *. 0.001 in
      let finished_at = Unix.gettimeofday () +. delta in
      let rec wait_and_trigger () =
        Unix.sleepf delay ;
        let time = Unix.gettimeofday () in
        List.iter
          (fire ~warn_on_delayed:false ~forced:false ~time)
          !daemons ;
        raise_if_canceled () ;
        if time < finished_at then
          if time +. delay > finished_at then
            Unix.sleepf (finished_at -. time)
          else wait_and_trigger ()
      in
      wait_and_trigger ()

(* ************************************************************************* *)

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
