open Cil_types

let is_pointer_type cty =
  let cty = Cil.unrollType cty in
  match cty with
  | TInt(_,_)
  | TVoid _
  | TFloat(_,_)
  | TFun(_,_,_,_)
  | TBuiltin_va_list _
  | TComp (_,_,_)
  | TNamed (_,_)
  | TEnum (_,_)
    -> false
  | TPtr(_,_)
  | TArray(_,_,_,_) -> true


let deref_cty cty =
  let cty = Cil.unrollType cty in
  match cty with
  | TInt(_,_)
  | TVoid _
  | TFloat(_,_)
  | TFun(_,_,_,_)
  | TBuiltin_va_list _
  | TComp (_,_,_)
  | TNamed (_,_)
  | TEnum (_,_)
    -> Options.fatal "recieved the type %a when a pointer type was expected"
         Printer.pp_typ cty
  | TPtr(cty,_) -> cty
  | TArray(cty,_,_,_) -> cty


let deref_lty ?cty lty = match lty with
  | Lreal | Lvar _ | Larrow (_ , _) | Ltype (_ , _)->
    Options.fatal "recieved the type %a when a pointer type was expected"
      Printer.pp_logic_type lty
  | Ctype cty -> Ctype (deref_cty cty)
  | Linteger ->
    match cty with
    | None -> Options.fatal "recieved the type %a when a pointer type was expected"
                Printer.pp_logic_type lty
    | Some cty -> Ctype (deref_cty cty)


let logic_type ?cty = function
  | TVar vi -> vi.lv_type
  | TResult ty -> Ctype ty
  | TMem tm -> deref_lty ?cty tm.term_type

let lval ?cty ~loc tlv =
  Logic_const.term ~loc (TLval tlv) (logic_type ?cty (fst tlv))

let deref ?cty ~loc tlv = lval ?cty ~loc (TMem tlv, TNoOffset)

let array_at0 ~loc tlv = lval ~loc (TMem (Logic_utils.mk_logic_StartOf tlv), TNoOffset)
