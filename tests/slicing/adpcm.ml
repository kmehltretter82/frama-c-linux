(*
ledit bin/toplevel.top  -no-annot -deps -slicing_level 2 adpcm.c
#use "select.ml";;
*)

include LibSelect;;

(* Kernel.slicing_level := 2;;  = MinimizeNbCalls *)

(*
let resname = "adpcm.sliced" in
ignore (test "uppol2" ~do_prop_to_callers:true ~resname (select_retres));;
*)
let () =
  Db.Main.extend
    (fun _ -> ignore (test "uppol2" ~do_prop_to_callers:true (select_retres)))

