(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions                                                   --- *)
(* -------------------------------------------------------------------------- *)

type value =
  | E of Exp.t
  | T of Term.t
[@@ deriving eq]

type addr =
  | LV of Lval.t
  | TLV of Term_lval.t
  | ADDR of Exp.t
  | TADDR of Term.t
[@@ deriving eq]

let pp_value fmt = function
  | E e -> Format.fprintf fmt "« %a »" Printer.pp_exp e
  | T t -> Printer.pp_term fmt t

let pp_addr fmt = function
  | LV lv -> Format.fprintf fmt "« &(%a) »" Printer.pp_lval lv
  | ADDR p -> Format.fprintf fmt "« %a »" Printer.pp_exp p
  | TLV lv -> Format.fprintf fmt "&(%a)" Printer.pp_term_lval lv
  | TADDR p -> Format.fprintf fmt "%a" Printer.pp_term p

type guard =
  | Bounds of value * Z.t
  | Valid_region of (Memory.node [@ equal fun _ _ -> true]) * addr
[@@ deriving eq]

(* For Valid_region, node is precomputed from addr, hence no comparison *)

type condition =
  | Forall of Logic_var.t list * condition
  | Hyp of Predicate.t * condition
  | Let of Logic_info.t * condition
  | At of condition * Logic_label.t
  | Guard of guard
[@@ deriving eq]

let pp_guard fmt = function
  | Bounds(k,n) -> Format.fprintf fmt "0<= %a < %a" pp_value k Z.pretty n
  | Valid_region(_,a) -> Format.fprintf fmt "\\valid_region(%a)" pp_addr a

let pp_body fmt = function
  | LBterm t -> Printer.pp_term fmt t
  | _ -> Format.pp_print_string fmt "…"

let rec pp_condition fmt = function
  | Forall(xs,p) ->
    Format.fprintf fmt "@[<hov 2>" ;
    List.iter
      (fun x -> Format.fprintf fmt "\\forall %a %s;@ "
          Printer.pp_logic_type x.lv_type x.lv_name)
      xs ;
    Format.fprintf fmt "%a@]" pp_condition p ;
  | Let(l,p) ->
    Format.fprintf fmt "@[<hov 2>\\let %s = %a;@ %a@]"
      l.l_var_info.lv_name pp_body l.l_body pp_condition p
  | Hyp(h,q) ->
    Format.fprintf fmt "@[<hov 2>%a ==>@ %a" Printer.pp_predicate h pp_condition q
  | At(p,l) ->
    Format.fprintf fmt "\\at(%a,%a)" pp_condition p Printer.pp_logic_label l
  | Guard g -> pp_guard fmt g

let of_value = function
  | T t -> t
  | E e -> Logic_utils.expr_to_term ~coerce:true e

let of_addr ?loc = function
  | LV lval -> Condition.addrof ?loc lval
  | TLV lval -> Condition.taddrof ?loc lval
  | ADDR ptr -> Logic_utils.expr_to_term ~coerce:true ptr
  | TADDR ptr -> ptr

let of_guard ?loc ?names = function
  | Bounds(k,n) -> Condition.pbounds ?loc ?names (of_value k) n
  | Valid_region(_,p) -> Condition.pvalid_region ?loc ?names @@ of_addr ?loc p

let of_condition ?loc ?(names=[]) p =
  let rec generate = function
    | Guard g -> of_guard ?loc g
    | Forall(xs,p) -> Logic_const.pforall ?loc (xs,generate p)
    | Let(l,p) -> Logic_const.plet ?loc l (generate p)
    | Hyp(h,p) -> Logic_const.pimplies ?loc (h,generate p)
    | At(p,l) -> Logic_const.pat ?loc (generate p,l)
  in Logic_const.prepend_names ~names @@ generate p

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions Generator                                         --- *)
(* -------------------------------------------------------------------------- *)

