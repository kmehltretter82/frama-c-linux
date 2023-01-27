theory vlist_Vlist_nth_repeat_1
imports Why3.Why3
begin

why3_open "vlist_Vlist_nth_repeat_1.xml"

lemma repeat_backward: \<open>repeat w (Suc n) = repeat w n @ w\<close>
  by (induction n) (simp_all add: repeatqtdef_1 repeatqtdef_2)

why3_vc nth_repeat
proof -
  from H1 H2 have \<open>0 < n * int (length w)\<close> by simp
  with H3 have
    N: \<open>0 \<le> n\<close> using zero_less_mult_pos2 order_le_less_trans by fastforce
  moreover obtain i m where
    I: \<open>i = nat k\<close> and
    M: \<open>m = nat n\<close> by simp
  moreover note H1 H2
  ultimately have
    \<open>i < m * length w\<close> using int_ops(7) nat_0_le nat_less_as_int by presburger
  then have \<open>repeat w (int m) ! i = w ! (i mod length w)\<close>
  proof (induction m)
    case (Suc m)
    then have \<open>repeat w (int m) ! i = w ! (i mod length w)\<close> if \<open>i < m * length w\<close> using that by simp
    then have ?case if \<open>i < m * length w\<close> using that
      by (simp only: repeat_backward)
        (metis length_repeat nat_int nth_append of_nat_0_le_iff of_nat_mult)
    moreover
    have \<open>length (repeat w (int m)) \<le> i\<close> if \<open>m * length w \<le> i\<close> using that length_repeat
      by (metis int_ops(7) nat_leq_as_int of_nat_0_le_iff)
    then have
      \<open>repeat w (int (Suc m)) ! i = w ! (i - length (repeat w (int m)))\<close> if \<open>m * length w \<le> i\<close>
      using that by (simp only: repeat_backward) (simp add: nth_append)
    then have \<open>repeat w (int (Suc m)) ! i = w ! (i - m * length w)\<close> if \<open>m * length w \<le> i\<close>
      using that length_repeat by (metis nat_int of_nat_0_le_iff of_nat_mult)
    with H3 Suc(2) have ?case if \<open>m * length w \<le> i\<close> using that calculation
      by (metis approximation_preproc_nat(11) div_less_iff_less_mult less_Suc_eq of_nat_0_less_iff)
    ultimately show ?case by linarith
  qed simp
  with M I N have \<open>repeat w n ! nat k = w ! ((nat k) mod length w)\<close> by fastforce
  moreover from H1 H3 have \<open>nat (k cmod int (length w)) = k mod int (length w)\<close>
    unfolding Why3_Int.cmod_def by (simp add: zsgn_def)
  with H1 have \<open>nat (k cmod int (length w)) = nat k mod length w\<close>
    by (metis int_nat_eq nat_int zmod_int)
  ultimately show ?thesis by presburger
qed

why3_end

end
