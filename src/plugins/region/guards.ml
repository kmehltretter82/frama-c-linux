(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Condition

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions Generator                                         --- *)
(* -------------------------------------------------------------------------- *)

type env = {
  map: Memory.map ;
  mutable guards : guard list ;
}

let create map = { map ; guards = [] }
let add env g = if not @@ trivial g then env.guards <- g :: env.guards
let iter f env = List.iter f @@ List.rev env.guards

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
    if not s then add env @@ g_valid Region (E e) ;
    Ast_types.C.direct_pointed @@ Cil.typeOf e, r

and offset env s t r = function
  | NoOffset -> s,t,r
  | Field(fd,o) -> offset env s fd.ftype (Memory.field r fd) o
  | Index(k,o) ->
    eval env k ;
    let te = Ast_types.C.direct_array_element t in
    let r = Memory.index r te in
    let s =
      if Kernel.SafeArrays.get () then
        let n = Ast_info.direct_array_size t in
        add env @@ g_bounds k n ; s
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
    if not s then add env @@ g_valid Region (L lv) ;
    Option.map (fun r -> false,r) @@ Memory.points_to r
  | CastE(t,e) when
      Ast_types.C.is_fun_or_ptr t &&
      not (Ast_types.C.is_fun_or_ptr @@ Cil.typeOf e) ->
    Options.not_yet_implemented ~source:(Fileloc.loc_start e.eloc)
      "Integral to pointer casts"
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
  let safe,_,_ = lval env lv in
  if not safe then add env @@ g_valid Region (L lv)

(* -------------------------------------------------------------------------- *)
(* --- Root Side Conditions                                               --- *)
(* -------------------------------------------------------------------------- *)

let nullable ~flags p =
  if Attr.mem `Nullable flags || Attr.mem `Allocated flags
  then g_null ~eq:false p
  else g_true