type env = {
  map: Memory.map ;
  mutable context: (guard -> condition) ;
  mutable conditions : condition list ;
}

let create map =
  { map ; context = (fun g -> Guard g) ; conditions = [] }

let iter f env = List.iter f @@ List.rev env.conditions

let add env guard =
  let cond = env.context guard in
  let rec append = function
    | [] -> [cond]
    | c::_ when equal_condition c cond -> raise Exit
    | c::cs -> c::append cs in
  try env.conditions <- append env.conditions with Exit -> ()

let pointed = function
  | LV lv -> Cil.typeOfLval lv
  | TLV lv -> Logic_utils.logicCType @@ Cil.typeOfTermLval lv
  | ADDR p -> Ast_types.pointed_type @@ Cil.typeOf p
  | TADDR p -> Logic_typing.ctype_of_pointed p.term_type

(* -------------------------------------------------------------------------- *)
(* ---  Valid Conditions                                                  --- *)
(* -------------------------------------------------------------------------- *)

let valid_region env n a = add env (Valid_region(n,a))

(* -------------------------------------------------------------------------- *)
(* ---  Lval/Exp Side Conditions                                          --- *)
(* -------------------------------------------------------------------------- *)

let rec lval env (h,o) =
  let t,r = lhost env h in
  offset env true t r o

and lhost env = function
  | Var v -> v.vtype, Memory.cvar env.map v
  | Mem e ->
    let s,r = addr env e in
    if not s then valid_region env r (ADDR e) ;
    Ast_types.direct_pointed_type @@ Cil.typeOf e, r

and offset env s t r = function
  | NoOffset -> s,t,r
  | Field(fd,o) -> offset env s fd.ftype (Memory.field r fd) o
  | Index(k,o) ->
    eval env k ;
    let te = Ast_types.direct_element_type t in
    let r = Memory.index r te in
    let s =
      if Kernel.SafeArrays.get () then
        let n = Ast_info.direct_array_size t in
        add env (Bounds(E k,n)) ; s
      else false
    in offset env s te r o

and addr env e = Option.get @@ exp env e
and eval env e = ignore @@ exp env e

and exp env e =
  match e.enode with
  | AddrOf lv | StartOf lv ->
    let s,_,r = lval env lv in
    Some (s,r)
  | Lval lv ->
    let s,_,r = lval env lv in
    if not s then valid_region env r (LV lv) ;
    Option.map (fun r -> false,r) @@ Memory.points_to r
  | CastE(t,e) when
      Ast_types.is_fun_or_ptr t &&
      not (Ast_types.is_fun_or_ptr @@ Cil.typeOf e) ->
    Options.not_yet_implemented ~source:(fst e.eloc) "Integral to pointer casts"
  | CastE(_,e) ->
    Option.map (fun (_,r) -> false,r) @@ exp env e
  | BinOp((PlusPI|MinusPI),p,k,_) ->
    eval env k ;
    Option.map (fun (_,r) -> false,r) @@ exp env p
  | BinOp(_,a,b,_) ->
    eval env a ; eval env b ; None
  | UnOp((Neg|BNot|LNot),e, _) -> eval env e ; None
  | Const _ | SizeOf _ | SizeOfE _ | AlignOf (_, _) | AlignOfE (_, _) -> None

let write env lv =
  let s,_,r = lval env lv in
  if not s then valid_region env r (LV lv)

(* -------------------------------------------------------------------------- *)
(* --- Code Side Conditions                                               --- *)
(* -------------------------------------------------------------------------- *)

let rec init env = function
  | SingleInit e -> eval env e
  | CompoundInit(_,ofs) -> List.iter (fun (_,i) -> init env i) ofs

let called env = function
  | Var _vf -> ()
  | Mem e -> eval env e

