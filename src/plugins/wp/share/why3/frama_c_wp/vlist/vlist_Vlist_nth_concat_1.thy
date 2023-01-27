theory vlist_Vlist_nth_concat_1
imports Why3.Why3
begin

why3_open "vlist_Vlist_nth_concat_1.xml"

why3_vc nth_concat
  using assms by (simp add: nat_diff_distrib' nat_less_iff nth_append)

why3_end

end
