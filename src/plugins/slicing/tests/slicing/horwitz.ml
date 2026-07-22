(*
ledit bin/toplevel.top  -deps src/plugins/slicing/tests/slicing/horwitz.c
#use "src/plugins/slicing/tests/slicing/select.ml";;

src/plugins/slicing/tests/slicing/horwitz.byte -deps src/plugins/slicing/tests/slicing/horwitz.c
* *)

include LibSelect;;

let () =
  Boot.Main.extend
    (fun _ ->
       ignore (test_select_data ~do_prop_to_callers:true "incr" "*pi"));;
