(*
ledit bin/toplevel.top  -deps plugins/slicing/tests/slicing/horwitz.c
#use "plugins/slicing/tests/slicing/select.ml";;

plugins/slicing/tests/slicing/horwitz.byte -deps plugins/slicing/tests/slicing/horwitz.c
* *)

include LibSelect;;

let () =
  Boot.Main.extend
    (fun _ ->
       ignore (test_select_data ~do_prop_to_callers:true "incr" "*pi"));;
