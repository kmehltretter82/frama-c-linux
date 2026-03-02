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
[@@ deriving ord]

type addr =
  | LV of Lval.t
  | TLV of Term_lval.t
  | ADDR of Exp.t
  | TADDR of Term.t
[@@ deriving ord]

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
  | Non_null of addr
  | Valid of addr
  | Valid_read of addr
  | Valid_object of addr
  | Valid_region of (Memory.node [@ compare fun _ _ -> 0]) * addr
  | Initialized of addr
  | Aligned of addr
[@@ deriving ord]

type condition =
  | Forall of Logic_var.t list * condition
  | Hyp of Predicate.t * condition
  | Let of Logic_info.t * condition
  | At of condition * Logic_label.t
  | Guard of guard
[@@ deriving ord]

let pp_guard fmt = function
  | Bounds(k,n) -> Format.fprintf fmt "0<= %a < %a" pp_value k Z.pretty n
  | Non_null a -> Format.fprintf fmt "!(%a)" pp_addr a
  | Valid a -> Format.fprintf fmt "\\valid(%a)" pp_addr a
  | Valid_object a -> Format.fprintf fmt "\\valid_object(%a)" pp_addr a
  | Valid_read a -> Format.fprintf fmt "\\valid_read(%a)" pp_addr a
  | Valid_region(_,a) -> Format.fprintf fmt "\\valid_region(%a)" pp_addr a
  | Initialized a -> Format.fprintf fmt "\\initialized(%a)" pp_addr a
  | Aligned a -> Format.fprintf fmt "\\aligned(%a)" pp_addr a

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

module Guards = Map.Make
    (struct
      type t = condition
      let compare = compare_condition
    end)

let of_value = function
  | T t -> t
  | E e -> Logic_utils.expr_to_term ~coerce:true e

let of_addr ?loc = function
  | LV lval -> Condition.addrof ?loc lval
  | TLV lval -> Condition.taddrof ?loc lval
  | ADDR ptr -> Logic_utils.expr_to_term ~coerce:true ptr
  | TADDR ptr -> ptr

let of_guard ?loc ?names = function
  | Bounds(k,n) ->
    let z = Logic_const.tinteger ?loc 0 in
    let n = Logic_const.tint ?loc n in
    let k = of_value k in
    let inf = Logic_const.pred ?loc (Prel(Rle,z,k)) in
    let sup = Logic_const.pred ?loc (Prel(Rlt,k,n)) in
    Logic_const.pand ?loc ?names (inf,sup)
  | Non_null p ->
    let addr = of_addr ?loc p in
    let null = Logic_const.term ?loc Tnull addr.term_type in
    Logic_const.prel ?loc ?names (Rneq,addr,null)
  | Valid p -> Condition.pvalid ?loc ?names @@ of_addr ?loc p
  | Valid_read p -> Condition.pvalid_read ?loc ?names @@ of_addr ?loc p
  | Valid_object p -> Condition.pvalid_object ?loc ?names @@ of_addr ?loc p
  | Valid_region(_,p) -> Condition.pvalid_region ?loc ?names @@ of_addr ?loc p
  | Initialized p -> Condition.pinitialized ?loc ?names @@ of_addr ?loc p
  | Aligned p -> Condition.paligned ?loc ?names @@ of_addr ?loc p

let of_condition ?loc ?(names=[]) p =
  let rec generate = function
    | Guard g -> of_guard ?loc g
    | Forall(xs,p) -> Logic_const.pforall ?loc (xs,generate p)
    | Let(l,p) -> Logic_const.plet ?loc l (generate p)
    | Hyp(h,p) -> Logic_const.pimplies ?loc (h,generate p)
    | At(p,l) -> Logic_const.pat ?loc (generate p,l)
  in Logic_const.prepend_names ~names (generate p)

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions Generator                                         --- *)
(* -------------------------------------------------------------------------- *)

type env = {
  map: Memory.map ;
  mutable here: kinstr ;
  mutable context: (guard -> condition) ;
  mutable guards: bool Guards.t ;
}

let root g = Guard g

let create ?stmt map =
  let here = match stmt with None -> Kglobal | Some stmt -> Kstmt stmt in
  {
    map ; here ;
    context = root ;
    guards = Guards.empty ;
  }

let iter f env = Guards.iter (fun g valid -> f g ~valid) env.guards

let add env ?(valid=true) guard =
  let cond = env.context guard in
  env.guards <- Guards.add cond valid env.guards

