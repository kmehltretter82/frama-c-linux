(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C) 2026 Frama-C Linux contributors                         *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

type operation =
  | Read
  | Write

type offset_access = {
  field: fieldinfo;
  counter: fieldinfo;
  counter_offset: offset;
  index: exp;
}

type access = {
  field: fieldinfo;
  counter: fieldinfo;
  counter_lval: lval;
  index: exp;
}

type violation =
  | Negative_index
  | Empty_extent
  | At_extent
  | Beyond_extent

let counted_by_field_name field =
  match Ast_attributes.find_params "counted_by" field.fattr with
  | [ ACons (name, []) ] -> Some name
  | _ -> None

let counted_by_counter field =
  match counted_by_field_name field, field.fcomp.cfields with
  | Some name, Some fields ->
    List.find_opt
      (fun candidate ->
         String.equal candidate.fname name ||
         String.equal candidate.forig_name name)
      fields
  | None, _ | _, None -> None

let rec flexible_array_accesses = function
  | NoOffset -> []
  | Field (field, remaining) ->
    let nested =
      List.map
        (fun access ->
           { access with
             counter_offset = Field (field, access.counter_offset) })
        (flexible_array_accesses remaining)
    in
    begin
      match remaining, counted_by_counter field with
      | Index (index, _), Some counter ->
        { field; counter; counter_offset = Field (counter, NoOffset); index }
        :: nested
      | NoOffset, _ | Field _, _ | Index _, None -> nested
    end
  | Index (index, remaining) ->
    List.map
      (fun access ->
         { access with
           counter_offset = Index (index, access.counter_offset) })
      (flexible_array_accesses remaining)

let is_pointer_type typ =
  match Ast_types.C.unroll_node typ with
  | TPtr _ -> true
  | _ -> false

let rec counted_pointer_offset = function
  | Field (field, NoOffset) when is_pointer_type field.ftype ->
    Option.map
      (fun counter -> Field (counter, NoOffset), field, counter)
      (counted_by_counter field)
  | Field (field, remaining) ->
    Option.map
      (fun (counter_offset, counted, counter) ->
         Field (field, counter_offset), counted, counter)
      (counted_pointer_offset remaining)
  | Index (index, remaining) ->
    Option.map
      (fun (counter_offset, counted, counter) ->
         Index (index, counter_offset), counted, counter)
      (counted_pointer_offset remaining)
  | NoOffset -> None

let counted_pointer_lval expression =
  match (Cil.stripCasts expression).enode with
  | Lval (host, offset) ->
    Option.map
      (fun (counter_offset, field, counter) ->
         (host, counter_offset), field, counter)
      (counted_pointer_offset offset)
  | _ -> None

let pointer_access address =
  match (Cil.stripCasts address).enode with
  | BinOp (PlusPI, base, index, _) ->
    Option.map
      (fun (counter_lval, field, counter) ->
         { field; counter; counter_lval; index })
      (counted_pointer_lval base)
  | Lval _ ->
    Option.map
      (fun (counter_lval, field, counter) ->
         let index = Cil.zero ~loc:address.eloc in
         { field; counter; counter_lval; index })
      (counted_pointer_lval address)
  | _ -> None

let accesses_of_lval (host, offset) =
  let flexible =
    List.map
      (fun { field; counter; counter_offset; index } ->
         { field; counter; counter_lval = host, counter_offset; index })
      (flexible_array_accesses offset)
  in
  match host with
  | Var _ -> flexible
  | Mem address ->
    begin
      match pointer_access address with
      | None -> flexible
      | Some access -> access :: flexible
    end

let expression_lval expression =
  match expression.enode with
  | Lval lval -> Some lval
  | _ -> None

let index_is_counter index counter_lval =
  match expression_lval index with
  | Some index_lval ->
    Cil_datatype.LvalStructEq.equal index_lval counter_lval
  | None -> false

let prove_violation access index_value counter_value =
  if Ival.is_bottom index_value || Ival.is_bottom counter_value then None
  else if index_is_counter access.index access.counter_lval then
    Some At_extent
  else
    match Ival.max_int index_value with
    | Some maximum when Z.lt maximum Z.zero -> Some Negative_index
    | None | Some _ ->
      begin
        match Ival.max_int counter_value with
        | Some maximum when Z.leq maximum Z.zero -> Some Empty_extent
        | Some maximum ->
          begin
            match Ival.min_int index_value with
            | Some minimum when Z.geq minimum maximum -> Some Beyond_extent
            | None | Some _ -> None
          end
        | None -> None
      end

let violation_text = function
  | Negative_index -> "always negative"
  | Empty_extent -> "outside an always-empty effective extent"
  | At_extent -> "equal to its associated count on every evaluated state"
  | Beyond_extent -> "at least the largest possible effective extent"

let operation_text = function
  | Read -> "read from"
  | Write -> "write to"

class checker = object (self)
  inherit Visitor.frama_c_inplace

  val mutable violations = 0

  method violations = violations

  method private check_access operation stmt access =
    let index_result =
      Eva.Results.(before stmt |> eval_exp access.index |> as_ival)
    and counter_result =
      Eva.Results.(before stmt |> eval_lval access.counter_lval |> as_ival)
    in
    match index_result, counter_result with
    | Ok index_value, Ok counter_value ->
      begin
        match prove_violation access index_value counter_value with
        | None -> ()
        | Some reason ->
          violations <- violations + 1;
          Options.warning
            ~wkey:Options.wkey_counted_by_bounds
            ~source:access.index.eloc
            "counted_by bounds violation: %s field '%s' at index %a \
             (value %a), which is %s; counter '%s' has value %a"
            (operation_text operation) access.field.forig_name
            Printer.pp_exp access.index Ival.pretty index_value
            (violation_text reason) access.counter.forig_name
            Ival.pretty counter_value
      end
    | Error _, _ | _, Error _ -> ()

  method private check_lval operation lval =
    match self#current_stmt with
    | None -> ()
    | Some stmt ->
      List.iter (self#check_access operation stmt) (accesses_of_lval lval)

  method! vinst instruction =
    begin
      match instruction with
      | Set (destination, _, _) -> self#check_lval Write destination
      | Call (destination, _, _, _) ->
        Option.iter (self#check_lval Write) destination
      | Local_init _ | Asm _ | Skip _ | Code_annot _ -> ()
    end;
    Cil.DoChildren

  method! vexpr expression =
    begin
      match expression.enode with
      | Lval lval -> self#check_lval Read lval
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
