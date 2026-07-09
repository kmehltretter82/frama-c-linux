(*
ledit bin/toplevel.top  -no-annot -deps -slicing_level 2 src/plugins/slicing/tests/slicing/adpcm.c
#use "src/plugins/slicing/tests/slicing/select.ml";;
*)

include LibSelect;;

(* Kernel.slicing_level := 2;;  = MinimizeNbCalls *)

(*
let resname = "src/plugins/slicing/tests/slicing/adpcm.sliced" in
ignore (test "uppol2" ~do_prop_to_callers:true ~resname (select_retres));;
*)
let () =
  Boot.Main.extend
    (fun _ -> ignore (test "uppol2" ~do_prop_to_callers:true (select_retres)))
