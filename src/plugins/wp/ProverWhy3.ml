(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let dkey = Wp_parameters.register_category "prover"
let dkey_pp_task = Wp_parameters.register_category "prover:pp_task"
let dkey_compile =
  Wp_parameters.register_category
    ~help:"WP -> Why3 compilation"
    "why3:compile"
let dkey_model =
  Wp_parameters.register_category
    ~help:"Counter examples model variable"
    "why3:model"

let failwith msg = Format.kasprintf failwith msg

type global = {
  env: Why3.Env.env;
  hts: (string, Why3.Ty.tysymbol) Hashtbl.t; (* types *)
  hls: (string, Why3.Term.lsymbol) Hashtbl.t; (* logics *)
  hfs: (string, Why3.Term.lsymbol) Hashtbl.t; (* fields *)
  hcs: (string, Why3.Term.lsymbol) Hashtbl.t; (* records *)
}

type context = {
  global : global ;
  cluster : Qed.Symbol.cluster ;
}

type env = {
  context : context ;
  pool : Lang.F.pool ;
  locals : Why3.Term.term Lang.F.Tmap.t ;
}

(** get symbols *)

let get_ts ctxt name =
  let data = Qed.Symbol.find_data ctxt.global.env name in
  Qed.Symbol.use ctxt.cluster @@ Qed.Symbol.Data.theory data ;
  Qed.Symbol.Data.symbol data

let get_ls ctxt name =
  let lfun  = Qed.Symbol.find_lfun ctxt.global.env name in
  Qed.Symbol.use ctxt.cluster @@ Qed.Symbol.Fun.theory lfun ;
  Qed.Symbol.Fun.symbol lfun

let t_app ctxt name tl = Why3.Term.t_app_infer (get_ls ctxt name) tl

let is_prop x =
  match x.Why3.Term.t_ty with
  | None -> false
  | Some _ -> true

let is_ty ty x =
  match x.Why3.Term.t_ty with
  | None -> false
  | Some tx -> Why3.Ty.ty_equal ty tx

let is_int = is_ty Why3.Ty.ty_int
let is_real = is_ty Why3.Ty.ty_real
let is_bool = is_ty Why3.Ty.ty_bool

let global env = {
  env ;
  hls = Hashtbl.create 0 ;
  hts = Hashtbl.create 0 ;
  hfs = Hashtbl.create 0 ;
  hcs = Hashtbl.create 0 ;
}

let context global name = {
  global ; cluster = Qed.Symbol.cluster ~path:["wp";"generated"] name ;
}

let gamma context = {
  context ;
  pool = Lang.F.pool () ;
  locals = Lang.F.Tmap.empty ;
}

let tvar =
  let tvar = Datatype.Int.Hashtbl.create 10 in
  fun i ->
    Datatype.Int.Hashtbl.memo tvar i
      (fun i ->
         let id = Why3.Ident.id_fresh (Printf.sprintf "a%i" i) in
         Why3.Ty.create_tvsymbol id)

(* -------------------------------------------------------------------------- *)
(* --- Sharing                                                            --- *)
(* -------------------------------------------------------------------------- *)

let shared (_ : Lang.F.term) = false

let shareable e =
  match Lang.F.repr e with
  | Kint _ | Kreal _ | True | False -> false
  | Times _ | Add _ | Mul _ | Div _ | Mod _ -> true
  | Eq _ | Neq _ | Leq _ | Lt _ -> false
  | Aget _ | Aset _ | Rget _ | Rdef _ | Acst _ -> true
  | And _ | Or _ | Not _ | Imply _ | If _ -> false
  | Fun _ -> not (Lang.F.is_prop e)
  | Bvar _ | Fvar _ | Apply _ | Bind _ -> false

let subterms f e =
  match Lang.F.repr e with
  | Rdef fts ->
    begin
      match Lang.F.record_with fts with
      | None -> Lang.F.lc_iter f e
      | Some(a,fts) -> f a ; List.iter (fun (_,e) -> f e) fts
    end
  | _ -> Lang.F.lc_iter f e

(* conversion *)

let cc_adt global (adt : Lang.adt) =
  try match adt with
    | Qdata a -> Qed.Symbol.Data.symbol a
    | Atype lt -> Hashtbl.find global.hts (Lang.type_id lt)
    | Comp(c,KValue) -> Hashtbl.find global.hts (Lang.comp_id c)
    | Comp(c,KInit) -> Hashtbl.find global.hts (Lang.comp_init_id c)
  with Not_found -> failwith "Unknown logic type %S" @@ Lang.ADT.fullname adt

let cc_lfun global (lf : Lang.lfun) =
  try match lf with
    | Lang.QFUN f -> Qed.Symbol.Fun.symbol f.e_symbol
    | LFUN f -> Hashtbl.find global.hls f.m_name
    | ACSL f -> Hashtbl.find global.hls (Lang.logic_id f)
    | CTOR c -> Hashtbl.find global.hls (Lang.ctor_id c)
  with Not_found -> failwith "Unknown logic symbol %S" @@ Lang.Fun.fullname lf

let is_cassoc = function Qed.Logic.Operator op -> op.associative | _ -> false

let is_assoc = function
  | Lang.QFUN f -> is_cassoc f.e_category
  | LFUN f -> is_cassoc f.m_category
  | ACSL _ | CTOR _ -> false

let rec cc_tau ctxt (t:Lang.F.tau) =
  match t with
  | Prop -> None
  | Bool -> Some Why3.Ty.ty_bool
  | Int -> Some Why3.Ty.ty_int
  | Real -> Some Why3.Ty.ty_real
  | Array(k,v) ->
    let ts = get_ts ctxt "map.Map.map" in
    Some (Why3.Ty.ty_app ts [Option.get (cc_tau ctxt k); Option.get (cc_tau ctxt v)])
  | Data(adt,l) ->
    let ts = cc_adt ctxt.global adt in
    Some (Why3.Ty.ty_app ts (List.map (fun e -> Option.get (cc_tau ctxt e)) l))
  | Tvar i -> Some (Why3.Ty.ty_var (tvar i))
  | Record _ -> failwith "Type %a not (yet) convertible" Lang.F.pp_tau t

let const_int z =
  let k = Why3.BigInt.of_string (Z.to_string z) in
  Why3.Term.t_const (Why3.Constant.int_const k) Why3.Ty.ty_int

let const_real ty ~radix ~neg ~int ?(frac="") ?exp () =
  let rc = Why3.Number.real_literal ~radix ~neg ~int ~frac ~exp in
  Why3.Term.t_const (Why3.Constant.ConstReal rc) ty

let const_rint z =
  let neg = Z.sign z < 0 in
  let int = Z.to_string (Z.abs z) in
  const_real Why3.Ty.ty_real ~radix:10 ~neg ~int ()

let const_qint env (q:Q.t) =
  let rnum = const_rint q.num in
  if Z.is_one q.den
  then rnum
  else t_app env "real.Real.(/)" [ rnum ; const_rint q.den ]

let re_float = Str.regexp
    "-?0x\\([0-9a-f]+\\).\\([0-9a-f]+\\)?0*p?\\([+-]?[0-9a-f]+\\)?$"

let const_float env fk q =
  let use_hex = true in
  let qf = Q.to_float q in
  let qf =
    match fk with
    | Ctypes.Float64 -> qf
    | Ctypes.Float32 -> Floating_point.round_to_single_precision qf
  in
  let s = Pretty_utils.to_string (Floating_point.pretty_normal ~use_hex) qf in
  let s = String.lowercase_ascii s in
  if Str.string_match re_float s 0 then
    let group n r = try Str.matched_group n r with Not_found -> "" in
    let neg = Q.sign q < 0 in
    let int,frac,exp = (group 1 s), (group 2 s), (group 3 s) in
    let exp = if String.equal exp "" then None else Some exp in
    let ts = match fk with
      | Ctypes.Float32 -> get_ts env "frama_c_wp.cfloat.Cfloat.f32"
      | Ctypes.Float64 -> get_ts env "frama_c_wp.cfloat.Cfloat.f64"
    in
    let ty = Why3.Ty.ty_app ts [] in
    const_real ty ~radix:16 ~neg ~int ~frac ?exp ()
  else invalid_arg "Wp.ProverWhy3.const_float"

let rec full_trigger = function
  | Qed.Engine.TgAny -> false
  | TgVar _ -> true
  | TgGet(a,k) -> full_trigger a && full_trigger k
  | TgSet(a,k,v) -> full_trigger a && full_trigger k && full_trigger v
  | TgFun(_,xs) | TgProp(_,xs) -> List.for_all full_trigger xs

let rec full_triggers = function
  | [] -> []
  | ts :: tgs ->
    match List.filter full_trigger ts with
    | [] -> full_triggers tgs
    | ts -> ts :: full_triggers tgs

let rec cc_trigger env t =
  match t with
  | Qed.Engine.TgAny -> assert false (* absurd: filter by full_triggers *)
  | Qed.Engine.TgVar v -> begin
      try Lang.F.Tmap.find (Lang.F.e_var v) env.locals
      with Not_found -> failwith "Unbound variable %a" Lang.F.pp_var v
    end
  | Qed.Engine.TgGet(m,k) ->
    t_app env.context "map.Map.get" [cc_trigger env m;cc_trigger env k]
  | TgSet(m,k,v) ->
    t_app env.context "mapMap.set" [cc_trigger env m;cc_trigger env k;cc_trigger env v]
  | TgFun (f,ts) | TgProp(f,ts) ->
    Why3.Term.t_app_infer (cc_lfun env.context.global f) (List.map (cc_trigger env) ts)

let t_real env u =
  if is_int u then t_app env "real.FromInt.from_int" [u] else u

let t_bool u =
  if is_prop u then u else Why3.Term.(t_equ u t_bool_true)

let t_prop u =
  if is_bool u then u else Why3.Term.(t_if u t_bool_true t_bool_false)

let hacked = Why3.Term.Hls.create 0

let rec cc env t : Why3.Term.term =
  try Lang.F.Tmap.find t env.locals with Not_found ->
  match Lang.F.repr t with
  | Fvar _ -> invalid_arg "missing free variable"
  | Bvar _ -> invalid_arg "missing bound variable"
  | Bind(q,_,_) ->
    let xs, t = cc_binders env q t in
    let quant = match q with
      | Forall -> Why3.Term.Tforall
      | Exists -> Why3.Term.Texists
      | Lambda -> assert false
    in
    Why3.Term.t_quant quant (Why3.Term.t_close_quant xs [] t)
  | True -> Why3.Term.t_true
  | False -> Why3.Term.t_false
  | Kint z -> const_int z
  | Kreal q -> const_qint env.context q
  | Times(z,t) ->
    let u = cc env t in
    if is_int u then
      t_app env.context "int.Int.(*)" [const_int z; u]
    else
      t_app env.context "real.Real.(*)" [const_rint z ; u]
  | Add ts ->
    cc_arith env ~i:"int.Int.(+)" ~r:"real.Real.(+)" ts
  | Mul ts ->
    cc_arith env ~i:"int.Int.(*)" ~r:"real.Real.(*)" ts
  | Mod(a,b) ->
    t_app env.context "int.ComputerDivision.mod" [ cc_term env a; cc_term env b ]
  | Div(a,b) ->
    cc_binop env ~i:"int.ComputerDivision.div" ~r:"real.Real.(/)" a b
  | Lt (a,b) ->
    cc_binop env ~i:"int.Int.(<)" ~r:"real.Real.(<)" a b
  | Leq (a,b) ->
    cc_binop env ~i:"int.Int.(<=)" ~r:"real.Real.(<=)" a b
  | And ts -> cc_logic env Why3.Term.Tand ts
  | Or ts -> cc_logic env Why3.Term.Tor ts
  | Imply (hs,p) -> Why3.Term.t_implies (cc_logic env Tand hs) (cc_prop env p)
  | Not e -> Why3.Term.t_not @@ cc_prop env e
  | Eq(a,b) -> cc_equal env a b
  | Neq (a,b) -> Why3.Term.t_not @@ cc_equal env a b
  | If(p,a,b) ->
    let p = cc_prop env p in
    let a = cc env a in
    let b = cc env b in
    if is_real a || is_real b then
      Why3.Term.t_if p (t_real env.context a) (t_real env.context b)
    else if is_prop a || is_prop b then
      Why3.Term.t_if p (t_prop a) (t_prop b)
    else Why3.Term.t_if p a b
  | Aget(m,k) ->
    t_app env.context "map.Map.get" [cc_term env m; cc_term env k]
  | Aset(m,k,v) ->
    t_app env.context "map.Map.set" [cc_term env m; cc_term env k; cc_term env v]
  | Acst(_,v) ->
    t_app env.context "map.Const.const" [cc_term env v]
  | Fun(f, [x]) when Lang.E.(Cfloat.fq32 @= f) ->
    begin match Lang.F.repr x with
      | Kreal q -> const_float env.context Float32 q
      | _ -> raise Not_found
    end
  | Fun(f, [x]) when Lang.E.(Cfloat.fq64 @= f) ->
    begin match Lang.F.repr x with
      | Kreal q -> const_float env.context Float32 q
      | _ -> raise Not_found
    end
  | Fun (fn,ts) ->
    begin
      try
        let ls = match fn with
          | Lang.QFUN f -> Qed.Symbol.Fun.symbol f.e_symbol
          | _ -> raise Not_found in
        let cc = Why3.Term.Hls.find hacked ls in
        let tr = Lang.F.typeof t in
        cc env tr ts
      with Not_found ->
        let ts = List.map (cc_term env) ts in
        let tr = cc_tau env.context @@ Lang.F.typeof t in
        let ls = cc_lfun env.context.global fn in
        if is_assoc fn then
          let rec foldop = function
            | [] -> failwith "Empty associative operator"
            | [a] -> a
            | a::ops -> Why3.Term.t_app ls [a;foldop ops] tr
          in foldop ts
        else
          Why3.Term.t_app ls ts tr
    end
  | Apply _ -> assert false
  | Rget _ -> assert false
  | Rdef _ -> assert false

and cc_equal env a b =
  let a = cc env a in
  let b = cc env b in
  if is_real a || is_real b then
    Why3.Term.t_equ (t_real env.context a) (t_real env.context b)
  else if is_prop a || is_prop b then
    Why3.Term.t_iff (t_prop a) (t_prop b)
  else Why3.Term.t_equ a b

and cc_prop env a = t_prop @@ cc env a
and cc_term env a = t_bool @@ cc env a
and cc_real env a = t_real env.context @@ cc env a

and cc_arith env ~i ~r = function
  | [] -> assert false
  | [x] -> cc env x
  | (y::ys) as xs ->
    if List.for_all Lang.F.is_int xs then
      let op = get_ls env.context i in
      let tr = Some Why3.Ty.ty_int in
      List.fold_left
        (fun acc y -> Why3.Term.t_app op [acc;cc env y] tr)
        (cc env y) ys
    else
      let op = get_ls env.context r in
      let tr = Some Why3.Ty.ty_real in
      List.fold_left
        (fun acc y -> Why3.Term.t_app op [acc;cc_real env y] tr)
        (cc_real env y) ys

and cc_binop env ~i ~r a b =
  let a = cc env a in
  let b = cc env b in
  if is_int a && is_int b then
    t_app env.context i [a;b]
  else
    t_app env.context r [ t_real env.context a; t_real env.context b ]

and cc_logic env op = function
  | [] -> assert false
  | [x] -> cc_prop env x
  | x::xs -> Why3.Term.t_binary op (cc_prop env x) @@ cc_logic env op xs

and cc_lets env ts =
  List.fold_left
    (fun (env,lets) e ->
       let e' = cc_term env e in
       match e'.t_ty with
       | None -> ({env with locals = Lang.F.Tmap.add e e' env.locals},lets)
       | Some ty ->
         let x = Why3.Ident.id_fresh (Lang.F.basename e) in
         let x = Why3.Term.create_vsymbol x ty in
         let env = {env with locals = Lang.F.Tmap.add e (Why3.Term.t_var x) env.locals } in
         let lets = (x,e')::lets in
         env,lets
    ) (env,[]) ts

and cc_binders env q t =
  match Lang.F.repr t with
  | Bind((Forall|Exists) as q',tau,t) when q' = q ->
    let x = Lang.F.fresh env.pool tau in
    let x' = Why3.Ident.id_fresh (Lang.F.Tau.basename tau) in
    let x' = Why3.Term.create_vsymbol x' (Option.get (cc_tau env.context tau)) in
    let locals = Lang.F.Tmap.add (Lang.F.e_var x) (Why3.Term.t_var x') env.locals in
    let env = { env with locals } in
    let t = Lang.F.QED.e_unbind x t in
    let xs, t = cc_binders env q t in
    x'::xs, t
  | _ ->
    [], compile env Qed.Logic.Prop t

and compile env tr term =
  let ts = Lang.F.QED.shared ~shareable ~shared ~subterms [term] in
  let env,letdefs = cc_lets env ts in
  let def =
    match (tr : Lang.tau) with
    | Prop -> cc_prop env term
    | Real -> cc_real env term
    | _ -> cc_term env term
  in
  List.fold_left
    (fun t (x,e') -> Why3.Term.t_let_close x e' t)
    def letdefs

let cc_params env xs =
  List.fold_left (fun (env,lets) v ->
      match cc_tau env.context (Lang.F.tau_of_var v) with
      | None -> failwith "Quantification on prop"
      | Some ty ->
        let x = Why3.Ident.id_fresh (Lang.F.Var.basename v) in
        let x = Why3.Term.create_vsymbol x ty in
        let ex = Lang.F.e_var v in
        let tx = Why3.Term.t_var x in
        let env = { env with locals = Lang.F.Tmap.add ex tx env.locals } in
        let lets = x::lets in
        env,lets
    ) (env,[]) (List.rev xs)

(** visit definitions and add them in the task *)

module CLUSTERS = WpContext.Index
    (struct
      type key = Definitions.cluster
      type data = int * Why3.Theory.theory
      let name = "ProverWhy3.CLUSTERS"
      let compare = Definitions.cluster_compare
      let pretty = Definitions.pp_cluster
    end)

class visitor ctxt c =
  object(self)

    inherit Definitions.visitor c


    (* --- Files, Theories and Clusters --- *)

    method on_cluster c =
      begin
        let name = Definitions.cluster_id c in
        Wp_parameters.debug ~dkey:dkey_compile "Start on_cluster %s@." name;
        let th_name = String.capitalize_ascii name in
        let thy =
          let age = try fst (CLUSTERS.find c) with Not_found -> (-1) in
          if age < Definitions.cluster_age c then
            let ctxt = context ctxt.global th_name in
            let v = new visitor ctxt c in v#vself;
            let th = Qed.Symbol.close ctxt.cluster in
            if Wp_parameters.(has_dkey print_generated) then
              Log.print_on_output
                begin fun fmt ->
                  Format.fprintf fmt "---------------------------------------------@\n" ;
                  Format.fprintf fmt "--- Context '%s' Cluster '%s' @\n"
                    (WpContext.get_context () |> WpContext.S.id) name;
                  Format.fprintf fmt "---------------------------------------------@\n" ;
                  Why3.Pretty.print_theory fmt th;
                end ;
            CLUSTERS.update c (Definitions.cluster_age c, th); th
          else
            snd (CLUSTERS.find c)
        in
        Qed.Symbol.use ctxt.cluster thy ;
        Wp_parameters.debug ~dkey:dkey_compile "End  on_cluster %s@." name ;
      end

    method section _ = ()

    method on_data = Qed.Symbol.use_data ctxt.cluster
    method on_lfun = Qed.Symbol.use_lfun ctxt.cluster

    method on_type lt def =
      match def with
      | Tabs ->
        let id = Why3.Ident.id_fresh (Lang.type_id lt) in
        let map i _ = tvar i in
        let tvs = List.mapi map lt.lt_params in
        let tys = Why3.Ty.create_tysymbol id tvs NoDef in
        let decl = Why3.Decl.create_ty_decl tys in
        Qed.Symbol.add ctxt.cluster decl
      | Tdef t ->
        let id = Why3.Ident.id_fresh (Lang.type_id lt) in
        let map i _ = tvar i in
        let tvs = List.mapi map lt.lt_params in
        let tdef = Option.get (cc_tau ctxt t) in
        let tys = Why3.Ty.create_tysymbol id tvs (Alias tdef) in
        let decl = Why3.Decl.create_ty_decl tys in
        Qed.Symbol.add ctxt.cluster decl
      | Tsum cases ->
        let name = Lang.type_id lt in
        let id = Why3.Ident.id_fresh name in
        let map i _ = tvar i in
        let tvs = List.mapi map lt.lt_params in
        let tys = Why3.Ty.create_tysymbol id tvs NoDef in
        Hashtbl.add ctxt.global.hts name tys ;
        let tvs = List.map Why3.Ty.ty_var tvs in
        let rty = Why3.Ty.ty_app tys tvs in
        let constr = List.length cases in
        let cases =
          List.map
            (fun (c,targs) ->
               let name = match c with Lang.CTOR c -> Lang.ctor_id c | _ -> assert false in
               let id = Why3.Ident.id_fresh name in
               let ts = List.map (fun t -> Option.get (cc_tau ctxt t)) targs in
               let ls = Why3.Term.create_fsymbol ~constr id ts rty in
               Hashtbl.add ctxt.global.hls name ls ;
               ls, List.map (fun _ -> None) ts
            ) cases in
        let decl = Why3.Decl.create_data_decl [tys,cases] in
        Qed.Symbol.add ctxt.cluster decl
      | Trec fields ->
        let name = Lang.type_id lt in
        let id = Why3.Ident.id_fresh name in
        let map i _ = tvar i in
        let tvs = List.mapi map lt.lt_params in
        let tys = Why3.Ty.create_tysymbol id tvs NoDef in
        Hashtbl.add ctxt.global.hts name tys ;
        let tvs = List.map Why3.Ty.ty_var tvs in
        let rty = Why3.Ty.ty_app tys tvs in
        let fields,args =
          List.split @@ List.map (fun (f,ty) ->
              let name = Lang.Field.name f in
              let id = Why3.Ident.id_fresh name in
              let ty = Option.get (cc_tau ctxt ty) in
              let ls = Why3.Term.create_fsymbol ~proj:true id [rty] ty in
              Hashtbl.add ctxt.global.hfs name ls ;
              Some ls,ty
            ) fields in
        let id = Why3.Ident.id_fresh (Lang.type_id lt) in
        let ctor = Why3.Term.create_fsymbol ~constr:1 id args rty in
        let decl = Why3.Decl.create_data_decl [tys,[ctor,fields]] in
        Hashtbl.add ctxt.global.hcs name ctor ;
        Qed.Symbol.add ctxt.cluster decl

    method private on_comp_gen kind c fts =
      begin
        let name = match kind with
          | Lang.KValue -> Lang.comp_id c
          | Lang.KInit -> Lang.comp_init_id c in
        let compare_field (f,_) (g,_) =
          let cmp = Lang.Field.compare f g in
          if cmp = 0 then assert false (* by definition *) else cmp
        in
        let fts = Option.map (List.sort compare_field) fts in
        let id = Why3.Ident.id_fresh name in
        let ts = Why3.Ty.create_tysymbol id [] Why3.Ty.NoDef in
        let ty = Why3.Ty.ty_app ts [] in
        let field (fd,tau) =
          let tf = cc_tau ctxt tau in
          let name = Lang.Field.name fd in
          let id = Why3.Ident.id_fresh name in
          let ls = Why3.Term.create_lsymbol ~proj:true id [ty] tf in
          Hashtbl.add ctxt.global.hfs name ls ;
          (Some ls,Option.get tf) in
        let decl =
          match fts with
          | None -> Why3.Decl.create_ty_decl ts
          | Some fts ->
            let projs,fields = List.split @@ List.map field fts in
            let id = Why3.Ident.id_fresh name in
            let ctor = Why3.Term.create_fsymbol ~constr:1 id fields ty in
            Hashtbl.add ctxt.global.hcs name ctor ;
            Why3.Decl.create_data_decl [ts,[ctor,projs]]
        in Qed.Symbol.add ctxt.cluster decl
      end

    method on_comp = self#on_comp_gen KValue
    method on_icomp = self#on_comp_gen KInit

    method private make_lemma env ?prefix (l: Definitions.dlemma) =
      let name = match prefix with
        | None -> l.l_name
        | Some p -> p ^ "_" ^ l.l_name
      in
      let id = Why3.Ident.id_fresh (Lang.lemma_id name) in
      let id = Why3.Decl.create_prsymbol id in
      List.iter (Lang.F.add_var env.pool) l.l_forall;
      let env, vars = cc_params env l.l_forall in
      let t = cc_prop env @@ Lang.F.e_prop l.l_lemma in
      let triggers = full_triggers l.l_triggers in
      let triggers = List.map (List.map (cc_trigger env)) triggers in
      let t = Why3.Term.t_forall_close vars triggers t in
      id, t

    method on_dlemma l =
      if l.l_kind <> Check then
        let kind = Why3.Decl.(if l.l_kind = Admit then Paxiom else Plemma) in
        let env = gamma ctxt in
        let pr, t = self#make_lemma env l in
        let decl = Why3.Decl.create_prop_decl kind pr t in
        Qed.Symbol.add ctxt.cluster decl

    method on_dfun d =
      Wp_parameters.debug ~dkey:dkey_compile "Define %a@." Lang.Fun.pretty d.d_lfun ;
      let name = Lang.Fun.name d.d_lfun in
      let id = Why3.Ident.id_fresh name in
      let map e = Option.get (cc_tau ctxt (Lang.F.tau_of_var e)) in
      let tvs = List.map map d.d_params in
      let env = gamma ctxt in
      List.iter (Lang.F.add_var env.pool) d.d_params;
      begin
        match d.d_definition with
        | Logic t ->
          let ls = Why3.Term.create_lsymbol id tvs (cc_tau ctxt t) in
          Hashtbl.add ctxt.global.hls name ls ;
          let decl = Why3.Decl.create_param_decl ls in
          Qed.Symbol.add ctxt.cluster decl
        | Function(tr,mu,def) ->
          begin
            let tyr = cc_tau ctxt tr in
            let ls = Why3.Term.create_lsymbol id tvs tyr in
            Hashtbl.add ctxt.global.hls name ls ;
            let env, vars = cc_params env d.d_params in
            let value = compile env tr def in
            match mu with
            | Def ->
              let defn = Why3.Decl.make_ls_defn ls vars value in
              let decl = Why3.Decl.create_logic_decl [defn] in
              Qed.Symbol.add ctxt.cluster decl
            | Rec -> (* transform recursive function into an axioms *)
              let decl = Why3.Decl.create_param_decl ls in
              Qed.Symbol.add ctxt.cluster decl ;
              let call = Why3.Term.t_app ls (List.map Why3.Term.t_var vars) tyr in
              let decl =
                Why3.Decl.create_prop_decl Why3.Decl.Paxiom
                  (Why3.Decl.create_prsymbol (Why3.Ident.id_fresh (name ^ "'def")))
                  (Why3.Term.t_forall_close vars [] (Why3.Term.t_equ call value)) in
              Qed.Symbol.add ctxt.cluster decl
          end
        | Predicate(mu,def) ->
          begin
            let ls = Why3.Term.create_lsymbol id tvs None in
            Hashtbl.add ctxt.global.hls name ls ;
            let env, vars = cc_params env d.d_params in
            let value = compile env Qed.Logic.Prop @@ Lang.F.e_prop def in
            match mu with
            | Def ->
              let defn = Why3.Decl.make_ls_defn ls vars value in
              let decl = Why3.Decl.create_logic_decl [defn] in
              Qed.Symbol.add ctxt.cluster decl
            | Rec ->
              let decl = Why3.Decl.create_param_decl ls in
              Qed.Symbol.add ctxt.cluster decl ;
              let call = Why3.Term.t_app_infer ls (List.map Why3.Term.t_var vars) in
              let decl =
                Why3.Decl.create_prop_decl Why3.Decl.Paxiom
                  (Why3.Decl.create_prsymbol (Why3.Ident.id_fresh (name^"'def")))
                  (Why3.Term.t_forall_close vars [] (Why3.Term.t_iff call value))
              in Qed.Symbol.add ctxt.cluster decl
          end
        | Inductive dcs ->
          (* create predicate symbol *)
          let ls = Why3.Term.create_lsymbol id tvs None in
          Hashtbl.add ctxt.global.hls name ls ;
          let cases =
            List.map
              (fun (lemma:Definitions.dlemma) ->
                 let env = gamma ctxt in
                 self#make_lemma env ~prefix:name lemma
              ) dcs in
          begin
            try
              let decl = Why3.Decl.(create_ind_decl Ind) [ls,cases] in
              Qed.Symbol.add ctxt.cluster decl
            with
            | Why3.Decl.InvalidIndDecl _
            | Why3.Decl.NonPositiveIndDecl _ ->
              Wp_parameters.abort
                "Ill-formed inductive declaration (non-positive premises)"
                Lang.Fun.pretty d.d_lfun
          end
      end

  end

(* -------------------------------------------------------------------------- *)
(* --- Public API                                                         --- *)
(* -------------------------------------------------------------------------- *)

module CC =
struct
  type nonrec env = env
  let tvar = tvar
  let find_ts env = get_ts env.context
  let find_ls env = get_ls env.context
  let cc_tau env = cc_tau env.context
  let cc_term = cc_term
  let cc_pred env p = cc_prop env @@ Lang.F.e_prop p
  let hack lf cc =
    match lf with
    | Lang.QFUN f ->
      Why3.Term.Hls.replace hacked (Qed.Symbol.Fun.symbol f.e_symbol) cc
    | _ -> invalid_arg "Wp.ProverWhy3.CC.hack"
end

(* -------------------------------------------------------------------------- *)
(* --- Goal Compilation                                                   --- *)
(* -------------------------------------------------------------------------- *)

let goal_id = Why3.Decl.create_prsymbol (Why3.Ident.id_fresh "wp")

let add_model_trace (probes: Lang.F.term Probe.Map.t) env t =
  let open Why3 in
  if Probe.Map.is_empty probes then t else
    let task = Task.add_meta t Driver.meta_get_counterexmp [Theory.MAstr ""] in
    let create_id (p:Probe.t) ty =
      let attr = Ident.create_model_trace_attr (string_of_int p.id) in
      let attrs = Ident.Sattr.singleton attr in
      let loc =
        let (pos1,pos2) = p.loc in
        let path = Filepos.path pos1 |> Filepath.to_string
        and l1 = Filepos.line pos1 and c1 = Filepos.input_column pos1 - 1
        and l2 = Filepos.line pos2 and c2 = Filepos.input_column pos2 - 1 in
        Why3.Loc.user_position path l1 c1 l2 c2
      in Term.create_lsymbol (Ident.id_fresh ~loc ~attrs p.name) [] ty
    in
    let fold (p:Probe.t) (t:Lang.F.term) task =
      let t = cc_term env t in
      let id = create_id p t.t_ty in
      let task = Task.add_param_decl task id in
      let eq_id = Why3.Decl.create_prsymbol (Why3.Ident.id_fresh "ce_eq") in
      let eq = Term.t_equ (Term.t_app id [] t.t_ty) t in
      let decl = Why3.Decl.create_prop_decl Paxiom eq_id eq in
      Task.add_decl task decl
    in
    Probe.Map.fold fold probes task

let convert_freevariables ~probes env t =
  let freevars = Probe.Map.fold
      (fun _ t vars -> Lang.F.Vars.union vars (Lang.F.vars t))
      probes (Lang.F.vars t) in
  let env,lss =
    Lang.F.Vars.fold (fun (v:Lang.F.Var.t) (env,lss) ->
        let ty = cc_tau env.context @@ Lang.F.tau_of_var v in
        let x = Why3.Ident.id_fresh (Lang.F.Var.basename v) in
        let ls = Why3.Term.create_lsymbol x [] ty in
        let ex = Lang.F.e_var v in
        let tx = Why3.Term.t_app ls [] ty in
        let env = { env with locals = Lang.F.Tmap.add ex tx env.locals } in
        (env,ls::lss)) freevars (env,[])
  in
  env,lss

let prove_goal ~id ~title ~name ?axioms ?(probes=Probe.Map.empty) goal =
  (* Format.printf "why3_of_qed start@."; *)
  let cg = Definitions.cluster ~id ~title () in
  let global = global @@ Why3Env.env () in
  let context = context global name in
  Wp_parameters.debug ~dkey:dkey_compile "%t"
    begin fun fmt ->
      Format.fprintf fmt "---------------------------------------------@\n" ;
      Format.fprintf fmt "EXPORT GOAL %s@." id ;
      Format.fprintf fmt "PROP @[<hov 2>%a@]@." Lang.F.pp_pred goal ;
      Format.fprintf fmt "---------------------------------------------@\n" ;
    end ;
  let v = new visitor context cg in
  v#vgoal axioms goal;
  let env = gamma context in
  let goal = Lang.F.e_prop goal in
  let env,lss = convert_freevariables ~probes env goal in
  let goal = compile env Prop goal in
  let decl = Why3.Decl.create_prop_decl Pgoal goal_id goal in
  let th = Qed.Symbol.close context.cluster in
  if Wp_parameters.(has_dkey print_generated) then begin
    Wp_parameters.debug
      ~dkey:Wp_parameters.print_generated "%a@\n%a"
      Why3.Pretty.print_theory th
      Why3.Pretty.print_decl decl
  end;
  let t = None in
  let t = Why3.Task.use_export t th in
  let t = List.fold_left Why3.Task.add_param_decl t lss in
  let t = add_model_trace probes env t in
  Why3.Task.add_decl t decl

let prove_prop ?probes ?axioms ~pid prop =
  let id = WpPropId.get_propid pid in
  let title = Pretty_utils.to_string WpPropId.pretty pid in
  let name = "WP" in
  prove_goal ?axioms ?probes ~id ~title ~name prop

let compute_probes ~ce ~pid goal =
  if ce then Wpo.GOAL.compute_probes ~pid goal else Probe.Map.empty

let task_of_wpo ~ce wpo =
  let v = wpo.Wpo.po_formula in
  let pid = wpo.Wpo.po_pid in
  let prop = Wpo.GOAL.compute_proof ~pid ~opened:ce v.goal in
  let probes = compute_probes ~ce ~pid v.goal in
  prove_prop ~pid ?axioms:v.axioms ~probes prop, probes

(* -------------------------------------------------------------------------- *)
(* --- Prover Task                                                        --- *)
(* -------------------------------------------------------------------------- *)

let prover_task env prover task =
  let config = Why3Env.config () in
  let prover_config = Why3.Whyconf.get_prover_config config prover in
  let drv = Why3.Driver.load_driver_for_prover (Why3.Whyconf.get_main config)
      env prover_config in
  drv , prover_config , Why3.Driver.prepare_task drv task

(* -------------------------------------------------------------------------- *)
(* --- Prover Call                                                        --- *)
(* -------------------------------------------------------------------------- *)

type prover_call = {
  prover : Why3Env.prover ;
  call : Why3.Call_provers.prover_call ;
  steps : int option ;
  timeout : float ;
  mutable timeover : float option ;
  mutable interrupted : bool ;
  mutable killed : bool ;
}

let has_model_attr attrs =
  Why3.Ident.Sattr.fold_left (fun acc (e:Why3.Ident.attribute) ->
      match String.remove_prefix "model_trace:" e.attr_string with
      | None -> acc
      | Some _ as a -> a
    ) None attrs

let debug_model (res:Why3.Call_provers.prover_result) =
  Wp_parameters.debug ~dkey:dkey_model "%t"
    begin fun fmt ->
      List.iter
        begin fun (res,model) ->
          Format.fprintf fmt "@[<hov 2>model %a: %a@]@\n"
            Why3.Call_provers.print_prover_answer res
            (Why3.Model_parser.print_model
               ~print_attrs:true) model
        end
        res.pr_models
    end

let get_model probes (res:Why3.Call_provers.prover_result) =
  if Wp_parameters.has_dkey dkey_model && not @@ Probe.Map.is_empty probes then
    debug_model (res:Why3.Call_provers.prover_result);
  (* we take the second model because it should be the most precise?? *)
  match Why3.Check_ce.select_model_last_non_empty res.pr_models with
  | None -> Probe.Map.empty
  | Some model ->
    let index = Hashtbl.create 0 in
    let elements = Why3.Model_parser.get_model_elements model in
    List.iter
      (fun (e:Why3.Model_parser.model_element) ->
         match has_model_attr e.me_attrs with
         | None -> ()
         | Some id -> Hashtbl.add index id e.me_concrete_value)
      elements ;
    Probe.Map.filter_map
      (fun (p:Probe.t) _ ->
         let id = string_of_int p.id in
         try Some (Hashtbl.find index id)
         with Not_found -> None
      ) probes

let ping_prover_call ~config ~probes p =
  match Why3.Call_provers.query_call p.call with
  | NoUpdates
  | ProverStarted ->
    let () =
      if p.timeout > 0.0 then
        match p.timeover with
        | None ->
          let started = Unix.time () in
          p.timeover <- Some (started +. 2.0 +. p.timeout)
        | Some timeout ->
          let time = Unix.time () in
          if time > timeout then
            begin
              Wp_parameters.debug ~dkey
                "Hard Kill (late why3server timeout)" ;
              p.interrupted <- true ;
              Why3.Call_provers.interrupt_call ~config p.call ;
            end
    in Task.Wait 100
  | InternalFailure exn ->
    let msg = Format.asprintf "@[<hov 2>%a@]"
        Why3.Exn_printer.exn_printer exn in
    Task.Return (Task.Result (VCS.failed msg))
  | ProverInterrupted -> Task.(Return Canceled)
  | ProverFinished _ when p.killed -> Task.(Return Canceled)
  | ProverFinished pr ->
    let r =
      let time = max Rformat.epsilon pr.pr_time in
      match pr.pr_answer with
      | Timeout -> VCS.timeout time
      | Valid -> VCS.result ~time ~steps:pr.pr_steps VCS.Valid
      | OutOfMemory -> VCS.failed "out of memory"
      | StepLimitExceeded -> VCS.result ?steps:p.steps VCS.Stepout
      | Invalid ->
        debug_model pr;
        VCS.result ~time:pr.pr_time ~steps:pr.pr_steps
          ~model:(get_model probes pr) VCS.Invalid
      | Unknown _ ->
        debug_model pr;
        VCS.result ~model:(get_model probes pr) VCS.Unknown
      | _ when p.interrupted -> VCS.timeout p.timeout
      | Failure msg | HighFailure msg -> VCS.failed msg
    in
    Wp_parameters.debug ~dkey
      "@[@[Why3 result for %a:@] @[%a@] and @[%a@]@."
      Why3.Whyconf.print_prover p.prover
      (Why3.Call_provers.print_prover_result ~json:false) pr
      VCS.pp_result r;
    Task.Return (Task.Result r)

let call_prover_task ~timeout ~steps ~config ~probes prover call =
  Wp_parameters.debug ~dkey "Why3 run prover %a with timeout %f, steps %d@."
    Why3.Whyconf.print_prover prover
    (Option.value ~default:(0.0) timeout)
    (Option.value ~default:0 steps) ;
  let timeout = match timeout with None -> 0.0 | Some tlimit -> tlimit in
  let pcall = {
    call ; prover ;
    killed = false ;
    interrupted = false ;
    steps ; timeout ; timeover = None ;
  } in
  let ping = function
    | Task.Kill ->
      pcall.killed <- true ;
      Why3.Call_provers.interrupt_call ~config call ;
      Task.Yield
    | Task.Coin -> ping_prover_call ~config ~probes pcall
  in
  Task.async ping

(* -------------------------------------------------------------------------- *)
(* --- Batch Prover                                                       --- *)
(* -------------------------------------------------------------------------- *)

let output_task wpo drv ?(script : Filepath.t option) prover task =
  let file =
    Wpo.DISK.file_goal ~pid:wpo.Wpo.po_pid ~model:wpo.Wpo.po_model drv prover in
  let open Filesystem.Operators in
  let$ fmt = Filesystem.with_formatter_exn file in
  let pp_header fmt msg data =
    match Filepath.extension file with
    | ".mlw" | ".why" | ".v" ->
      Format.fprintf fmt "(* %s %s *)@\n" msg data
    | ".smt2" | ".psmt2" ->
      Format.fprintf fmt "; %s %s@\n" msg data
    | _ -> ()
  in
  pp_header fmt "WP Task for Prover" @@ Why3Env.ident_why3 prover ;
  let old = Option.map
      (fun fscript ->
         let hash = Filesystem.digest fscript in
         pp_header fmt "WP Script" hash ;
         open_in (Filepath.to_string_abs fscript)
      ) script in
  let _ = Why3.Driver.print_task_prepared ?old drv fmt task in
  Option.iter close_in old


let digest_task wpo drv ?(script : Filepath.t option) prover task =
  output_task wpo drv ?script prover task;
  Filesystem.digest @@
  Wpo.DISK.file_goal ~pid:wpo.Wpo.po_pid ~model:wpo.Wpo.po_model drv prover

let run_batch pconf driver ~config
    ?(script : Filepath.t option)
    ~timeout ~steplimit ~memlimit
    ?(probes=Probe.Map.empty)
    prover task =
  let steps = match steplimit with Some 0 -> None | _ -> steplimit in
  let limits =
    let config = Why3.Whyconf.get_main @@ Why3Env.config () in
    let config_mem = Why3.Whyconf.memlimit config in
    let config_time = Why3.Whyconf.timelimit config in
    let config_steps = Why3.Call_provers.empty_limits.limit_steps in
    let limit_mem =
      if not @@ Why3Env.is_auto prover
      then 0
      else Option.value ~default:config_mem memlimit
    in
    Why3.Call_provers.{
      limit_time = Option.value ~default:config_time timeout;
      limit_steps = Option.value ~default:config_steps steps;
      limit_mem;
    } in
  let with_steps = match steps, pconf.Why3.Whyconf.command_steps with
    | None, _ -> false
    | Some _, Some _ -> true
    | Some _, None ->
      Wp_parameters.warning ~once:true ~current:false
        "%a does not support steps limit (ignored option)"
        Why3.Whyconf.print_prover prover ;
      false in
  let steps = if with_steps then steps else None in
  let command = Why3.Whyconf.get_complete_command pconf ~with_steps in
  Wp_parameters.debug ~dkey "Prover command %S" command ;
  let inplace = if script <> None then Some true else None in
  let call =
    Why3.Driver.prove_task_prepared
      ?old:(Option.map Filepath.to_string_abs script) ?inplace
      ~command ~limits ~config driver task in
  call_prover_task ~config ~timeout ~steps ~probes prover call

(* -------------------------------------------------------------------------- *)
(* --- Interactive Prover (Coq)                                           --- *)
(* -------------------------------------------------------------------------- *)

let editor_mutex = Task.mutex ()

let editor_command pconf =
  let config = Why3Env.config () in
  try
    let prover = pconf.Why3.Whyconf.prover in
    let ed_id = Why3.Whyconf.get_prover_editor config prover in
    let ed = Why3.Whyconf.editor_by_id config ed_id in
    String.concat " " (ed.editor_command :: ed.editor_options)
  with Not_found ->
    Why3.Whyconf.(default_editor (get_main config))

let scriptfile ~force ~ext wpo =
  let dir = Wp_parameters.Session.get_dir ~create_path:force "interactive" in
  Filepath.(dir / (wpo.Wpo.po_sid ^ ext))

let updatescript ~script driver task =
  let backup = Filepath.extend script ".bak" in
  Filesystem.rename script backup ;
  let _printing_info =
    let open Filesystem.Operators in
    let$ old = Filesystem.with_open_in_exn backup in
    let$ fmt = Filesystem.with_formatter_exn script in
    Why3.Driver.print_task_prepared ~old driver fmt task
  in
  if Filesystem.same_digest backup script then Filesystem.remove_file backup

let editor ~script ~merge ~config pconf driver task =
  Task.sync editor_mutex
    begin fun () ->
      Wp_parameters.feedback ~ontty:`Transient "Editing %a..."
        Filepath.pretty script ;
      if merge then updatescript ~script driver task ;
      let command = editor_command pconf in
      Wp_parameters.debug ~dkey "Editor command %S" command ;
      let probes = Probe.Map.empty in
      call_prover_task ~config ~timeout:None ~steps:None ~probes pconf.prover @@
      Why3.Call_provers.call_editor ~command ~config (Filepath.to_string_abs script)
    end

let compile ~script ~timeout ~memlimit ~config pconf driver prover task =
  run_batch ~config pconf driver ~script ~timeout ~memlimit ~steplimit:None
    ~probes:Probe.Map.empty prover task

let prepare ~mode wpo driver task =
  let ext = Filename.extension (Why3.Driver.file_of_task driver "S" "T" task) in
  let force = mode <> Prover.InteractiveMode.Batch in
  let script = scriptfile ~force wpo ~ext in
  if Filesystem.exists script then Some (script, true) else
  if force then
    begin
      let open Filesystem.Operators in
      let$ fmt = Filesystem.with_formatter_exn script in
      ignore @@ Why3.Driver.print_task_prepared driver fmt task;
      Some (script, false)
    end
  else None

let interactive ~mode ~config wpo pconf driver prover task =
  let time = Wp_parameters.InteractiveTimeout.get () in
  let mem = Wp_parameters.Memlimit.get () in
  let timeout = if time <= 0 then None else Some (float time) in
  let memlimit = if mem <= 0 then None else Some mem in
  match prepare ~mode wpo driver task with
  | None ->
    Wp_parameters.warning ~once:true ~current:false
      "Missing script(s) for prover %a.@\n\
       Use -wp-interactive=fix for interactive proving."
      Why3.Whyconf.print_prover prover ;
    Task.return VCS.unknown
  | Some (script, merge) ->
    Wp_parameters.debug ~dkey "%s %a script %S@."
      (if merge then "Found" else "New")
      Why3.Whyconf.print_prover prover (Filepath.to_string_abs script) ;
    match mode with
    | Prover.InteractiveMode.Batch ->
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
    | Update ->
      if merge then updatescript ~script driver task ;
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
    | Edit ->
      let open Task in
      editor ~script ~merge ~config pconf driver task >>= fun _ ->
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
    | Fix ->
      let open Task in
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
      >>= fun r ->
      if VCS.is_valid r then return r else
        editor ~script ~merge ~config pconf driver task >>= fun _ ->
        compile ~script ~timeout ~memlimit ~config pconf driver prover task
    | FixUpdate ->
      let open Task in
      if merge then updatescript ~script driver task ;
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
      >>= fun r ->
      if VCS.is_valid r then return r else
        let merge = false in
        editor ~script ~merge ~config pconf driver task >>= fun _ ->
        compile ~script ~timeout ~memlimit ~config pconf driver prover task

let automated ~config ~probes ~timeout ~steplimit ~memlimit
    wpo pconf drv prover task =
  if Wp_parameters.Output.exists () then output_task wpo drv prover task;
  if Probe.Map.is_empty probes then
    Cache.get_result
      ~digest:(digest_task wpo drv)
      ~runner:(run_batch ~config ~probes ~memlimit pconf drv ?script:None)
      ~timeout ~steplimit prover task
  else
    run_batch ~config ~probes ~memlimit ~timeout ~steplimit
      pconf drv prover task

(* -------------------------------------------------------------------------- *)
(* --- Prove WPO                                                          --- *)
(* -------------------------------------------------------------------------- *)

let is_trivial (t : Why3.Task.task) =
  let goal = Why3.Task.task_goal_fmla t in
  Why3.Term.t_equal goal Why3.Term.t_true

let print_debug_task wpo drv prover task =
  let pp_task fmt task =
    ignore @@ Why3.Driver.print_task_prepared drv fmt task in
  if Wp_parameters.Output.exists () then
    let out_dir =
      Wp_parameters.Output.get_dir (WpContext.MODEL.id wpo.Wpo.po_model) in
    let prover = Why3Env.title prover in
    let goal = Wpo.get_gid wpo ^ "_" ^ prover in
    let filename = Why3.Driver.file_of_task drv "" goal task in
    let file = Filepath.(out_dir / filename) in
    let out_channel = open_out (Filepath.to_string_abs file) in
    let fmt = Format.formatter_of_out_channel out_channel in
    Format.fprintf fmt "%a" pp_task task ;
    close_out out_channel
  else
    Wp_parameters.feedback "%a" pp_task task

let build_proof_task ?(mode=Prover.InteractiveMode.Batch) ?timeout ?steplimit ?memlimit
    ~prover wpo () =
  try
    (* Always generate common task *)
    let context = Wpo.get_context wpo in
    let ce,prover =
      if Wp_parameters.CounterExamples.get () then
        match Why3Env.with_counter_examples prover with
        | Some prover_ce -> true,prover_ce
        | None -> false,prover
      else false, prover in
    let task,probes = WpContext.on_context context (task_of_wpo ~ce) wpo in
    if Wp_parameters.Generate.get ()
    then Task.return VCS.no_result (* Only generate *)
    else
      let env = Why3Env.env () in
      let config = Why3.Whyconf.get_main @@ Why3Env.config () in
      let drv , pconf , task = prover_task env prover task in
      if Wp_parameters.is_debug_key_enabled dkey_pp_task then
        print_debug_task wpo drv prover task ;
      if is_trivial task then
        Task.return VCS.valid
      else
      if pconf.interactive then
        interactive ~mode ~config wpo pconf drv prover task
      else
        automated ~config ~probes ~timeout ~steplimit ~memlimit
          wpo pconf drv prover task
  with
  | Log.AbortError _ ->
    Task.failed "[User Error]"
  | Log.AbortFatal _ ->
    Task.failed "[Compilation Error]"
  | exn ->
    if Wp_parameters.has_dkey dkey_compile then
      Wp_parameters.fatal "[Why3 Error] %a@\n%s"
        Why3.Exn_printer.exn_printer exn
        Printexc.(raw_backtrace_to_string @@ get_raw_backtrace ())
    else
      Task.failed "[Why3 Error] %a" Why3.Exn_printer.exn_printer exn

let prove ?mode ?timeout ?steplimit ?memlimit ~prover wpo =
  Task.later
    (build_proof_task ?mode ?timeout ?steplimit ?memlimit ~prover wpo) ()

(* -------------------------------------------------------------------------- *)