let instr env = function
  | Set(lv,e,_) ->
    eval env e ;
    write env lv ;
  | Call(r,f,es,_) ->
    called env f ;
    List.iter (eval env) es ;
    Option.iter (write env) r
  | Local_init(_,AssignInit i,_) -> init env i
  | Local_init(_,ConsInit(_,es,_),_) -> List.iter (eval env) es
  | Asm _ | Skip _ | Code_annot _ -> ()

let rec stmtkind env = function
  | Instr i -> instr env i
  | Return(r,_) -> Option.iter (eval env) r
  | If(e,_,_,_) | Switch(e,_,_,_)| Throw (Some(e,_),_) -> eval env e
  | Goto _ | Break _ | Continue _ | Loop _ | Block _
  | Throw(None,_) | TryCatch _ | TryFinally _ -> ()
  | TryExcept(_,(ks,e),_,_) -> List.iter (instr env) ks ; eval env e
  | UnspecifiedSequence us ->
    let b = Cil.block_from_unspecified_sequence us in
    List.iter (fun s -> stmtkind env s.skind) b.bstmts

(* -------------------------------------------------------------------------- *)
(* --- Logic Labels                                                       --- *)
(* -------------------------------------------------------------------------- *)

let forall env xs job prm =
  if xs = [] then job prm else
    let context = env.context in
    env.context <- (fun p -> Forall(xs,context p)) ;
    let r = job prm in env.context <- context ; r

let assume env h job prm =
  let context = env.context in
  env.context <- (fun p -> Hyp(h,context p)) ;
  let r = job prm in env.context <- context ; r

let plet env l job prm =
  let context = env.context in
  env.context <- (fun p -> Let(l,context p)) ;
  let r = job prm in env.context <- context ; r

(* -------------------------------------------------------------------------- *)
(* --- Logic Annotations (Non-Generated by Default)                       --- *)
(* -------------------------------------------------------------------------- *)

type domain = LOC of Memory.node | VAL of Memory.domain

let rec term_lval env (h,o) : domain =
  match h with
  | TVar { lv_origin = Some v } ->
    term_coffset env v.vtype (Memory.cvar env.map v) o
  | TResult tr ->
    term_coffset env tr (Option.get @@ Memory.result env.map) o
  | TMem p ->
    let r = term_addr env p in
    let t = Logic_typing.ctype_of_pointed p.term_type in
    term_coffset env t r o
  | TVar v ->
    term_loffset env (Memory.lvar env.map v) o

and term_loffset env d = function
  | TNoOffset -> VAL d
  | TField(fd,o) -> term_loffset env (Domain.get_field min d fd) o
  | TIndex(k,o) -> term_eval env k ; term_loffset env (Domain.get_index min d) o
  | TModel _-> Options.not_yet_implemented "Model fields"

and term_coffset env t r = function
  | TNoOffset -> LOC r
  | TField(fd,o) -> term_coffset env fd.ftype (Memory.field r fd) o
  | TIndex(k,o) ->
    term_eval env k ;
    let te = Ast_types.direct_element_type t in
    let r = Memory.index r te in
    begin
      if Kernel.SafeArrays.get () then
        let n = Ast_info.direct_array_size t in
        add env (Bounds(T k,n))
    end ;
    term_coffset env te r o
  | TModel _ -> Options.not_yet_implemented "Model fields"

and term_eval env t = ignore @@ term env t
and term_addr env t = Option.get @@ Domain.pointed min @@ term env t

