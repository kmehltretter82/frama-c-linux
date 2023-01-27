theory vlist_Vlist_extensionality_1
imports Why3.Why3
begin

why3_open "vlist_Vlist_extensionality_1.xml"

why3_vc extensionality
  using assms unfolding vlist_eq_def
  by (metis int_eq_iff less_imp_of_nat_less list_eq_iff_nth_eq)

why3_end

end
