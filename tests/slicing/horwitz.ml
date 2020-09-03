(* 
ledit bin/toplevel.top  -deps horwitz.c
#use "select.ml";;

horwitz.byte -deps horwitz.c
* *)

include LibSelect;;

let () =
  Db.Main.extend
    (fun _ ->
       ignore (test_select_data ~do_prop_to_callers:true "incr" "*pi"));;


