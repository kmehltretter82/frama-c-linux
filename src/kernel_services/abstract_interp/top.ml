(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

type 'a or_top = [ `Value of 'a | `Top ]

(** Combination *)

let zip x y =
  match x, y with
  | `Top, _ | _, `Top -> `Top
  | `Value x, `Value y -> `Value (x,y)

(** Operators *)

module Type = struct
  type 'a or_top = [ `Value of 'a | `Top ]

  let (>>-) t f = match t with
    | `Top -> `Top
    | `Value t -> f t

  let (>>-:) t f = match t with
    | `Top -> `Top
    | `Value t -> `Value (f t)

  let (let+) = (>>-:)
  let (and+) = zip
  let (let*) = (>>-)
  let (and*) = zip
end

(** Conversion. *)

let of_option = function
  | None -> `Top
  | Some x -> `Value x

let to_option = function
  | `Top -> None
  | `Value x -> Some x

(** Pretty printing. *)

let pretty_top fmt =
  Format.pp_print_string fmt (Unicode.top_string ())

let pretty pp fmt = function
  | `Top -> pretty_top fmt
  | `Value v -> pp fmt v
