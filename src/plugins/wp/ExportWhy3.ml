(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let dkey_compile =
  Wp_parameters.register_category
    ~help:"WP -> Why3 compilation"
    "why3:compile"

let failwith msg = Format.kasprintf failwith msg

type context = {
  env: Why3.Env.env;
  cluster : Qed.Symbol.cluster ;
}

type env = {
  context : context ;
  pool : Lang.F.pool ;
  locals : Why3.Term.term Lang.F.Tmap.t ;
}

(** get symbols *)

module SMAP(S : sig type data val name : string end) =
  WpContext.Index
    (struct
      type key = string
      type data = S.data
      let name = "ExportWhy3." ^ S.name
      let compare = String.compare
      let pretty = Format.pp_print_string
    end)

module TS = SMAP(struct type data = Why3.Ty.tysymbol let name = "TS" end)
module LS = SMAP(struct type data = Why3.Term.lsymbol let name = "LS" end)
module FS = SMAP(struct type data = Why3.Term.lsymbol let name = "FS" end)
module CS = SMAP(struct type data = Why3.Term.lsymbol let name = "CS" end)

let get_ts ctxt name =
  let data = Qed.Symbol.find_data ctxt.env name in
  Qed.Symbol.use ctxt.cluster @@ Qed.Symbol.Data.theory data ;
  Qed.Symbol.Data.symbol data

let get_ls ctxt name =
  let lfun  = Qed.Symbol.find_lfun ctxt.env name in
  Qed.Symbol.use ctxt.cluster @@ Qed.Symbol.Fun.theory lfun ;
  Qed.Symbol.Fun.symbol lfun

let t_app env name ?result tl =
  match result with
  | None -> Why3.Term.t_app_infer (get_ls env.context name) tl
  | Some oty -> Why3.Term.t_app (get_ls env.context name) tl oty

let is_prop x =
  match x.Why3.Term.t_ty with
  | None -> true
  | Some _ -> false

let is_ty ty x =
  match x.Why3.Term.t_ty with
  | None -> false
  | Some tx -> Why3.Ty.ty_equal ty tx

let is_int = is_ty Why3.Ty.ty_int
let is_real = is_ty Why3.Ty.ty_real

let context env name =
  let cluster = Qed.Symbol.cluster ~path:["wp";"generated"] name in
  Qed.Symbol.use cluster Why3.Theory.builtin_theory ;
  { env ; cluster }

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

let cc_adt (adt : Lang.adt) =
  try match adt with
    | Qdata a -> Qed.Symbol.Data.symbol a
    | Atype lt -> TS.find (Lang.type_id lt)
    | Comp(c,KValue) -> TS.find (Lang.comp_id c)
    | Comp(c,KInit) -> TS.find (Lang.comp_init_id c)
  with Not_found -> failwith "Undefined logic type %S" @@ Lang.ADT.fullname adt

let cc_lfun (lf : Lang.lfun) =
  try match lf with
    | Lang.QFUN f -> Qed.Symbol.Fun.symbol f.e_symbol
    | LFUN f -> LS.find f.m_name
    | ACSL f -> LS.find (Lang.logic_id f)
    | CTOR c -> LS.find (Lang.ctor_id c)
  with Not_found -> failwith "Undefined logic symbol %S" @@ Lang.Fun.fullname lf

let cc_field (fd : Lang.field) =
  try FS.find (Lang.Field.name fd)
  with Not_found -> failwith "Undefined field symbol %S" @@ Lang.Field.fullname fd

let cc_comp = function
  | [] -> assert false
  | (fd,_) :: _ ->
    try CS.find (Lang.ADT.name @@ Lang.adt_of_field fd)
    with Not_found -> failwith "Undefined record symbol for field %S" @@ Lang.Field.fullname fd

let is_cassoc = function Qed.Logic.Operator op -> op.associative | _ -> false

let is_assoc = function
  | Lang.QFUN f -> is_cassoc f.e_category
  | LFUN f -> is_cassoc f.m_category
  | ACSL _ | CTOR _ -> false

let rec cc_tau ctxt (t:Lang.F.tau) =
  match t with
  | Prop -> None
  | Int -> Some Why3.Ty.ty_int
  | Real -> Some Why3.Ty.ty_real
  | Bool ->
    Qed.Symbol.use ctxt.cluster Why3.Theory.bool_theory ; Some Why3.Ty.ty_bool
  | Array(k,v) ->
    let ts = get_ts ctxt "map.Map.map" in
    Some (Why3.Ty.ty_app ts [Option.get (cc_tau ctxt k); Option.get (cc_tau ctxt v)])
  | Data(adt,l) ->
    let ts = cc_adt adt in
    Some (Why3.Ty.ty_app ts (List.map (fun e -> Option.get (cc_tau ctxt e)) l))
  | Tvar i -> Some (Why3.Ty.ty_var (tvar i))
  | Record _ -> failwith "Type %a not (yet) convertible" Lang.F.pp_tau t

let const_int z =
  let k = Why3.BigInt.of_string (Z.to_string z) in
  Why3.Term.t_const (Why3.Constant.int_const k) Why3.Ty.ty_int

let const_rint z =
  let neg = Z.sign z < 0 in
  let int = Z.to_string (Z.abs z) in
  let rc = Why3.Number.real_literal ~radix:10 ~neg ~int ~frac:"" ~exp:None in
  Why3.Term.t_const (Why3.Constant.ConstReal rc) Why3.Ty.ty_real

let const_qint env (q:Q.t) =
  let rnum = const_rint q.num in
  if Z.is_one q.den
  then rnum
  else t_app env "real.Real.(/)" [ rnum ; const_rint q.den ]

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
    t_app env "map.Map.get" [cc_trigger env m;cc_trigger env k]
  | TgSet(m,k,v) ->
    t_app env "mapMap.set" [cc_trigger env m;cc_trigger env k;cc_trigger env v]
  | TgFun (f,ts) | TgProp(f,ts) ->
    Why3.Term.t_app_infer (cc_lfun f) (List.map (cc_trigger env) ts)

let t_real env u =
  if is_int u then t_app env "real.FromInt.from_int" [u] else u

let t_prop env u =
  if is_prop u then u else
    begin
      Qed.Symbol.use env.context.cluster Why3.Theory.bool_theory ;
      Why3.Term.(t_equ_simp u t_bool_true)
    end

let t_bool env u =
  if is_prop u then
    begin
      Qed.Symbol.use env.context.cluster Why3.Theory.bool_theory ;
      Why3.Term.(t_if_simp u t_bool_true t_bool_false)
    end
  else u

let hacked = Why3.Term.Hls.create 0

let pp_oty fmt = function
  | None -> Format.pp_print_string fmt "PROP"
  | Some ty -> Why3.Pretty.print_ty fmt ty
[@@warning "-32"]

let rec cc env t : Why3.Term.term =
  if Wp_parameters.has_dkey dkey_compile then
    try
      let r = cc_any env t in
      Wp_parameters.debug ~dkey:dkey_compile "@[<hov 2>CC %a@]@ @[<hov 2>RESULT %a : %a@]"
        Lang.F.pp_term t Why3.Pretty.print_term r pp_oty r.t_ty ; r
    with exn ->
      Wp_parameters.debug ~dkey:dkey_compile "@[<hov 2>CC %a@]@ ERROR %s@]"
        Lang.F.pp_term t (Printexc.to_string exn) ;
      raise exn
  else cc_any env t

and cc_any env t =
  try Lang.F.Tmap.find t env.locals with Not_found ->
  match Lang.F.repr t with
  | Fvar _ -> invalid_arg "missing free variable"
  | Bvar _ -> invalid_arg "missing bound variable"
  | Apply _ -> assert false
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
  | Kreal q -> const_qint env q
  | Times(z,t) ->
    let u = cc env t in
    if is_int u then
      t_app env "int.Int.(*)" [const_int z; u]
    else
      t_app env "real.Real.(*)" [const_rint z ; u]
  | Add ts ->
    cc_arith env ~i:"int.Int.(+)" ~r:"real.Real.(+)" ts
  | Mul ts ->
    cc_arith env ~i:"int.Int.(*)" ~r:"real.Real.(*)" ts
  | Mod(a,b) ->
    t_app env "frama_c_wp.cdiv.Cdiv.mod" [ cc_term env a; cc_term env b ]
  | Div(a,b) ->
    cc_binop env ~i:"frama_c_wp.cdiv.Cdiv.div" ~r:"real.Real.(/)" a b
  | Lt (a,b) ->
    cc_binop env ~i:"int.Int.(<)" ~r:"real.Real.(<)" a b
  | Leq (a,b) ->
    cc_binop env ~i:"int.Int.(<=)" ~r:"real.Real.(<=)" a b
  | And ts -> cc_logic env Why3.Term.Tand ts
  | Or ts -> cc_logic env Why3.Term.Tor ts
  | Imply (hs,p) -> cc_implies env hs (cc_prop env p)
  | Not e -> Why3.Term.t_not @@ cc_prop env e
  | Eq(a,b) -> cc_equal env a b
  | Neq (a,b) -> Why3.Term.t_not @@ cc_equal env a b
  | If(p,a,b) ->
    let p = cc_prop env p in
    let a = cc env a in
    let b = cc env b in
    if is_real a || is_real b then
      Why3.Term.t_if p (t_real env a) (t_real env b)
    else if is_prop a || is_prop b then
      Why3.Term.t_if p (t_prop env a) (t_prop env b)
    else Why3.Term.t_if p a b
  | Aget(m,k) ->
    t_app env "map.Map.get" [cc_term env m; cc_term env k]
  | Aset(m,k,v) ->
    t_app env "map.Map.set" [cc_term env m; cc_term env k; cc_term env v]
  | Acst(_,v) ->
    let result = cc_tau env.context @@ Lang.F.typeof t in
    t_app env "map.Const.const" ~result [cc_term env v]
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
        let ls = cc_lfun fn in
        let call xs =
          match ls.ls_value with
          | None -> Why3.Term.t_app_infer ls xs
          | Some _ -> Why3.Term.t_app ls xs tr
        in
        if is_assoc fn then
          let rec foldop = function
            | [] -> failwith "Empty associative operator"
            | [a] -> a
            | a::ops -> call [a;foldop ops]
          in foldop ts
        else call ts
    end
  | Rget(e,fd) ->
    Why3.Term.t_app_infer (cc_field fd) [cc_term env e]
  | Rdef fvs ->
    let ts = List.map (fun (_,v) -> cc_term env v) fvs in
    Why3.Term.t_app_infer (cc_comp fvs) ts

and cc_equal env a b =
  let a = cc env a in
  let b = cc env b in
  if is_real a || is_real b then
    Why3.Term.t_equ (t_real env a) (t_real env b)
  else if is_prop a || is_prop b then
    Why3.Term.t_iff (t_prop env a) (t_prop env b)
  else Why3.Term.t_equ a b

and cc_prop env a = t_prop env @@ cc env a
and cc_term env a = t_bool env @@ cc env a
and cc_real env a = t_real env @@ cc env a

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
    t_app env i [a;b]
  else
    t_app env r [ t_real env a; t_real env b ]

and cc_logic env op = function
  | [] -> assert false
  | [x] -> cc_prop env x
  | x::xs -> Why3.Term.t_binary op (cc_prop env x) @@ cc_logic env op xs

and cc_implies env hs p =
  match hs with
  | [] -> p
  | h::hs -> Why3.Term.t_implies (cc_prop env h) @@ cc_implies env hs p

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
      let name = "ExportWhy3.CLUSTERS"
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
            let ctxt = context ctxt.env th_name in
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
      let name = Lang.type_id lt in
      let id = Why3.Ident.id_fresh name in
      let map i _ = tvar i in
      let tvs = List.mapi map lt.lt_params in
      match def with
      | Tabs ->
        let tys = Why3.Ty.create_tysymbol id tvs NoDef in
        let decl = Why3.Decl.create_ty_decl tys in
        TS.update name tys ; Qed.Symbol.add ctxt.cluster decl
      | Tdef t ->
        let tdef = Option.get (cc_tau ctxt t) in
        let tys = Why3.Ty.create_tysymbol id tvs (Alias tdef) in
        TS.update name tys ;
        Qed.Symbol.add ctxt.cluster @@ Why3.Decl.create_ty_decl tys
      | Tsum cases ->
        let tys = Why3.Ty.create_tysymbol id tvs NoDef in
        TS.update name tys ;
        let tvs = List.map Why3.Ty.ty_var tvs in
        let rty = Why3.Ty.ty_app tys tvs in
        let constr = List.length cases in
        let cases =
          List.map
            (fun (c,targs) ->
               let name = match c with
                 | Lang.CTOR c -> Lang.ctor_id c
                 | _ -> assert false in
               let id = Why3.Ident.id_fresh name in
               let ts = List.map (fun t -> Option.get (cc_tau ctxt t)) targs in
               let ls = Why3.Term.create_fsymbol ~constr id ts rty in
               LS.update name ls ;
               ls, List.map (fun _ -> None) ts
            ) cases in
        Qed.Symbol.add ctxt.cluster @@ Why3.Decl.create_data_decl [tys,cases]
      | Trec fields ->
        let tys = Why3.Ty.create_tysymbol id tvs NoDef in
        TS.update name tys ;
        let tvs = List.map Why3.Ty.ty_var tvs in
        let rty = Why3.Ty.ty_app tys tvs in
        let fields,args =
          List.split @@ List.map (fun (f,ty) ->
              let name = Lang.Field.name f in
              let id = Why3.Ident.id_fresh name in
              let ty = Option.get (cc_tau ctxt ty) in
              let ls = Why3.Term.create_fsymbol ~proj:true id [rty] ty in
              FS.update name ls ;
              Some ls,ty
            ) fields in
        let id = Why3.Ident.id_fresh (Lang.type_id lt) in
        let ctor = Why3.Term.create_fsymbol ~constr:1 id args rty in
        CS.update name ctor ;
        Qed.Symbol.add ctxt.cluster @@
        Why3.Decl.create_data_decl [tys,[ctor,fields]]

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
          FS.update name ls ;
          (Some ls,Option.get tf) in
        let decl =
          match fts with
          | None -> Why3.Decl.create_ty_decl ts
          | Some fts ->
            let projs,fields = List.split @@ List.map field fts in
            let id = Why3.Ident.id_fresh name in
            let ctor = Why3.Term.create_fsymbol ~constr:1 id fields ty in
            CS.update name ctor ;
            Why3.Decl.create_data_decl [ts,[ctor,projs]]
        in
        TS.update name ts ;
        Qed.Symbol.add ctxt.cluster decl
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
          LS.update name ls ;
          let decl = Why3.Decl.create_param_decl ls in
          Qed.Symbol.add ctxt.cluster decl
        | Function(tr,mu,def) ->
          begin
            let tyr = cc_tau ctxt tr in
            let ls = Why3.Term.create_lsymbol id tvs tyr in
            LS.update name ls ;
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
                  (Why3.Decl.create_prsymbol (Why3.Ident.id_fresh (name ^ "_def")))
                  (Why3.Term.t_forall_close vars [] (Why3.Term.t_equ call value)) in
              Qed.Symbol.add ctxt.cluster decl
          end
        | Predicate(mu,def) ->
          begin
            let ls = Why3.Term.create_lsymbol id tvs None in
            LS.update name ls ;
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
                  (Why3.Decl.create_prsymbol (Why3.Ident.id_fresh (name^"_def")))
                  (Why3.Term.t_forall_close vars [] (Why3.Term.t_iff call value))
              in Qed.Symbol.add ctxt.cluster decl
          end
        | Inductive dcs ->
          (* create predicate symbol *)
          let ls = Why3.Term.create_lsymbol id tvs None in
          LS.update name ls ;
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
        let (pos1,pos2) = Fileloc.positions p.loc in
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

let cc_goal ~id ~title ~name ?axioms ?(probes=Probe.Map.empty) goal =
  (* Format.printf "why3_of_qed start@."; *)
  let cg = Definitions.cluster ~id ~title () in
  let env = Why3Env.env () in
  let context = context env name in
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

let cc_task ?probes ?axioms ~pid prop =
  let id = WpPropId.get_propid pid in
  let title = Pretty_utils.to_string WpPropId.pretty pid in
  let name = "WP" in
  cc_goal ?axioms ?probes ~id ~title ~name prop

(* -------------------------------------------------------------------------- *)
