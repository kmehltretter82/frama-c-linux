theory vlist_Vlist_eq_repeat_concat_1
imports Why3.Why3
begin

why3_open "vlist_Vlist_eq_repeat_concat_1.xml"

lemma repeat_backward: \<open>repeat w (Suc n) = repeat w n @ w\<close>
  by (induction n) (simp_all add: repeatqtdef_1 repeatqtdef_2)

why3_vc eq_repeat_concat
proof -
  from assms obtain i j where
    \<open>int i = p\<close> and
    \<open>int j = q\<close> using nat_0_le by blast
  moreover have \<open>repeat w (int i + int j) = repeat w (int i) @ repeat w (int j)\<close>
    by (induction j)
      (simp add: rw_repeat_zero, metis add_Suc_right append.assoc of_nat_add repeat_backward)
  ultimately show ?thesis unfolding vlist_eq_def by simp
qed

why3_end

end
