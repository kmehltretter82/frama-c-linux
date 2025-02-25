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

let (<?>) c other = if c = 0 then Lazy.force other else c



module Result = struct
  type log = string list
  type 'a result = Ok of 'a | Warning of 'a * log | Error of log

  module Minimal = struct
    type 'a t = 'a result
    let return v = Ok v
    let bind f result =
      match result with
      | Ok v -> f v
      | Error log -> Error log
      | Warning (v, log) ->
        match f v with
        | Ok r -> Warning (r, log)
        | Warning (r, log') -> Warning (r, log @ log')
        | Error log' -> Error (log @ log')
  end
  include Monad.Make_based_on_bind (Minimal)

  let ok v = return v
  let warning v fmt = Format.kasprintf (fun msg -> Warning (v, [msg])) fmt
  let error fmt = Format.kasprintf (fun msg -> Error [msg]) fmt

  let compare f x y =
    let compare_log = Stdlib.List.compare String.compare in
    match x, y with
    | Ok x, Ok y -> f x y
    | Ok _, (Warning _ | Error _) -> -1
    | (Warning _ | Error _), Ok _ ->  1
    | Warning (x, lx), Warning (y, ly) -> f x y <?> lazy (compare_log lx ly)
    | Warning _, Error _ -> -1
    | Error _, Warning _ ->  1
    | Error lx, Error ly -> compare_log lx ly

  let equal f x y =
    let equal_log = Stdlib.List.equal String.equal in
    match x, y with
    | Ok x, Ok y -> f x y
    | Ok _, (Warning _ | Error _) | (Warning _ | Error _), Ok _ -> false
    | Warning (x, lx), Warning (y, ly) -> f x y && equal_log lx ly
    | Warning _, Error _ | Error _, Warning _ -> false
    | Error lx, Error ly -> equal_log lx ly

  let pp_log = Format.(pp_print_list ~pp_sep:pp_print_newline pp_print_string)
  let log ~error = function
    | Ok v -> v
    | Warning (v, log) ->
      Self.warning ~current:true ~once:true "%a" pp_log log ; v
    | Error log ->
      Self.warning ~current:true ~once:true "%a" pp_log log ; error

  let value = function
    | Ok v -> v
    | Warning (v, log) ->
      Self.warning ~current:true ~once:true "%a" pp_log log ; v
    | Error log ->
      Self.fatal ~current:true "%a" pp_log log
end



type trilean = True | False | Unknown

module Trilean = struct
  include Datatype.Make_with_collections (struct
      type t = trilean
      let name = "Trilean"
      let structural_descr = Structural_descr.t_abstract
      let reprs = [ True ; False ; Unknown ]
      let rehash = Datatype.identity
      let copy = Datatype.identity
      let mem_project = Datatype.never_any_project
      let hash = function True -> 0 | False -> 1 | Unknown -> 2
      let compare x y = compare (hash x) (hash y)
      let equal x y = compare x y = 0
      let pretty fmt = function
        | True    -> Format.fprintf fmt "true"
        | False   -> Format.fprintf fmt "false"
        | Unknown -> Format.fprintf fmt "unknown"
    end)

  let top = Unknown
  let is_unknown = function Unknown -> true | _ -> false
  let is_included x y = is_unknown y || equal x y
  let intersects x y = is_unknown x || is_unknown y || equal x y
  let join x y = if equal x y then x else Unknown
  let narrow = join

  let maybe_true  = function False -> false | _ -> true
  let maybe_false = function True  -> false | _ -> true

  let of_bool = function true -> True | false -> False

  let ( && ) l r =
    match l, r with
    | True, True -> True
    | True, False | False, True | False, False -> False
    | True, Unknown | Unknown, True-> Unknown
    | False, Unknown | Unknown, False -> False
    | Unknown, Unknown -> Unknown

  let ( || ) l r =
    match l, r with
    | False, False -> False
    | True, False | False, True | True, True -> True
    | True, Unknown | Unknown, True-> True
    | False, Unknown | Unknown, False -> Unknown
    | Unknown, Unknown -> Unknown

  let not = function
    | True -> False
    | False -> True
    | Unknown -> Unknown
end



module Value = struct
  include Cvalue.V

  let zero = inject_int Z.zero

  let of_int n = Z.of_int n |> inject_int

  let to_int_list cvalue =
    try
      let ival = Cvalue.V.project_ival cvalue in
      match Ival.project_small_set ival with
      | Some l ->
        Result.ok (List.map Integer.to_int_exn l)
      | None ->
        Result.error "Too many values to enumerate, try increasing ilevel."
    with Cvalue.V.Not_based_on_null | Ival.Not_Singleton_Int ->
      Result.error "Expected thread identifier, received %a."
        Cvalue.V.pretty cvalue

  let extract_singleton cvalue =
    try Some (Cvalue.V.project_ival cvalue |> Ival.project_int |> Z.to_int)
    with Cvalue.V.Not_based_on_null | Ival.Not_Singleton_Int | Z.Overflow ->
      None

  let error_not_a_pointer_to_function value =
    Result.error "Expected@ pointer@ to function,@ received %a."
      Cvalue.V.pretty value

  let fold f cvalue x =
    try Locations.Location_Bytes.fold_i f cvalue (Result.ok x)
    with Abstract_interp.Error_Top -> error_not_a_pointer_to_function cvalue

  let get_function value var =
    try Result.ok (Globals.Functions.get var)
    with Not_found -> error_not_a_pointer_to_function value

  let extract_fun cvalue =
    let open Result.Operators in
    let add b _ival acc =
      let* acc = acc in
      match b with
      | Base.Var (v, _) ->
        let* f = get_function cvalue v in
        begin match f.fundec with
          | Definition (_, _) -> Result.ok (f :: acc)
          | Declaration (_, f, _, _) ->
            Result.error "Missing@ definition@ for function@ '%s'." f.vname
        end
      | _ -> error_not_a_pointer_to_function cvalue
    in
    fold add cvalue []
end