and term env t =
  match t.term_node with
  | TLval lv ->
    begin
      match term_lval env lv with
      | VAL d -> d
      | LOC r ->
        valid_region env r (TLV lv) ;
        Domain.scalar @@ Memory.points_to r
    end
  | TAddrOf lv | TStartOf lv ->
    begin
      match term_lval env lv with
      | VAL _ -> assert false
      | LOC r -> Domain.ptr r
    end
  | TBinOp((PlusPI|MinusPI),p,k) ->
    let r = term env p in
    term_eval env k ; r
  | TBinOp(_,a,b) -> term_eval env a ; term_eval env b ; Domain.pure
  | Trange(a,b) ->
    Option.iter (term_eval env) a ;
    Option.iter (term_eval env) b ;
    Domain.pure
  | Tapp(f,_,ts) -> Logic.call env.map f @@ List.map (term env) ts
  | TDataCons(c,ts) -> Logic.cons env.map c @@ List.map (term env) ts
  | TCast(_,Ctype pt,e) when
      Ast_types.is_fun_or_ptr pt &&
      not (Ast_types.is_logic_fun_or_ptr e.term_type) ->
    Options.not_yet_implemented
      ~source:(fst t.term_loc) "Integral to pointer casts"
  | TCast(_,_,a) | TUnOp(_,a) | Tat(a,_) -> term env a
  | Tnull | Tempty_set
  | TAlignOf _ | TAlignOfE _ | TSizeOf _ | TSizeOfE _
  | Ttype _ | Ttypeof _
  | TConst _ -> Domain.pure
  | Tif(c,p,q) ->
    pred env c ;
    let loc = c.pred_loc in
    let pos = Logic_const.pif ~loc Logic_const.(c,ptrue,pfalse) in
    let neg = Logic_const.pif ~loc Logic_const.(c,pfalse,ptrue) in
    let dp = assume env pos (term env) p in
    let dq = assume env neg (term env) q in
    Domain.merge min dp dq
  | Tcomprehension(t,xs,p) ->
    forall env xs
      (match p with
       | None -> term env
       | Some p -> pred env p ; assume env p (term env)
      ) t
  | Tunion ts | Tinter ts ->
    List.fold_left
      (fun w t -> Domain.merge min w @@ term env t)
      Domain.pure ts
  | Tbase_addr(_,t) | Toffset(_,t) | Tblock_length(_,t) ->
    term_eval env t ; Domain.pure
  | Tlambda(xs,t) -> forall env xs (term env) t
  | Tlet( { l_profile = xs ; l_body = def } as d,t) ->
    forall env xs (pbody env) def ; plet env d (term env) t
  | TUpdate(r,o,v) ->
    let dr = term env r in
    ignore @@ term_loffset env dr o ;
    term_eval env v ; dr

and pbody env = function
  | LBterm t -> term_eval env t
  | LBpred p -> pred env p
  | LBnone -> ()
  | LBreads _ -> ()
  | LBinductive cs -> List.iter (fun (_,_,_,p) -> pred env p) cs

and pred env p =
  match p.pred_content with
  | Ptrue | Pfalse -> ()
  | Pnot p | Pat(p,_) -> pred env p
  | Pand(p,q) | Pimplies(p,q) -> pred env p ; assume env p (pred env) q
  | Por(p,q) -> pred env p ; assume env (Logic_const.pnot p) (pred env) q
  | Pxor(p,q) | Piff(p,q) -> pred env p ; pred env q
  | Pif(c,p,q) ->
    pred env c ;
    let loc = c.pred_loc in
    let pos = Logic_const.pif ~loc Logic_const.(c,ptrue,pfalse) in
    let neg = Logic_const.pif ~loc Logic_const.(c,pfalse,ptrue) in
    assume env pos (pred env) p ;
    assume env neg (pred env) q ;
  | Prel(_,a,b) -> term_eval env a ; term_eval env b
  | Pfresh(_,_,a,b) | Paligned(a,b) -> term_eval env a ; term_eval env b
  | Pfreeable(_,a) | Pallocable(_,a)
  | Pvalid_function a | Pobject_pointer(_,a)
  | Pdangling(_,a) | Pvalid(_,a) | Pvalid_read(_,a) | Pinitialized(_,a) ->
    term_eval env a
  | Papp(f,_,ts) -> ignore @@ Logic.call env.map f @@ List.map (term env) ts
  | Pseparated ts -> List.iter (term_eval env) ts
  (* Context: *)
  | Pforall(xs,p) | Pexists(xs,p) -> forall env xs (pred env) p
  | Plet( { l_profile = xs ; l_body = def } as d,p) ->
    forall env xs (pbody env) def ; plet env d (pred env) p

