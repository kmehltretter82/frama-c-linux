(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Operator Names                                                     --- *)
(* -------------------------------------------------------------------------- *)

let infixes = ["infix ";"prefix ";"mixfix "]
let rec unwrap_infix s = function
  | [] -> s
  | prefix::others ->
    if String.starts_with ~prefix s then
      let n = String.length s in
      let p = String.length prefix in
      Printf.sprintf "(%s)" @@ String.sub s p (n-p)
    else unwrap_infix s others

let of_infix s = unwrap_infix s infixes

let to_infix s =
  let n = String.length s in
  if n > 2 && s.[0] = '(' && s.[n-1] = ')' then
    if String.index_opt s '[' <> None
    then "mixfix " ^ String.sub s 1 (n-2) else
    if n > 3 && s.[n-2] = '_'
    then "prefix " ^ String.sub s 1 (n-3)
    else "infix " ^ String.sub s 1 (n-2)
  else s

(* -------------------------------------------------------------------------- *)
(* --- Full Names                                                         --- *)
(* -------------------------------------------------------------------------- *)

let fullname id =
  try
    let ps,m,ns = Why3.Theory.restore_path id in
    let buffer = Buffer.create 80 in
    List.iter (Printf.bprintf buffer "%s.") ps ;
    Buffer.add_string buffer m ;
    List.iter (fun x -> Printf.bprintf buffer ".%s" @@ of_infix x) ns ;
    Buffer.contents buffer
  with Not_found -> of_infix id.id_string

(* -------------------------------------------------------------------------- *)
(* --- Why3 Symbol Generic Lookup                                         --- *)
(* -------------------------------------------------------------------------- *)

let capitalized a =
  match a.[0] with 'A'..'Z' -> true | _ | exception Invalid_argument _ -> false

