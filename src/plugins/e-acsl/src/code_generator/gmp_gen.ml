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

end