(* -------------------------------------------------------------------------- *)
(* --- ACSL Annotations                                                   --- *)
(* -------------------------------------------------------------------------- *)

class visit env =
  object
    inherit Visitor.frama_c_inplace
    method !vexpr e = eval env e ; SkipChildren
    method !vlval lv = ignore @@ lval env lv ; SkipChildren
    method !vterm t = term_eval env t ; SkipChildren
    method !vpredicate p = pred env p ; SkipChildren
    method !vterm_lval lv = ignore @@ term_lval env lv ; SkipChildren
  end

(* -------------------------------------------------------------------------- *)
(* --- Statement Annotations                                              --- *)
(* -------------------------------------------------------------------------- *)

let guards map f stmt =
  let env = create map in
  if Options.Logic.get () then
    begin
      let visitor = new visit env in
      Annotations.iter_code_annot
        (fun _emitter ca ->
           ignore @@ Visitor.visitFramacCodeAnnotation visitor ca) stmt ;
    end ;
  stmtkind env stmt.skind ;
  iter f env

(* -------------------------------------------------------------------------- *)
(* --- Generate Annotations                                               --- *)
(* -------------------------------------------------------------------------- *)

let self =
  let em = ref None in
  fun () ->
    match !em with
    | Some e -> e
    | None ->
      let e = Emitter.create "Region Side-Conditions"
          Emitter.[ Code_annot ; Property_status ]
          ~correctness:[]
          ~tuning:[] in
      em := Some e ; e

let add_annotation ?kf ?emitter ?(names=[]) ?(invalid=false) ?(hyps=[]) stmt condition =
  let loc = Cil_datatype.Stmt.loc stmt in
  let kind = if Options.Assert.get () then Cil_types.Assert else Check in
  let enames = if invalid then "invalid"::names else names in
  let enames = if emitter = None then "region"::enames else enames in
  let e = match emitter with Some e -> e | None -> self () in
  let a = of_condition ~loc ~names:enames condition in
  let a = Logic_const.toplevel_predicate ~kind a in
  let ca = Logic_const.new_code_annotation (AAssert ([],a)) in
  Annotations.add_code_annot e ?kf stmt ca ;
  if invalid then
    let kf = Kernel_function.find_englobing_kf stmt in
    let ips = Property.ip_of_code_annot kf stmt ca in
    let status = Property_status.False_if_reachable in
    List.iter (fun ip -> Property_status.emit e ~hyps ip status) ips ;
    match names with
    | [] ->
      Options.warning ~source:(fst loc) "Invalid side-condition"
    | [e] ->
      Options.warning ~source:(fst loc) "Invalid side-condition (%s)" e
    | es ->
      Options.warning ~source:(fst loc) "Invalid side-conditions (%s)"
        (String.concat ", " es)

(* -------------------------------------------------------------------------- *)
(* ---  Function Annotation                                               --- *)
(* -------------------------------------------------------------------------- *)

module ValidRegion =
  State_builder.Hashtbl(Kernel_function.Hashtbl)(Datatype.Unit)
    (struct
      let name = "Region.Guards.ValidRegion"
      let dependencies = [Ast.self]
      let size = 0
    end)

let is_annotated kf = ValidRegion.mem kf
let set_annotated kf = ValidRegion.add kf ()

let annotate =
  ValidRegion.memo
    begin fun kf ->
      if Kernel_function.has_definition kf then
        begin
          let map = Analysis.get kf in
          Options.feedback "annotating function %a" Kernel_function.pretty kf ;
          let fd = Kernel_function.get_definition kf in
          List.iter
            (fun stmt -> guards map (add_annotation ~kf stmt) stmt)
            fd.sallstmts ;
          set_annotated kf ;
        end
    end

(* -------------------------------------------------------------------------- *)
