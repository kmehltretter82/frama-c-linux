(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

open Eva_utils

open Lattice_bounds.Bottom.Operators

let frama_C_assert state actuals =
  let do_bottom () =
    warning_once_current "Frama_C_assert: false";
    Cvalue.Model.bottom
  in
  match actuals with
  | [arg_exp, arg] ->
    let state =
      if Cvalue.V.is_zero arg
      then do_bottom ()
      else if Cvalue.V.contains_zero arg
      then begin
        let state =
          let* valuation = fst (Cvalue_queries.reduce state arg_exp true) in
          let valuation = Cvalue_queries.to_domain_valuation valuation in
          Cvalue_transfer.update valuation state
        in
        match state with
        | `Value state -> warning_once_current "Frama_C_assert: unknown"; state
        | `Bottom -> do_bottom ()
      end
      else begin
        warning_once_current "Frama_C_assert: true";
        state
      end
    in
    Builtins.States [ state ]
  | _ -> raise (Builtins.Invalid_nb_of_args 1)

let () = Builtins.register_builtin "Frama_C_assert" NoCache frama_C_assert