let valid ~flags acs p =
  match acs with
  | Write when Attr.mem `Validread flags -> g_valid acs p
  | Read | Write when not @@ Attr.mem `Allocated flags -> nullable ~flags p
  | Initialized when not @@ Attr.mem `Garbage flags -> g_true
  | _ -> g_valid acs p

let requires ~spec node p =
  let flags = Memory.flags node in
  let initialized =
    if not @@ Attr.mem `Garbage spec
    then valid ~flags Initialized p
    else g_true in
  if Attr.mem `Allocated spec
  then g_imply (valid ~flags Read p) initialized
  else
    let acs = if Attr.mem `Validread spec then Read else Write in
    let accessible = valid ~flags acs p in
    let wellformed = g_and accessible initialized in
    if Attr.mem `Nullable spec
    then g_imply (nullable ~flags p) wellformed
    else wellformed

(* -------------------------------------------------------------------------- *)
(* --- Call Side Conditions                                               --- *)
(* -------------------------------------------------------------------------- *)

let subst ~loc kf es t =
  match Logic_subst.term (Kernel_function.get_formals kf) es t
  with Some t -> t | None ->
    Options.abort ~source:(Fileloc.loc_start loc)
      "Can not evaluate term (%a)@ from function %a at call site"
      Printer.pp_term t Kernel_function.pretty kf

let call_kf env stmt kf es =
  let fct = Kernel_function.get_name kf in
  let loc = Cil_datatype.Stmt.loc stmt in
  let tenv = Lookup.callsite env.map stmt kf in
  let kmap = Analysis.get kf in
  let globals = ref [] in
  let objmap = Separated.create () in
  begin
    Memory.iter
      (fun from ->
         List.iter
           (fun x ->
              if x.vglob then
                let lv = L(Var x,NoOffset) in
                globals := lv :: !globals
           ) (Memory.cvars from) ;
         List.iter
           (function Memory.Root a ->
              let ptr = subst ~loc kf es a.ptr in
              let inf = subst ~loc kf es a.inf in
              let sup = subst ~loc kf es a.sup in
              let addr = R(ptr,a.typ,inf,sup) in
              let node = Lookup.tmem tenv ptr in
              Separated.add objmap ~node ~from
                { named = a.named ; flags = a.flags ; addr } ;
              add env @@ g_name fct @@ g_name a.named @@
              requires ~spec:a.flags node addr ;
           ) (Memory.roots from) ;
      ) kmap ;
    let globals = List.rev !globals in
    Separated.iter
      (fun _node a ->
         List.iter
           (fun g ->
              add env
              @@ g_name fct @@ g_name a.named
              @@ g_imply (valid ~flags:a.flags Read a.addr)
              @@ g_separated a.addr g
           ) globals
      ) objmap ;
    Separated.iter2
      (fun _node a b ->
         add env
         @@ g_name fct @@ g_name a.named @@ g_name b.named
         @@ g_imply (valid ~flags:a.flags Read a.addr)
         @@ g_imply (valid ~flags:b.flags Read b.addr)
         @@ g_separated a.addr b.addr
      ) objmap ;
  end

let call env stmt fct es =
  match Kernel_function.get_called fct with
  | Some kf -> call_kf env stmt kf es
  | None ->
    begin
      match Dyncall.get stmt with
      | Some(_,kfs) ->
        List.iter (fun kf -> call_kf env stmt kf es) kfs
      | None ->
        Options.not_yet_implemented
          ~source:(Fileloc.loc_start @@ Cil_datatype.Stmt.loc stmt)
          "Dynamic call without @call annotation"
    end

(* -------------------------------------------------------------------------- *)
(* --- Code Side Conditions                                               --- *)
(* -------------------------------------------------------------------------- *)

let rec init env = function
  | SingleInit e -> eval env e
  | CompoundInit(_,ofs) -> List.iter (fun (_,i) -> init env i) ofs

let evalfun env = function
  | Var _vf -> ()
  | Mem e -> eval env e

let instr env stmt = function
  | Set(lv,e,_) ->
    eval env e ;
    write env lv ;
  | Call(r,f,es,_) ->
    evalfun env f ;
    List.iter (eval env) es ;
    Option.iter (write env) r ;
    call env stmt f es
  | Local_init(_,AssignInit i,_) -> init env i
  | Local_init(x,ConsInit(vf,args,kind),loc) ->
    List.iter (eval env) args ;
    Cil.treat_constructor_as_func
      (fun _res fct args _loc -> call env stmt fct args)
      x vf args kind loc
  | Asm _ | Skip _ | Code_annot _ -> ()

let stmtkind env stmt = function
  | Instr i -> instr env stmt i
  | Return(r,_) -> Option.iter (eval env) r
  | If(e,_,_,_) | Switch(e,_,_,_)| Throw (Some(e,_),_) -> eval env e
  | Goto _ | Break _ | Continue _ | Loop _ | Block _
  | Throw(None,_) | TryCatch _ | TryFinally _ -> ()
  | TryExcept(_,(ks,e),_,_) -> List.iter (instr env stmt) ks ; eval env e
  | UnspecifiedSequence _ -> () (* already visited *)

let guards map f stmt =
  let env = create map in stmtkind env stmt stmt.skind ; iter f env

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

let add_annotation ?kf ?emitter ?(names=[]) ?(hyps=[]) stmt guard =
  let loc = Cil_datatype.Stmt.loc stmt in
  let kind = if Options.Assert.get () then Cil_types.Assert else Check in
  let invalid = invalid guard in
  let enames = if invalid then "invalid"::names else names in
  let enames = if emitter = None then "region"::enames else enames in
  let e = match emitter with Some e -> e | None -> self () in
  let a = of_guard ~loc ~names:enames guard in
  let a = Logic_const.toplevel_predicate ~kind a in
  let ca = Logic_const.new_code_annotation (AAssert ([],a)) in
  Annotations.add_code_annot e ?kf stmt ca ;
  if invalid then
    let kf = Kernel_function.find_englobing_kf stmt in
    let ips = Property.ip_of_code_annot kf stmt ca in
    let status = Property_status.False_if_reachable in
    List.iter (fun ip -> Property_status.emit e ~hyps ip status) ips ;
    Options.warning ~source:(Fileloc.loc_start loc) "Invalid side-condition: %a"
      Printer.pp_predicate (of_guard @@ falsy guard)

(* -------------------------------------------------------------------------- *)
(* ---  Function Annotation                                               --- *)
(* -------------------------------------------------------------------------- *)

module Computed =
  State_builder.Hashtbl(Kernel_function.Hashtbl)(Datatype.Unit)
    (struct
      let name = "Region.Guards.Computed"
      let dependencies = [Ast.self]
      let size = 0
    end)

let is_annotated kf = Computed.mem kf
let set_annotated kf = Computed.add kf ()

let annotate =
  Computed.memo
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
