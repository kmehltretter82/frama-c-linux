open Cabs
open Crowbar

let loc = Cabshelper.cabslu

let gen_int_type =
  choose [
    const Tint;
    const Tlong;
    const Tunsigned;
  ]

let gen_type =
  choose [
    gen_int_type;
    const Tfloat;
    const Tdouble;
  ]

let mk_exp expr_node = { expr_loc = loc; expr_node }

let force_int gen_expr =
  map [gen_int_type; gen_expr]
    (fun x e -> mk_exp (CAST (([SpecType x],JUSTBASE), SINGLE_INIT e)))

let gen_int_unary =
  choose [
    const NOT;
    const BNOT;
  ]

let gen_unary =
  choose [
    const MINUS;
    const PLUS;
  ]

let gen_constant =
  choose [
    map [ int64 ] (fun i -> CONST_INT (Int64.to_string i));
    map [ float ] (fun f -> CONST_FLOAT (string_of_float f))
  ]

let gen_expr =
  fix
    (fun gen_expr ->
       choose [
         map [ gen_int_unary; force_int gen_expr ]
           (fun u e -> mk_exp (UNARY(u,e)));
         map [ gen_constant ]
           (fun c -> mk_exp (CONSTANT c))
       ])

let gen_cabs typ expr =
  (Datatype.Filepath.dummy,
   [false,
    FUNDEF(
      None,([SpecType Tvoid],("f", PROTO(JUSTBASE,[],[],false),[],loc)),
      { blabels = [];
        battrs = [];
        bstmts = [
          { stmt_ghost = false;
            stmt_node =
              DEFINITION(
                DECDEF(
                  None,
                  ([SpecType typ], [("x",JUSTBASE,[],loc),SINGLE_INIT expr]),
                  loc))}
          ]
      },
    loc,loc)])

let run typ expr =
  let loc = Cil_datatype.Location.unknown in
  let cabs = gen_cabs typ expr in
  Project.set_current (Project.create "my_project");
  let cil = Cabs2cil.convFile cabs in
  File.prepare_cil_file cil;
  Kernel.MainFunction.set "f";
  !Db.Value.compute ();
  let kf = Globals.Functions.find_by_name "f" in
  let x = Globals.Vars.find_from_astinfo "x" (Cil_types.VLocal kf) in
  let ret = Kernel_function.find_return kf in
  let state = Db.Value.get_stmt_state ~after:true ret in
  let v1 =
    !Db.Value.eval_expr
      ~with_alarms:CilE.warn_none_mode state (Cil.evar ~loc x)
  in
  Kernel.Constfold.on ();
  !Db.Value.compute ();
  let state = Db.Value.get_stmt_state ~after:true ret in
  let v2 =
    !Db.Value.eval_expr
      ~with_alarms:CilE.warn_none_mode state (Cil.evar ~loc x)
  in
  let eq = Cvalue.V.equal in
  let pp = Cvalue.V.pretty in
  check_eq ~pp ~eq v1 v2

let () = add_test ~name:"constfold" [gen_type; gen_expr] run
