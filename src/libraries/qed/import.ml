(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type depends = Why3.Theory.Stdecl.t ref
let depends () = ref Why3.Theory.Stdecl.empty
let iter f ds = Why3.Theory.Stdecl.iter f !ds

type 'a symbol = { symbol : 'a ; decl : Why3.Theory.tdecl }
let use ds s = ds := Why3.Theory.Stdecl.add s.decl !ds ; s.symbol

let capitalized a =
  match a.[0] with 'A'..'Z' -> true | _ | exception Invalid_argument _ -> false

let find ~kind fn env name =
  let rec parse lp = function
    | [] ->
      Format.kasprintf invalid_arg "Qed: invalid why3 identifier (%S)" name
    | p::ps ->
      if capitalized p then
        try
          let th = Why3.Env.read_theory env (List.rev lp) p in
          let symbol = fn th.th_export ps in
          let decl = Why3.Theory.create_use th in
          { symbol ; decl }
        with Not_found ->
          Format.kasprintf invalid_arg "Qed: %s not found (%S)" kind name
      else parse (p::lp) ps
  in parse [] @@ String.split_on_char '.' name

let find_ts = find ~kind:"type" Why3.Theory.ns_find_ts
let find_ls = find ~kind:"function or predicate" Why3.Theory.ns_find_ls
let find_pr = find ~kind:"property" Why3.Theory.ns_find_pr
