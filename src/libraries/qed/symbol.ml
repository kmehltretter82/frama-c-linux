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
  List.iter (Printf.bprintf buffer "%s.") th.th_path ;
  Printf.bprintf buffer "%s.%s" th.th_name.id_string id.id_string ;
  Buffer.contents buffer

let find ~kind ~lookup env name fn =
  let rec parse lp = function
    | [] ->
      Format.kasprintf invalid_arg "Qed.Symbol.find(%S)" name
    | p::ps ->
      if capitalized p then
        try
          let t = Why3.Env.read_theory env (List.rev lp) p in
          fn t @@ lookup t.th_export ps
        with Not_found ->
          Format.kasprintf invalid_arg "Qed.Symbol.find_%s(%S)" kind name
      else parse (p::lp) ps
  in parse [] @@ String.split_on_char '.' name

let find_ts e = find ~kind:"type" ~lookup:Why3.Theory.ns_find_ts e
let find_ls e = find ~kind:"function" ~lookup:Why3.Theory.ns_find_ls e
let find_pr e = find ~kind:"property" ~lookup:Why3.Theory.ns_find_pr e

let rec find_use_opt id (th : Why3.Theory.theory) =
  if Why3.Ident.Sid.mem id th.th_local then Some th else
    List.find_map
      (fun (td : Why3.Theory.tdecl) ->
         match td.td_node with
         | Use th when Why3.Ident.Mid.mem id th.th_known -> find_use_opt id th
         | _ -> None
      ) th.th_decls

let find_use ~context id =
  match find_use_opt id context with
  | Some th -> th
  | None ->
    Format.kasprintf invalid_arg "Qed.Symbol.find_use(%S)" id.id_string

(* -------------------------------------------------------------------------- *)
(* --- Abstract Data Types                                                --- *)
(* -------------------------------------------------------------------------- *)

