type symbolic_location = {
  sl_lval : Cil_types.lval;
  sl_location : Locations.location;
  sl_owner : Cil_types.kernel_function option;
  sl_folded : bool;
  sl_imprecise : bool;
}