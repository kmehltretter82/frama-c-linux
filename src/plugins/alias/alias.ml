

type lset = Cil_datatype.Lval.Set.t  (* sets of lvalues *)

(** Performes the may-alias analysis. Do it once before using other functions *)
let compute () =
  failwith "not implemented"

(** Minimal API, as presented during kickoff meeting *)
(* we changed:  type varinfo -> type lval *)

let get_class_before_statement _ =
  failwith "not implemented"

let get_class_after_statement _ =
  failwith "not implemented"

let  get_class_fundec _ =
  failwith "not implemented"

let get_class_fundec_stmts _ =
  failwith "not implemented"

    
(** connection with Abstract_state *)

let concretise _ =
  failwith "not implemented"


(** other functions required by MERCE *)
  
(* checks that two Lval have the same ECR *)
let is_equivalent  _ =
  failwith "not implemented"

(* give the graph vertex of lval *)
let points_to _ =
  failwith "not implemented"


(* give the graph vertex of lval and its points-to closure *)
let points_to_closure  _ =
  failwith "not implemented"
