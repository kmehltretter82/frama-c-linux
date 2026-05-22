(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let capitalized a =
  match a.[0] with 'A'..'Z' -> true | _ | exception Invalid_argument _ -> false

let fullname (th : Why3.Theory.theory) (id : Why3.Ident.ident) =
  let buffer = Buffer.create 80 in
  List.iter (Printf.bprintf buffer ".%s") th.th_path ;
  Printf.bprintf buffer "%s.%s" th.th_name.id_string id.id_string ;
  Buffer.contents buffer

let find ~kind ~lookup env name fn =
  let rec parse lp = function
    | [] ->
      Format.kasprintf invalid_arg "Qed: invalid why3 identifier (%S)" name
    | p::ps ->
      if capitalized p then
        try
          let t = Why3.Env.read_theory env (List.rev lp) p in
          fn t @@ lookup t.th_export ps
        with Not_found ->
          Format.kasprintf invalid_arg "Qed: %s not found (%S)" kind name
      else parse (p::lp) ps
  in parse [] @@ String.split_on_char '.' name

let find_ts e = find ~kind:"type" ~lookup:Why3.Theory.ns_find_ts e
let find_ls e = find ~kind:"function" ~lookup:Why3.Theory.ns_find_ls e
let find_pr e = find ~kind:"property" ~lookup:Why3.Theory.ns_find_pr e

(* -------------------------------------------------------------------------- *)
(* --- Abstract Data Types                                                --- *)
(* -------------------------------------------------------------------------- *)

type data = Data of {
    th : Why3.Theory.theory ;
    ts : Why3.Ty.tysymbol ;
    cs : Why3.Decl.constructor list ;
    mutable fields : field list option ; (* Memoized *)
  }

and field = Field of {
    th : Why3.Theory.theory ;
    ls : Why3.Term.lsymbol ;
    rank : int ;
    data : data ;
  }

(* -------------------------------------------------------------------------- *)
(* --- Data                                                               --- *)
(* -------------------------------------------------------------------------- *)

let data env name = find_ts env name @@ fun th ts ->
  Data {
    th ; ts ;
    fields = None ;
    cs = try Why3.Decl.find_constructors th.th_known ts with _ -> []
  }

let constructors (Data a) = a.cs

(* -------------------------------------------------------------------------- *)
(* --- Records                                                            --- *)
(* -------------------------------------------------------------------------- *)

let fields (Data a as data) =
  match a.fields with Some fds -> fds | None ->
    let fds =
      try
        match a.cs with
        | [_,ps] when a.ts.ts_args = [] ->
          List.mapi
            (fun rank p -> match p with None -> raise Not_found | Some ls ->
                 Field { th = a.th ; ls ; rank ; data }
            ) ps
        | _ -> []
      with Not_found -> []
    in a.fields <- Some fds ; fds

let field data fd =
  List.find (function Field f -> f.ls.ls_name.id_string = fd) @@ fields data

let by_field (Field a) (Field b) = b.rank - a.rank

(* -------------------------------------------------------------------------- *)
(* --- Logic Functions & Predicates                                       --- *)
(* -------------------------------------------------------------------------- *)

type lfun = Fun of {
    th : Why3.Theory.theory ;
    ls : Why3.Term.lsymbol ;
    def : Why3.Term.term option ;
  }

let lfun env name = find_ls env name @@ fun th ls ->
  Fun {
    th ; ls ;
    def =
      try
        Option.map Why3.Decl.ls_defn_axiom @@
        Why3.Decl.find_logic_definition th.th_known ls
      with _ -> None
  }

(* -------------------------------------------------------------------------- *)
(* --- Generic Symbols                                                    --- *)
(* -------------------------------------------------------------------------- *)

module type Sid =
sig
  type t
  type symbol
  val theory : t -> Why3.Theory.theory
  val symbol : t -> symbol
  val ident : t -> Why3.Ident.ident
end

module type Symbol =
sig
  type t
  type symbol
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val name : t -> string
  val fullname : t -> string
  val pretty : Format.formatter -> t -> unit
  val symbol : t -> symbol
  val ident : t -> Why3.Ident.ident
  val theory : t -> Why3.Theory.theory
end

module Make(S : Sid) : Symbol with type t = S.t and type symbol = S.symbol =
struct
  include S
  let hash a = Why3.Ident.id_hash (ident a)
  let equal a b = Why3.Ident.id_equal (ident a) (ident b)
  let compare a b = Why3.Ident.id_compare (ident a) (ident b)
  let name a = (ident a).id_string
  let fullname a = fullname (theory a) (ident a)
  let pretty fmt a = Format.pp_print_string fmt (ident a).id_string
end

module Data = Make
    (struct
      type t = data
      type symbol = Why3.Ty.tysymbol
      let theory (Data a) = a.th
      let symbol (Data a) = a.ts
      let ident (Data a) = a.ts.ts_name
    end)

module Field = Make
    (struct
      type t = field
      type symbol = Why3.Term.lsymbol
      let theory (Field fd) = fd.th
      let symbol (Field fd) = fd.ls
      let ident (Field fd) = fd.ls.ls_name
    end)

module Fun = Make
    (struct
      type t = lfun
      type symbol = Why3.Term.lsymbol
      let theory (Fun fn) = fn.th
      let symbol (Fun fn) = fn.ls
      let ident (Fun fn) = fn.ls.ls_name
    end)


(* -------------------------------------------------------------------------- *)