let find ~kind ~lookup env name fn =
  let rec rsplit rp k =
    if name.[k] = '(' then
      rp, to_infix (String.sub name k (String.length name - k))
    else
      try
        let k' = String.index_from name k '.' in
        rsplit (String.sub name k (k'-k) :: rp) (k'+1)
      with Not_found ->
        rp , String.sub name k (String.length name - k)
  in
  let rec resolve ns m = function
    | a::rp when capitalized a -> resolve (if m = "" then ns else m::ns) a rp
    | lp ->
      try
        let th = Why3.Env.read_theory env (List.rev lp) m in
        fn th @@ lookup th.th_export ns
      with Not_found ->
        Format.kasprintf invalid_arg "Qed.Symbol.find_%s(%S)" kind name
  in
  let rp,a = rsplit [] 0 in resolve [a] "" rp

(* -------------------------------------------------------------------------- *)
(* --- Why3 Symbol Lookup                                                 --- *)
(* -------------------------------------------------------------------------- *)

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
(* --- Context                                                            --- *)
(* -------------------------------------------------------------------------- *)

type context =
  | Theory of Why3.Theory.theory
  | Cluster of { mutable closed : Why3.Theory.theory option }

type cluster = {
  ct : context ;
  mutable uc : Why3.Theory.theory_uc ;
}

let cluster ?(path=["qed";"generated"]) ?loc name =
  let ct = Cluster { closed = None } in
  let uc = Why3.Theory.create_theory ~path @@ Why3.Ident.id_fresh ?loc name in
  { ct ; uc }

let close = function
  | { ct = Theory _ } -> assert false
  | { uc ; ct = Cluster c } ->
    let th = Why3.Theory.close_theory uc in
    c.closed <- Some th ; th

let theory = function
  | Theory th | Cluster { closed = Some th } -> th
  | Cluster { closed = None } -> invalid_arg "Qed.Symbol.theory"

let iter fn = function
  | Theory th -> fn th
  | Cluster { closed } -> Option.iter fn closed

let use cluster (thy : Why3.Theory.theory) =
  if not @@ Why3.Ident.Sid.mem thy.th_name cluster.uc.uc_used then
    let name = "use'" ^ thy.th_name.id_string in
    let uc = Why3.Theory.open_scope cluster.uc name in
    let uc = Why3.Theory.use_export uc thy in
    let uc = Why3.Theory.close_scope uc ~import:false in
    cluster.uc <- uc

let add cluster decl =
  cluster.uc <- Why3.Theory.add_decl cluster.uc ~warn:false decl

(* -------------------------------------------------------------------------- *)
(* --- Abstract Data Types                                                --- *)
(* -------------------------------------------------------------------------- *)

type data = Data of {
    ct : context ;
    ts : Why3.Ty.tysymbol ;
    mutable cs : Why3.Decl.constructor list option ; (* Memoized *)
    mutable fs : field list option ; (* Memoized *)
  }

and field = Field of {
    ct : context ;
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
    let ct = Theory (find_use ~context ts.ts_name) in
    let d = Data { ts ; ct ; cs = None ; fs = None } in
    Why3.Ty.Hts.add hts ts d ; d

let find_data env name =
  let hs = hds env in
  try Hashtbl.find hs name with Not_found ->
    let d = find_ts env name of_ts in
    Hashtbl.add hs name d ; d

let constructors (Data a) =
  match a.cs with
  | Some cs -> cs
  | None ->
    let th = theory a.ct in
    let cs = try Why3.Decl.find_constructors th.th_known a.ts with _ -> [] in
    a.cs <- Some cs ; cs

let use_data cluster (Data d) = iter (use cluster) d.ct
let new_data { ct = ct } ts = Data { ct ; ts ; cs = None ; fs = None }

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
                 Field { ct = a.ct ; ls ; rank ; data }
            ) ps
        | _ -> []
      with Not_found -> []
    in a.fs <- Some fds ; fds

let find_field data fd =
  List.find (function Field f -> f.ls.ls_name.id_string = fd) @@ fields data

let field_rank (Field a) = a.rank
let by_field_rank (Field a) (Field b) = a.rank - b.rank
let record_of_field (Field a) = a.data

(* -------------------------------------------------------------------------- *)
(* --- Logic Functions & Predicates                                       --- *)
(* -------------------------------------------------------------------------- *)

type lfun = Fun of {
    ct : context ;
    ls : Why3.Term.lsymbol ;
    mutable def : (Why3.Term.vsymbol list * Why3.Term.term) option option ;
  }

let hls : lfun Why3.Term.Hls.t = Why3.Term.Hls.create 0
let hfs = Why3.Env.Wenv.memoize 0 (fun _env -> Hashtbl.create 0)

let of_ls context (ls : Why3.Term.lsymbol) =
  try Why3.Term.Hls.find hls ls with Not_found ->
    let ct = Theory (find_use ~context ls.ls_name) in
    let lfun = Fun { ls ; ct ; def = None } in
    Why3.Term.Hls.add hls ls lfun ; lfun

let find_lfun env name =
  let hs = hfs env in
  try Hashtbl.find hs name with Not_found ->
    let lfun = find_ls env name of_ls in
    Hashtbl.add hs name lfun ; lfun

let use_lfun context (Fun f) = iter (use context) f.ct
let new_lfun { ct = ct } ls = Fun { ct ; ls ; def = None }

(* -------------------------------------------------------------------------- *)
(* --- Generic Symbols                                                    --- *)
(* -------------------------------------------------------------------------- *)

module type Sid =
sig
  type t
  type symbol
  val context : t -> context
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
  val use : cluster -> t -> unit
end

module Make(S : Sid) : Symbol with type t = S.t and type symbol = S.symbol =
struct
  include S
  let hash a = Why3.Ident.id_hash (ident a)
  let equal a b = Why3.Ident.id_equal (ident a) (ident b)
  let compare a b = Why3.Ident.id_compare (ident a) (ident b)
  let name a = of_infix (ident a).id_string
  let fullname a = fullname (ident a)
  let pretty fmt a = Format.pp_print_string fmt @@ name a
  let theory a = theory @@ S.context a
  let use cluster a = iter (use cluster) @@ S.context a
end

module Data = Make
    (struct
      type t = data
      type symbol = Why3.Ty.tysymbol
      let context (Data a) = a.ct
      let symbol (Data a) = a.ts
      let ident (Data a) = a.ts.ts_name
    end)

module Field = Make
    (struct
      type t = field
      type symbol = Why3.Term.lsymbol
      let context (Field fd) = fd.ct
      let symbol (Field fd) = fd.ls
      let ident (Field fd) = fd.ls.ls_name
    end)

module Fun = Make
    (struct
      type t = lfun
      type symbol = Why3.Term.lsymbol
      let context (Fun fn) = fn.ct
      let symbol (Fun fn) = fn.ls
      let ident (Fun fn) = fn.ls.ls_name
    end)

(* -------------------------------------------------------------------------- *)
(* --- Types                                                              --- *)
(* -------------------------------------------------------------------------- *)

type tau = data Logic.datatype

module Tau =
struct
  type t = tau
  let hash = Kind.hash_tau Data.hash
  let equal = Kind.eq_tau Data.equal
  let compare = Kind.compare_tau Data.compare
  let pretty = Kind.pp_tau Kind.pp_tvar Data.pretty
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

let sort ty =
  let open Logic in
  let open Why3.Ty in
  if ty_equal ty ty_int then Sint else
  if ty_equal ty ty_bool then Sbool else
  if ty_equal ty ty_real then Sreal else
    Sdata

let osort = function None -> Logic.Sprop | Some ty -> sort ty

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

(* -------------------------------------------------------------------------- *)
(* --- Typechecking                                                       --- *)
(* -------------------------------------------------------------------------- *)

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
  of_oty ~sigma:!s (theory f.ct) f.ls.ls_value

(* -------------------------------------------------------------------------- *)
(* --- Functions                                                          --- *)
(* -------------------------------------------------------------------------- *)

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
  let th = theory f.ct in
  !r, of_oty ~sigma:!s th f.ls.ls_value,
  List.map (of_ty ~sigma:!s th) f.ls.ls_args

let definition (Fun f) =
  match f.def with
  | Some def -> def
  | None ->
    let def =
      try
        Option.map Why3.Decl.open_ls_defn @@
        Why3.Decl.find_logic_definition (theory f.ct).th_known f.ls
      with _ -> None
    in f.def <- Some def ; def

(* -------------------------------------------------------------------------- *)
(* --- Declarations                                                       --- *)
(* -------------------------------------------------------------------------- *)

let tvar = Why3.Wstdlib.Hint.memo 0 @@
  fun i ->
  Why3.Ty.create_tvsymbol @@ Why3.Ident.id_fresh @@
  String.make 1 @@ char_of_int @@ int_of_char 'a' + i mod 26

let tvars =
  Why3.Wstdlib.Hint.memo 0 @@
  fun n -> let rec vs k = if k < n then tvar k :: vs (succ k) else [] in vs 0

let new_type cluster ?loc ?(vars=0) name =
  let id = Why3.Ident.id_fresh ?loc name in
  let vs = if vars = 0 then [] else tvars vars in
  let ts = Why3.Ty.create_tysymbol id  vs NoDef in
  let { ct } = cluster in
  let data = Data { ct ; ts ; cs = None ; fs = None } in
  let decl = Why3.Decl.create_ty_decl ts in
  add cluster decl ; data

let new_datatype cluster ?loc name ctors =
  let id = Why3.Ident.id_fresh ?loc name in
  let tvs =
    Why3.Ty.Stv.elements @@
    List.fold_left
      (fun tvs (_,ts) -> List.fold_left Why3.Ty.ty_freevars tvs ts)
      Why3.Ty.Stv.empty ctors in
  let ts = Why3.Ty.create_tysymbol id tvs NoDef in
  let tr = Why3.Ty.ty_app ts (List.map Why3.Ty.ty_var tvs) in
  let constr = List.length ctors in
  let ctors : Why3.Decl.constructor list =
    List.map
      (fun (name,tys) ->
         let id = Why3.Ident.id_fresh ?loc name in
         Why3.Term.create_fsymbol ~constr id tys tr,
         List.map (fun _ -> None) tys
      ) ctors in
  let { ct } = cluster in
  let decl = Why3.Decl.create_data_decl [ts,ctors] in
  let data = Data { ct ; ts ; cs = Some ctors ; fs = None } in
  let cfs = List.map (fun (ls,_) -> Fun { ct ; ls ; def = None }) ctors in
  add cluster decl ; data, cfs

let new_record cluster ?loc name fds =
  let id = Why3.Ident.id_fresh ?loc name in
  let mk = Why3.Ident.id_fresh ?loc (name ^ "'mk") in
  let tvs =
    Why3.Ty.Stv.elements @@
    List.fold_left
      (fun tvs (_,ty) -> Why3.Ty.ty_freevars tvs ty)
      Why3.Ty.Stv.empty fds in
  let ts = Why3.Ty.create_tysymbol id tvs NoDef in
  let fts = List.map snd fds in
  let tr = Why3.Ty.ty_app ts (List.map Why3.Ty.ty_var tvs) in
  let prjs =
    List.map
      (fun (fd,ty) ->
         let id = Why3.Ident.id_fresh ?loc fd in
         let fs = Why3.Term.create_fsymbol ~proj:true id [tr] ty in
         Some fs
      ) fds in
  let { ct } = cluster in
  let data = Data { ct ; ts ; cs = None ; fs = None } in
  let fields =
    List.mapi
      (fun rank prj ->
         Field { ct ; rank ; ls = Option.get prj ; data }
      ) prjs in
  let ls = Why3.Term.create_lsymbol ~constr:1 mk fts (Some tr) in
  let record = Fun { ct ; ls ; def = None } in
  let ctors = [ls,prjs] in
  let decl = Why3.Decl.create_data_decl [ts,ctors] in
  let Data d = data in d.fs <- Some fields ; d.cs <- Some ctors ;
  add cluster decl ; data, record, fields

(* -------------------------------------------------------------------------- *)
