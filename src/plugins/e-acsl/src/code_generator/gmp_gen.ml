module Z = struct
  let create ~loc ?name t_opt env kf e =
    let _, e, env =
      Env.new_var
        ~loc
        ?name
        env
        kf
        t_opt
        (Gmp_types.Z.t ())
        (fun lv v -> [ Gmp.init_set ~loc (Cil.var lv) v e ])
    in
    e, env

  let add_cast ~loc ?name env kf ty e =
    let fname, new_ty =
      if Cil.isSignedInteger ty then "__gmpz_get_si", Cil.longType
      else "__gmpz_get_ui", Cil.ulongType
    in
    let _, e, env =
      Env.new_var
        ~loc
        ?name
        env
        kf
        None
        new_ty
        (fun v _ ->
           [ Smart_stmt.rtl_call ~loc
               ~result:(Cil.var v)
               ~prefix:""
               fname
               [ e ] ])
    in
    e, env

  let binop ~loc t_opt bop env kf e1 e2 =
    let name = Gmp.Z.name_arith_bop bop in
    let mk_stmts _ e = [ Smart_stmt.rtl_call ~loc
                           ~prefix:""
                           name
                           [ e; e1; e2 ] ] in
    let name = Misc.name_of_binop bop in
    let _, e, env =
      Env.new_var_and_mpz_init ~loc ~name env kf t_opt mk_stmts
    in
    e,env

  let cmp ~loc name t_opt bop env kf e1 e2 =
    let _, e, env = Env.new_var
        ~loc
        env
        kf
        t_opt
        ~name
        Cil.intType
        (fun v _ ->
           [ Smart_stmt.rtl_call ~loc
               ~result:(Cil.var v)
               ~prefix:""
               "__gmpz_cmp"
               [ e1; e2 ] ])
    in
    Cil.new_exp ~loc (BinOp(bop, e, Cil.zero ~loc, Cil.intType)), env
end

module Q = struct
  let create ~loc ?name t_opt env kf e =
    let ty = Cil.typeOf e in
    if Gmp_types.Q.is_t ty then
      e, env
    else
      let _, e, env =
        Env.new_var
          ~loc
          ?name
          env
          kf
          t_opt
          (Gmp_types.Q.t ())
          (fun vi vi_e ->
             [ Gmp.init ~loc vi_e ;
               Gmp.affect ~loc (Cil.var vi) vi_e e ])
      in
      e, env

  let cast_to_z ~loc:_ ?name:_ _env e =
    assert (Gmp_types.Q.is_t (Cil.typeOf e));
    Error.not_yet "reals: cast from R to Z"

  let add_cast ~loc ?name env kf ty e =
    (* TODO: The best solution would actually be to directly write all the needed
       functions as C builtins then just call them here depending on the situation
       at hand. *)
    assert (Gmp_types.Q.is_t (Cil.typeOf e));
    let get_double e env =
      let _, e, env =
        Env.new_var
          ~loc
          ?name
          env
          kf
          None
          Cil.doubleType
          (fun v _ ->
             [ Smart_stmt.rtl_call ~loc
                 ~result:(Cil.var v)
                 ~prefix:""
                 "__gmpq_get_d"
                 [ e ] ])
      in
      e, env
    in
    match Cil.unrollType ty with
    | TFloat(FLongDouble, _) ->
      (* The biggest floating-point type we can extract from GMPQ is double *)
      Error.not_yet "R to long double"
    | TFloat(FDouble, _) ->
      get_double e env
    | TFloat(FFloat, _) ->
      (* No "get_float" in GMPQ, but fortunately, [float] \subset [double].
         HOWEVER: going through double as intermediate step might be unsound since
         it could cause double rounding. See: [Boldo2013, Sec 2.2]
         https://hal.inria.fr/hal-00777639/document *)
      let e, env = get_double e env in
      Options.warning
        ~once:true "R to float: double rounding might cause unsoundness";
      Cil.mkCastT ~force:false ~oldt:Cil.doubleType ~newt:ty e, env
    | TInt(IULongLong, _) ->
      (* The biggest C integer type we can extract from GMP is ulong *)
      Error.not_yet "R to unsigned long long"
    | TInt _ ->
      (* 1) Cast R to Z using cast_to_z
         2) Extract ulong from Z
         3) Potentially cast ulong to ty *)
      Error.not_yet "R to Int"
    | _ ->
      Error.not_yet "R to <typ>"

  let new_var_and_init ~loc ?scope ?name env kf t_opt mk_stmts =
    Env.new_var
      ~loc
      ?scope
      ?name
      env
      kf
      t_opt
      (Gmp_types.Q.t ())
      (fun v e -> Gmp.init ~loc e :: mk_stmts v e)

  let binop ~loc t_opt bop env kf e1 e2 =
    let name = Gmp.Q.name_arith_bop bop in
    (* TODO: [t1_opt] and [t2_opt] could be provided when creating [e1] and
       [e2] *)
    let e1, env = create ~loc None env kf e1 in
    let e2, env = create ~loc None env kf e2 in
    let mk_stmts _ e = [ Smart_stmt.rtl_call ~loc
                           ~prefix:""
                           name
                           [ e; e1; e2 ] ] in
    let name = Misc.name_of_binop bop in
    let _, e, env = new_var_and_init ~loc ~name env kf t_opt mk_stmts in
    e, env

  let cmp ~loc name t_opt bop env kf e1 e2 =
    let fname = "__gmpq_cmp" in
    (* TODO: [t1_opt] and [t2_opt] could be provided when creating [e1] and
       [e2] *)
    let e1, env = create ~loc None env kf e1 in
    let e2, env = create ~loc None env kf e2 in
    let _, e, env =
      Env.new_var
        ~loc
        env
        kf
        t_opt
        ~name
        Cil.intType
        (fun v _ ->
           [ Smart_stmt.rtl_call ~loc
               ~result:(Cil.var v)
               ~prefix:""
               fname
               [ e1; e2 ] ])
    in
    Cil.new_exp ~loc (BinOp(bop, e, Cil.zero ~loc, Cil.intType)), env

end
