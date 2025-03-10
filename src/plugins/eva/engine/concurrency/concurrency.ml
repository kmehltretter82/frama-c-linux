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

module Name = struct

  module Prototype =
  struct
    open Cil_datatype

    include Datatype.Serializable_undefined

    type t =
      | String of string
      | Integer of Integer.t
      | Pointer of Varinfo.t * OffsetStructEq.t
      | RawPointer of Varinfo.t * Integer.t (* Offset in bits *)
    [@@deriving eq, ord]

    let name = "Eva.Concurrency.Name"
    let reprs = [Integer Integer.zero]

    let pretty fmt = function
      | String s -> Format.pp_print_string fmt s
      | Integer i -> Integer.pretty fmt i
      | Pointer (v, o) ->
        Format.fprintf fmt "%a%a" Varinfo.pretty v OffsetStructEq.pretty o
      | RawPointer (v, o) ->
        Format.fprintf fmt "&%a + %a" Varinfo.pretty v Integer.pretty o

    let hash = function
      | String s -> Hashtbl.hash (1, s)
      | Integer i -> Hashtbl.hash (2, Integer.hash i)
      | Pointer (v, o) -> Hashtbl.hash (3, Varinfo.hash v, OffsetStructEq.hash o)
      | RawPointer (v, o) -> Hashtbl.hash (4, Varinfo.hash v, Integer.hash o)
  end

  include Prototype
  include Datatype.Make_with_collections (Prototype)

  let of_string s = String s

  let to_string n =
    Pretty_utils.to_string pretty n

  let of_address base i =
    match base with
    | Base.Null ->
      Some (Integer i)
    | Base.Var (vi, _) | Base.Allocated (vi, _, _) ->
      begin try
          let offset, _typ =
            Bit_utils.find_offset vi.vtype ~offset:i Bit_utils.MatchLast
          in
          Some (Pointer (vi, offset))
        with Bit_utils.NoMatchingOffset ->
          Some (RawPointer (vi, i))
      end
    | Base.String (_, Base.CSString s) when Integer.is_zero i ->
      Some (String s)
    | Base.String (_, Base.CSWstring s) when Integer.is_zero i ->
      Some (String (Escape.escape_wstring s))
    | _ -> None

  let of_cvalue cvalue =
    try
      let base, ival = Locations.Location_Bytes.find_lonely_binding cvalue in
      let byte_offset = Ival.project_int ival in
      let bits_offset = Integer.(mul byte_offset (of_int 8)) in
      of_address base bits_offset
    with Not_found | Ival.Not_Singleton_Int -> None
end
