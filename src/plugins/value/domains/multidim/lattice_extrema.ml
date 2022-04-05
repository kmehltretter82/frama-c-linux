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

type 'a or_bottom = [`Bottom | `Value of 'a]
type 'a or_top = [`Top | `Value of 'a]
type 'a or_top_bottom = [`Top | `Bottom | `Value of 'a]

module Bot =
struct
  include Bottom.Type
  let zip x y =
    match x, y with
    | `Bottom, _ | _, `Bottom -> `Bottom
    | `Value x, `Value y -> `Value (x,y)

  (* Applicative syntax *)
  let ( let+ ) = (>>-:)
  let ( and+ ) = zip
  (* Monad syntax *)
  let ( let* ) = (>>-)
  let ( and* ) = zip
end

module Top =
struct
  let zip x y =
    match x, y with
    | `Top, _ | _, `Top -> `Top
    | `Value x, `Value y -> `Value (x,y)

  let (>>-) t f = match t with
    | `Top  -> `Top
    | `Value t -> f t

  let (>>-:) t f = match t with
    | `Top  -> `Top
    | `Value t -> `Value (f t)

  let (let+) = (>>-:)
  let (and+) = zip
  let (let*) = (>>-)
  let (and*) = zip
  let of_option = function
    | None -> `Top
    | Some v -> `Value v
end

module TopBot =
struct
  let (>>-) t f = match t with
    | `Top  -> `Top
    | `Bottom -> `Bottom
    | `Value t -> f t

  let (>>-:) t f = match t with
    | `Top  -> `Top
    | `Bottom -> `Bottom
    | `Value t -> `Value (f t)

  let (let+) = (>>-:)
  let (let*) = (>>-)
end