type data = Data of {
    th : Why3.Theory.theory ;
    ts : Why3.Ty.tysymbol ;
    mutable cs : Why3.Decl.constructor list option ; (* Memoized *)
    mutable fs : field list option ; (* Memoized *)
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

let hts : data Why3.Ty.Hts.t = Why3.Ty.Hts.create 0
let hds = Why3.Env.Wenv.memoize 0 (fun _env -> Hashtbl.create 0)

let of_ts context (ts : Why3.Ty.tysymbol) =
  try Why3.Ty.Hts.find hts ts with Not_found ->
    let d = Data {
        ts ; th = find_use ~context ts.ts_name ; cs = None ; fs = None
      } in Why3.Ty.Hts.add hts ts d ; d

let find_data env name =
  let hs = hds env in
  try Hashtbl.find hs name with Not_found ->
    let d = find_ts env name of_ts in
    Hashtbl.add hs name d ; d

let constructors (Data a) =
  match a.cs with
  | Some cs -> cs
  | None ->
    let cs = try Why3.Decl.find_constructors a.th.th_known a.ts with _ -> [] in
    a.cs <- Some cs ; cs

(* -------------------------------------------------------------------------- *)
(* --- Records                                                            --- *)
(* -------------------------------------------------------------------------- *)

let fields (Data a as data) =
  match a.fs with Some fds -> fds | None ->
    let cs = constructors data in
    let fds =
      try
        match cs with
        | [_,ps] when a.ts.ts_args = [] ->
          List.mapi
            (fun rank p -> match p with None -> raise Not_found | Some ls ->
                 Field { th = a.th ; ls ; rank ; data }
            ) ps
        | _ -> []
      with Not_found -> []
    in a.fs <- Some fds ; fds

let field data fd =
  List.find (function Field f -> f.ls.ls_name.id_string = fd) @@ fields data

let by_field_rank (Field a) (Field b) = b.rank - a.rank

(* -------------------------------------------------------------------------- *)
(* --- Logic Functions & Predicates                                       --- *)
(* -------------------------------------------------------------------------- *)

type lfun = Fun of {
    th : Why3.Theory.theory ;
    ls : Why3.Term.lsymbol ;
    mutable def : (Why3.Term.vsymbol list * Why3.Term.term) option option ;
  }

let hls : lfun Why3.Term.Hls.t = Why3.Term.Hls.create 0
let hfs = Why3.Env.Wenv.memoize 0 (fun _env -> Hashtbl.create 0)

let of_ls context (ls : Why3.Term.lsymbol) =
  try Why3.Term.Hls.find hls ls with Not_found ->
    let lfun = Fun { ls ; th = find_use ~context ls.ls_name ; def = None } in
    Why3.Term.Hls.add hls ls lfun ; lfun

let find_lfun env name =
  let hs = hfs env in
  try Hashtbl.find hs name with Not_found ->
    let lfun = find_ls env name of_ls in
    Hashtbl.add hs name lfun ; lfun

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
  let pretty fmt a = Format.pp_print_string fmt (fullname a)
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
(* --- Types                                                              --- *)
(* -------------------------------------------------------------------------- *)

type tau = (field,data) Logic.datatype

module Tau =
struct
  type t = tau
  let hash = Kind.hash_tau Field.hash Data.hash
  let equal = Kind.eq_tau Field.equal Data.equal
  let compare = Kind.compare_tau Field.compare Data.compare
  let pretty = Kind.pp_tau Kind.pp_tvar Field.pretty Data.pretty
end

let hty : tau Why3.Ty.Hty.t = Why3.Ty.Hty.create 32
let () =
  begin
    Why3.Ty.(Hty.add hty ty_int Int) ;
    Why3.Ty.(Hty.add hty ty_real Real) ;
    Why3.Ty.(Hty.add hty ty_bool Bool) ;
  end

type sigma = tau Why3.Ty.Mtv.t

let data (Data d as adt) = function
  | [] when Why3.Ty.(ts_equal d.ts ts_int) -> Logic.Int
  | [] when Why3.Ty.(ts_equal d.ts ts_real) -> Logic.Real
  | [] when Why3.Ty.(ts_equal d.ts ts_bool) -> Logic.Bool
  | [a;b] when Why3.Ty.(ts_equal d.ts ts_func) -> Logic.Array(a,b)
  | ts -> Logic.Data(adt, ts)

let rec of_ty context ?(sigma=Why3.Ty.Mtv.empty) ty =
  try Why3.Ty.Hty.find hty ty with Not_found ->
  match ty.ty_node with
  | Tyvar x -> Why3.Ty.Mtv.find x sigma
  | Tyapp (ts, tys) ->
    let d = of_ts context ts in
    let t = data d @@ List.map (of_ty ~sigma context) tys in
    if Why3.Ty.ty_closed ty then Why3.Ty.Hty.add hty ty t ; t

let of_oty context ?sigma = function
  | None -> Logic.Prop
  | Some ty -> of_ty ?sigma context ty

let rec unify sigma (ty : Why3.Ty.ty) (t : tau) =
  match ty.ty_node, t with
  | Tyapp(ts,[]) , Int when Why3.Ty.(ts_equal ts ts_int) -> ()
  | Tyapp(ts,[]) , Real when Why3.Ty.(ts_equal ts ts_real) -> ()
  | Tyapp(ts,[]) , Bool when Why3.Ty.(ts_equal ts ts_bool) -> ()
  | Tyapp(ts,[tyk;tyv]) , Array(tk,tv) when Why3.Ty.(ts_equal ts ts_func) ->
    unify sigma tyk tk ;
    unify sigma tyv tv ;
  | Tyapp(ts,tys) , Data(d,tvs) when Why3.Ty.ts_equal ts @@ Data.symbol d ->
    unify_all sigma tys tvs
  | Tyvar x, _ ->
    begin
      try
        let u = Why3.Ty.Mtv.find x !sigma in
        if not @@ Tau.equal u t then invalid_arg "Qed.Symbol.unify_var"
      with Not_found ->
        sigma := Why3.Ty.Mtv.add x t !sigma
    end
  | _ -> invalid_arg "Qed.Symbol.unify"

and unify_all sigma tys tvs =
  match tys , tvs with
  | [], [] -> ()
  | ty::tys , t::tvs -> unify sigma ty t ; unify_all sigma tys tvs
  | _ -> invalid_arg "Qed.Symbol.unify_all"

let unify_opt sigma oty tr =
  match oty with
  | None -> if tr <> Logic.Prop then invalid_arg "Qed.Symbol.unity_oty"
  | Some ty -> unify sigma ty tr

let apply (Fun f) ?result ts =
  let s = ref Why3.Ty.Mtv.empty in
  unify_all s f.ls.ls_args ts ;
  Option.iter (unify_opt s f.ls.ls_value) result ;
  of_oty ~sigma:!s f.th f.ls.ls_value

let signature (Fun f) =
  let r = ref 0 in
  let s = ref Why3.Ty.Mtv.empty in
  let addv tv =
    if not @@ Why3.Ty.Mtv.mem tv !s then
      let k = !r in incr r ;
      s := Why3.Ty.Mtv.add tv (Logic.Tvar k) !s in
  let rec addt (t : Why3.Ty.ty) =
    match t.ty_node with
    | Tyvar tv -> addv tv
    | Tyapp(_,ts) -> List.iter addt ts in
  Option.iter addt f.ls.ls_value ;
  List.iter addt f.ls.ls_args ;
  !r, of_oty ~sigma:!s f.th f.ls.ls_value,
  List.map (of_ty ~sigma:!s f.th) f.ls.ls_args

let definition (Fun f) =
  match f.def with
  | Some def -> def
  | None ->
    let def =
      try
        Option.map Why3.Decl.open_ls_defn @@
        Why3.Decl.find_logic_definition f.th.th_known f.ls
      with _ -> None
    in f.def <- Some def ; def

(* -------------------------------------------------------------------------- *)
