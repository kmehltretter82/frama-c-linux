(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Server

(* Current callstack *)

module Info = struct
  let name = "Eva.Update.CurrentCallstacks"
  let dependencies = [ Self.state ]
end

module CurrentCallstacks = State_builder.List_ref (Callstack) (Info)

(* Hooks *)

let add_computation_hook f =
  Self.ComputationState.add_hook_on_change (fun _ -> f ());
  Self.ComputationState.add_hook_on_update (fun _ -> f ())

let add_callstack_hook f =
  CurrentCallstacks.add_hook_on_change (fun _ -> f ())

let add_hook f =
  add_computation_hook f;
  add_callstack_hook f

(** Eva provides information (values, taint status) about AST markers that may
    change when the computation state or the selected callstacks change. *)
let () = add_hook Server.Kernel_ast.Information.update


(* Signals *)

let package =
  let title = "Signals emitted when the analysis results have changed" in
  Package.package ~plugin:"eva" ~name:"signals" ~title ()

let signal name descr =
  let descr = Markdown.plain ("Emitted when " ^ descr) in
  Request.signal ~package ~name ~descr

let computation_signal =
  signal "computationState" "the computation state of the analysis has changed"

let callstack_signal =
  signal "currentCallstacks" "the selected callstacks have changed"

let signals = [ computation_signal; callstack_signal ]

let () =
  add_computation_hook (fun () -> Request.emit computation_signal);
  add_callstack_hook (fun () -> Request.emit callstack_signal)
