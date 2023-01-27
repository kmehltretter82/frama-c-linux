theory vlist_Vlist_length_repeat_1
imports Why3.Why3
begin

why3_open "vlist_Vlist_length_repeat_1.xml"

why3_vc length_repeat
  using assms by (induction n) (simp_all add: Rings.ring_distribs(2) repeatqtdef_1 repeatqtdef_2)

why3_end

end