let check env g n a = function
  | Condition.Default -> add env g
  | Residual { validregion ; condition } ->
    if validregion then add env (Valid_region(n,a)) ;
    match condition with
    | `True -> ()
    | `False -> add env ~valid:false g
    | `Non_null -> add env (Non_null a)

let kind = function
  | LV lv -> Condition.lkind lv
  | ADDR p -> Condition.kind p
  | TLV lv -> Condition.term_lkind lv
  | TADDR p -> Condition.term_kind p

let typeof = function
  | LV lv -> Cil.typeOfLval lv
  | TLV lv -> Logic_utils.logicCType @@ Cil.typeOfTermLval lv
  | ADDR p -> Ast_types.pointed_type @@ Cil.typeOf p
  | TADDR p -> Logic_typing.ctype_of_pointed p.term_type

(* -------------------------------------------------------------------------- *)
(* ---  Valid Conditions                                                  --- *)
(* -------------------------------------------------------------------------- *)

let valid env n a =
  check env (Valid a) n a @@
  Condition.rvalid ~readonly:false env.here n (kind a)

let valid_read env n a =
  check env (Valid_read a) n a @@
  Condition.rvalid ~readonly:true env.here n (kind a)

let valid_object env n a =
  check env (Valid_read a) n a @@
  Condition.rvalid_object env.here n (kind a)

let valid_region env n a =
  if (kind a).unsafe then add env (Valid_region(n,a))

let initialized env n a =
  check env (Valid_read a) n a @@ Condition.rinitialized n (kind a)

let aligned env n a =
  let bits = Fields.bitsSizeOf @@ typeof a in
  check env (Valid_read a) n a @@ Condition.raligned n (kind a) ~bits

let readable env n a =
  begin
    valid_region env n a ;
    valid_read env n a ;
    aligned env n a ;
    if not (Ast_types.is_struct_or_union @@ typeof a) then
      initialized env n a ;
  end

let writable env n a =
  begin
    valid_region env n a ;
    valid env n a ;
    aligned env n a ;
  end

let assignable_pointed env a n =
  let is_fun = Ast_types.is_fun_ptr @@ typeof a in
  begin
    if not is_fun then aligned env n a ;
    valid_object env n a
  end

(* -------------------------------------------------------------------------- *)
(* ---  Lval/Exp Side Conditions                                          --- *)
(* -------------------------------------------------------------------------- *)

let rec lval env (h,o) =
  let t,r = lhost env h in
  offset env t r o

and lhost env = function
  | Var v -> v.vtype, Memory.cvar env.map v
  | Mem e -> Ast_types.direct_pointed_type @@ Cil.typeOf e, addr env e

and offset env t r = function
  | NoOffset -> t,r
  | Field(fd,o) -> offset env fd.ftype (Memory.field r fd) o
  | Index(k,o) ->
    eval env k ;
    let te = Ast_types.direct_element_type t in
    let r = Memory.index r te in
    begin
      if Kernel.SafeArrays.get () then
        let n = Ast_info.direct_array_size t in
        add env (Bounds(E k,n))
    end ;
    offset env te r o

and addr env e = Option.get @@ exp env e
and eval env e =
  match exp env e with
  | None -> ()
  | Some r -> assignable_pointed env (ADDR e) r

and exp env e =
  match e.enode with
  | AddrOf lv | StartOf lv ->
    let _,r = lval env lv in Some r
  | Lval lv ->
    let _,r = lval env lv in
    readable env r (LV lv) ;
    Memory.points_to r
  | CastE(t,_) when Ast_types.is_fun_or_ptr t ->
    Options.not_yet_implemented ~source:(fst e.eloc) "Guards for pointer casts"
  | CastE(_,e) -> exp env e
  | BinOp((PlusPI|MinusPI),p,k,_) ->
    let r = exp env p in
    eval env k ; r
  | BinOp(_,a,b,_) -> eval env a ; eval env b ; None
  | UnOp(_,e,_) -> eval env e ; None
  | Const _ | SizeOf _ | SizeOfE _ | AlignOf (_, _) | AlignOfE (_, _) -> None

let write env lv =
  let _,r = lval env lv in
  writable env r (LV lv)

(* -------------------------------------------------------------------------- *)
(* --- Code Side Conditions                                               --- *)
(* -------------------------------------------------------------------------- *)

let rec init env = function
  | SingleInit e -> eval env e
  | CompoundInit(_,ofs) -> List.iter (fun (_,i) -> init env i) ofs

let instr env = function
  | Set(lv,e,_) ->
    eval env e ;
    write env lv ;
  | Call(r,f,es,_) ->
    ignore (lhost env f) ;
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

let locate env = function
  | StmtLabel sr -> Kstmt !sr
  | FormalLabel _ -> Kglobal
  | BuiltinLabel Here -> env.here
  | BuiltinLabel (Pre|Old|Post|Init) -> Kglobal
  | BuiltinLabel (LoopEntry|LoopCurrent) ->
    match env.here with
    | Kglobal -> Kglobal
    | Kstmt stmt ->
      try
        let kf = Kernel_function.find_englobing_kf stmt in
        Kstmt (Kernel_function.find_enclosing_loop kf stmt)
      with Not_found -> Kglobal

let at env lbl job prm =
  let here = env.here in
  let context = env.context in
  env.context <- (fun p -> At(context p,lbl)) ;
  let r = job prm in env.here <- here ; env.context <- context ; r

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
(* --- Logic Annotations                                                  --- *)
(* -------------------------------------------------------------------------- *)

type lvalue = LOC of Memory.node | VAL of Memory.domain

let rec term_lval env (h,o) : lvalue =
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
      | LOC r -> readable env r (TLV lv) ; Domain.scalar @@ Memory.points_to r
    end
  | TAddrOf lv | TStartOf lv ->
    begin
      match term_lval env lv with
      | VAL _ -> assert false
      | LOC r -> valid_region env r (TLV lv) ; Domain.ptr r
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
  | TCast(_,lt,_) when Ast_types.is_logic_fun_or_ptr lt ->
    Options.not_yet_implemented ~source:(fst t.term_loc) "Guards for pointer casts"
  | TCast(_,_,a) | TUnOp(_,a) -> term env a
  | Tnull | Tempty_set
  | TAlignOf _ | TAlignOfE _ | TSizeOf _ | TSizeOfE _
  | Ttype _ | Ttypeof _
  | TConst _ -> Domain.pure
  | Tif(c,p,q) ->
    term_eval env c ;
    let loc = c.term_loc in
    let pos = Logic_const.pif ~loc Logic_const.(c,ptrue,pfalse) in
    let neg = Logic_const.pif ~loc Logic_const.(c,pfalse,ptrue) in
    let dp = assume env pos (term env) p in
    let dq = assume env neg (term env) q in
    Domain.merge min dp dq
  | Tat(a,l) -> at env l (term env) a
  | Tcomprehension(t,xs,p) ->
    forall env xs
      (match p with
       | None -> term env
       | Some p -> assume env p (term env)
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
  | Pnot p -> pred env p
  | Pand(p,q) | Pimplies(p,q) -> pred env p ; assume env p (pred env) q
  | Por(p,q) -> pred env p ; assume env (Logic_const.pnot p) (pred env) q
  | Pxor(p,q) | Piff(p,q) -> pred env p ; pred env q
  | Pif(c,p,q) ->
    term_eval env c ;
    let loc = c.term_loc in
    let pos = Logic_const.pif ~loc Logic_const.(c,ptrue,pfalse) in
    let neg = Logic_const.pif ~loc Logic_const.(c,pfalse,ptrue) in
    assume env pos (pred env) p ;
    assume env neg (pred env) q ;
  | Pforall(xs,p) | Pexists(xs,p) -> forall env xs (pred env) p
  | Prel(_,a,b) -> term_eval env a ; term_eval env b
  | Pfresh(_,_,a,b) -> term_eval env a ; term_eval env b
  | Pfreeable(_,p) | Pallocable(_,p)
  | Pvalid_function p | Pobject_pointer(_,p)
  | Pdangling(_,p)
    -> term_eval env p
  | Pvalid(l,p) ->
    residual env (Condition.rvalid ~readonly:false (locate env l)) p
  | Pvalid_read(l,p) ->
    residual env (Condition.rvalid ~readonly:true (locate env l)) p
  | Pinitialized(_,p) ->
    residual env Condition.rinitialized p
  | Paligned(p,s) ->
    begin
      match Ast_info.possible_value_of_integral_term s with
      | Some n when Z.fits_int n ->
        let bits = Z.to_int n * 8 in
        residual env (Condition.raligned ~bits) p
      | _ -> term_eval env p ; term_eval env s
    end
  | Papp(f,_,ts) -> ignore @@ Logic.call env.map f @@ List.map (term env) ts
  | Pseparated ts -> List.iter (term_eval env) ts
  | Pat(p,l) -> at env l (pred env) p
  | Plet( { l_profile = xs ; l_body = def } as d,p) ->
    forall env xs (pbody env) def ; plet env d (pred env) p

and residual env f p =
  let r = term_addr env p in
  let kd = Condition.term_kind p in
  match f r kd with
  | Condition.Default -> ()
  | Residual { validregion } ->
    if validregion then valid_region env r (TADDR p)

(* -------------------------------------------------------------------------- *)
(* --- Statement Annotations                                              --- *)
(* -------------------------------------------------------------------------- *)

let iter_stmt map f stmt =
  let env = create ~stmt map in
  stmtkind env stmt.skind ;
  iter f env

(* -------------------------------------------------------------------------- *)
