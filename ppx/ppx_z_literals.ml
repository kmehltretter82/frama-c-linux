open Ppxlib

let conv_to_z  loc = [%expr Z.of_int]

let rewriter conv loc s =
  let number =
    Ast_builder.Default.pexp_constant ~loc
      (Parsetree.Pconst_integer (s, None))
  in
  [%expr [%e (conv loc)] [%e number]]

let rule (ch, conv) =
  Ppxlib.Context_free.Rule.(constant Constant_kind.Integer ch (rewriter conv))

let rules =
  List.map rule  [ ('z', conv_to_z) ]

let () =
  Driver.register_transformation ~rules
    "Constant rewriting for Zarith.Z.t from int"
