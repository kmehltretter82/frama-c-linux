Compilation of the coherent_compare_hash_types.ml file.
  $ dune build --cache=disabled --root . coherent_compare_hash_types.cmxs

  $ frama-c -no-autoload-plugins -kernel-msg-key printer:attrs -load-module coherent_compare_hash_types.cmxs
  Checking Cil_datatype.Typ.t
    All checks succeeded!
  
  Checking Cil_datatype.TypByName.t
    All checks succeeded!
  
  Checking Cil_datatype.TypNoUnroll.t
    All checks succeeded!
  
  Checking Cil_datatype.TypNoAttrs.t
    All checks succeeded!
  
