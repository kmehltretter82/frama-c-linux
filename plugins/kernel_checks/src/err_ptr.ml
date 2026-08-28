(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

type classification =
  | Encoded_error
  | Null
  | Valid_object
  | Unknown

type operation =
  | Read
  | Write
  | Indirect_call
  | Deallocate of string

let error_intervals () =
  let max_errno = Options.MaxErrno.get () in
  let pointer_bits = Cil.bitsSizeOf Cil_const.voidPtrType in
  let modulus = Z.two_power_of_int pointer_bits in
  let max_errno_z = Z.of_int max_errno in
  let unsigned =
    Ival.inject_range
      (Some Z.(sub modulus max_errno_z))
      (Some Z.(pred modulus))
  and signed =
    Ival.inject_range (Some Z.(neg max_errno_z)) (Some Z.minus_one)
  in
  unsigned, signed

let is_encoded_error absolute =
  if Ival.is_bottom absolute then false
  else
    let unsigned, signed = error_intervals () in
    Ival.is_included absolute unsigned || Ival.is_included absolute signed

let valid_object_pointer access pointers =
  if Cvalue.V.is_bottom pointers then false
  else
    try
      Cvalue.V.for_all
        (fun base byte_offsets ->
           let bit_offsets = Ival.scale (Z.of_int 8) byte_offsets in
           Base.is_valid_offset access base bit_offsets)
        pointers
    with Abstract_interp.Error_Top -> false

let classify ~access value =
  if Cvalue.V.is_bottom value then Unknown
  else
    let absolute, pointers = Cvalue.V.split Base.null value in
    if Cvalue.V.is_bottom pointers then
      if Ival.is_zero absolute then Null
      else if is_encoded_error absolute then Encoded_error
      else Unknown
    else if Ival.is_bottom absolute && valid_object_pointer access pointers then
      Valid_object
    else
      Unknown

let access_for_lval writing lval =
  try
    let size = Z.of_int (Cil.bitsSizeOf (Cil.typeOfLval lval)) in
    if writing then Base.Write size else Base.Read size
  with Cil.SizeOfError _ -> Base.Object_pointer

let operation_text = function
  | Read -> "read through"
  | Write -> "write through"
  | Indirect_call -> "call through"
  | Deallocate function_name ->
    Format.asprintf "pass to deallocator %s" function_name

let deallocator_argument name =
  match name with
  | "kfree" | "kfree_sensitive" | "kvfree" | "kvfree_sensitive"
  | "vfree" | "free" | "__kfree_skb" | "kfree_skb"
  | "kfree_skb_reason" | "kfree_skb_list" | "kfree_skb_list_reason"
  | "kfree_skb_partial" | "consume_skb" | "napi_consume_skb"
  | "dev_kfree_skb" | "dev_kfree_skb_any" | "dev_kfree_skb_any_reason"
  | "dev_kfree_skb_irq" | "dev_kfree_skb_irq_reason"
  | "dev_consume_skb_any" | "dev_consume_skb_irq" -> Some 0
  | "devm_kfree" -> Some 1
  | _ -> None

class checker = object (self)
  inherit Visitor.frama_c_inplace

  val mutable violations = 0

  method violations = violations

  method private check_expression ~access operation expression =
    match self#current_stmt with
    | None -> ()
    | Some stmt ->
      let evaluated =
        Eva.Results.(before stmt |> eval_exp expression |> as_cvalue_result)
      in
      match evaluated with
      | Ok value when classify ~access value = Encoded_error ->
        violations <- violations + 1;
        Options.warning
          ~wkey:Options.wkey_err_ptr ~current:true
          "ERR_PTR protocol violation: %s encoded error pointer %a (value %a)"
          (operation_text operation) Printer.pp_exp expression
          Cvalue.V.pretty value
      | Ok _ | Error _ -> ()

  method private check_lval ~writing operation ((host, _) as lval) =
    match host with
    | Var _ -> ()
    | Mem pointer ->
      self#check_expression
        ~access:(access_for_lval writing lval) operation pointer

  method private check_deallocator name arguments =
    match deallocator_argument name with
    | None -> ()
    | Some index ->
      match List.nth_opt arguments index with
      | None -> ()
      | Some pointer ->
        self#check_expression
          ~access:Base.Object_pointer (Deallocate name) pointer

  method! vinst instruction =
    begin
      match instruction with
      | Set (destination, _, _) ->
        self#check_lval ~writing:true Write destination
      | Call (destination, function_host, arguments, _) ->
        Option.iter (self#check_lval ~writing:true Write) destination;
        begin
          match function_host with
          | Var function_info ->
            self#check_deallocator function_info.vname arguments
          | Mem function_pointer ->
            self#check_expression
              ~access:Base.Any_pointer Indirect_call function_pointer
        end
      | Local_init _ | Asm _ | Skip _ | Code_annot _ -> ()
    end;
    Cil.DoChildren

  method! vexpr expression =
    begin
      match expression.enode with
      | Lval lval -> self#check_lval ~writing:false Read lval
      | _ -> ()
    end;
    Cil.DoChildren
end

let run () =
  Eva.Analysis.compute ();
  let visitor = new checker in
  Visitor.visitFramacFileSameGlobals
    (visitor :> Visitor.frama_c_visitor) (Ast.get ());
  visitor#violations
