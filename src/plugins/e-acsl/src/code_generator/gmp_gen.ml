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
end
