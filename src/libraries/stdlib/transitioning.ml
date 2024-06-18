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

(* Generated file. The file to update is [transitioning.ml.in] *)

module Seq = struct
  open Stdlib.Seq

  let mapi f seq =
    let i = ref 0 in
    map (fun x -> let y = f !i x in incr i; y) seq

  let unzip seq =
    map fst seq, map snd seq

  let is_empty xs =
    match xs () with
    | Nil -> true
    | Cons _ -> false

  let drop n xs =
    if n < 0
    then invalid_arg "Seq.drop"
    else if n = 0
    then xs
    else
      let rec aux n xs =
        match xs () with
        | Nil -> Nil
        | Cons (_, xs) ->
          let n = n - 1 in
          if n = 0
          then xs ()
          else aux n xs
      in
      fun () -> aux n xs
end
