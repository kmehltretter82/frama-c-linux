(* -------------------------------------------------------------------------- *)
(* --- Check Filename CASE sensitivity                                    --- *)
(* -------------------------------------------------------------------------- *)

let loadable = [".ts";".tsx";".js";".jsx";".css";".json"]

let basename f =
  let rec lookup f = function
    | [] -> None
    | suffix::others ->
      match Filename.chop_suffix_opt ~suffix f with
      | None -> lookup f others
      | Some basename -> Some (String.lowercase_ascii basename)
  in lookup f loadable

let () =
  let dir = Sys.argv.(1) in
  let hmap : (string,string) Hashtbl.t = Hashtbl.create 32 in
  Sys.readdir dir |> Array.iter
    begin fun f ->
      match basename f with
      | None -> ()
      | Some base ->
        try
          let f0 = Hashtbl.find hmap base in
          Format.printf "Ambiguous import '%s/%s':@\n" dir base ;
          Format.printf " - '%s'@\n" f0 ;
          Format.printf " - '%s'@\n" f ;
          exit 1 ;
        with Not_found ->
          Hashtbl.add hmap base f
    end ;
  exit 0

(* -------------------------------------------------------------------------- *)
