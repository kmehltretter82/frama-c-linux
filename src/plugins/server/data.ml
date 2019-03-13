(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Data Encoding                                                      --- *)
(* -------------------------------------------------------------------------- *)

module Json = Yojson.Basic
module Jutil = Yojson.Basic.Util

type json = Json.t
let pretty = Json.pretty_print ~std:false

module type S =
sig
  type t
  val descr : Markdown.text
  val of_json : json -> t
  val to_json : t -> json
end

module type Info =
sig
  val name : string
  val descr : Markdown.text
end

type 'a data = (module S with type t = 'a)

let d_tuple ts = Markdown.(tt "[" <+> glue ~sep:(raw " `,` ") ts <+> tt "]")
let d_record txt = Markdown.(tt "{" <+> txt <+> tt "}")
let d_array txt = Markdown.(tt "[" <+> txt <+> tt ",…]")
let d_option txt = Markdown.(txt <@> tt "?")

let failure msg js = raise (Jutil.Type_error(msg,js))

(* -------------------------------------------------------------------------- *)
(* --- Option                                                             --- *)
(* -------------------------------------------------------------------------- *)

module Joption(A : S) : S with type t = A.t option =
struct
  type t = A.t option

  let nullable = try ignore (A.of_json `Null) ; true with _ -> false
  let descr = d_option (if nullable then A.descr else d_tuple [A.descr])

  let to_json = function
    | None -> `Null
    | Some v -> if nullable then `List [A.to_json v] else A.to_json v

  let of_json = function
    | `Null -> None
    | `List [js] when nullable -> Some (A.of_json js)
    | js -> Some (A.of_json js)

end

(* -------------------------------------------------------------------------- *)
(* --- Tuples                                                             --- *)
(* -------------------------------------------------------------------------- *)

module Jpair(A : S)(B : S) : S with type t = A.t * B.t =
struct
  type t = A.t * B.t
  let descr = d_tuple [A.descr;B.descr]
  let to_json (x,y) = `List [ A.to_json x ; B.to_json y ]
  let of_json = function
    | `List [ ja ; jb ] -> A.of_json ja , B.of_json jb
    | js -> raise (Jutil.Type_error( "Expected list with 2 elements" , js ))
end

module Jtriple(A : S)(B : S)(C : S) : S with type t = A.t * B.t * C.t =
struct
  type t = A.t * B.t * C.t
  let descr = d_tuple [A.descr;B.descr;C.descr]
  let to_json (x,y,z) = `List [ A.to_json x ; B.to_json y ; C.to_json z ]
  let of_json = function
    | `List [ ja ; jb ; jc ] -> A.of_json ja , B.of_json jb , C.of_json jc
    | js -> raise (Jutil.Type_error( "Expected list with 3 elements" , js ))
end

(* -------------------------------------------------------------------------- *)
(* --- Lists                                                              --- *)
(* -------------------------------------------------------------------------- *)

module Jlist(A : S) : S with type t = A.t list =
struct
  type t = A.t list
  let descr = d_array A.descr
  let to_json xs = `List (List.map A.to_json xs)
  let of_json js = List.map A.of_json (Jutil.to_list js)
end

(* -------------------------------------------------------------------------- *)
(* --- Arrays                                                             --- *)
(* -------------------------------------------------------------------------- *)

module Jarray(A : S) : S with type t = A.t array =
struct
  type t = A.t array
  let descr = d_array A.descr
  let to_json xs = `List (List.map A.to_json (Array.to_list xs))
  let of_json js = Array.of_list @@ List.map A.of_json (Jutil.to_list js)
end

(* -------------------------------------------------------------------------- *)
(* --- Collections                                                        --- *)
(* -------------------------------------------------------------------------- *)

module type S_collection =
sig
  include S
  module Joption : S with type t = t option
  module Jlist : S with type t = t list
  module Jarray : S with type t = t array
end

module Collection(A : S) : S_collection with type t = A.t =
struct
  include A
  module Joption = Joption(A)
  module Jlist = Jlist(A)
  module Jarray = Jarray(A)
end

(* -------------------------------------------------------------------------- *)
(* --- Atomic Types                                                       --- *)
(* -------------------------------------------------------------------------- *)

module Junit : S with type t = unit =
struct
  type t = unit
  let descr = Markdown.tt "null"
  let of_json _js = ()
  let to_json () = `Null
end

module Jany : S with type t = json =
struct
  type t = json
  let descr = Markdown.it "any"
  let of_json js = js
  let to_json js = js
end

module Jbool : S_collection with type t = bool =
  Collection
    (struct
      type t = bool
      let descr = Markdown.it "bool"
      let of_json = Jutil.to_bool
      let to_json b = `Bool b
    end)

module Jint : S_collection with type t = int =
  Collection
    (struct
      type t = int
      let descr = Markdown.it "int"
      let of_json = Jutil.to_int
      let to_json n = `Int n
    end)

module Jfloat : S_collection with type t = float =
  Collection
    (struct
      type t = float
      let descr = Markdown.it "number"
      let of_json = Jutil.to_number
      let to_json v = `Float v
    end)

module Jstring : S_collection with type t = string =
  Collection
    (struct
      type t = string
      let descr = Markdown.it "string"
      let of_json = Jutil.to_string
      let to_json s = `String s
    end)

let text_page = Doc.page `Kernel ~title:"Rich Text Format" ~filename:"text.md"

module Jtext =
struct
  include Jany
  let descr = Markdown.href ~title:"text" (`Page (Doc.path text_page))
end

(* -------------------------------------------------------------------------- *)
(* --- Records                                                            --- *)
(* -------------------------------------------------------------------------- *)

module Fmap = Map.Make(String)

module Record( R : Info ) =
struct

  type t = json Fmap.t
  let descr = Markdown.it R.name

  type 'a field = {
    member : t -> bool ;
    getter : t -> 'a ;
    setter : t -> 'a -> t ;
  }

  (* Declared Fields in this Record *)
  let fdocs = ref []
  let defaults = ref Fmap.empty

  let default () = !defaults
  let has fd r = fd.member r
  let get fd r = fd.getter r
  let set fd v r = fd.setter r v

  let field (type a) name ~descr ?default (d : a data) : a field =
    let module D = (val d) in
    let def = match default with
      | None -> None
      | Some v ->
        let jd = D.to_json v in
        defaults := Fmap.add name jd !defaults ; Some jd
    in fdocs := (name , D.descr , def , descr) :: !fdocs ;
    let member r = Fmap.mem name r in
    let getter r = D.of_json (Fmap.find name r) in
    let setter r v = Fmap.add name (D.to_json v) r in
    { member ; getter ; setter }

  let option (type a) name ~descr (d : a data) : a option field =
    let module D = (val d) in
    fdocs := (name , d_option D.descr , None , descr) :: !fdocs ;
    let member r = Fmap.mem name r in
    let getter r =
      try Some (D.of_json (Fmap.find name r)) with Not_found -> None in
    let setter r = function
      | None -> Fmap.remove name r
      | Some v -> Fmap.add name (D.to_json v) r in
    { member ; getter ; setter }

  let details
      ?(field=`Center "Field")
      ?(format=`Center "Format")
      ?(default=`Center "Default")
      ?(descr=`Left "Description")
      ()
    =
    if Fmap.is_empty !defaults then
      Markdown.table [ field ; format ; descr ]
        (List.map
           (fun (fd,fmt,_def,descr) -> [ Markdown.tt fd ; fmt ; descr ])
           !fdocs)
    else
      let mk_format def fmt = if def <> None then d_option fmt else fmt in
      let mk_default = function
        | None -> Markdown.text []
        | Some js -> Markdown.tt (Json.to_string js) in
      Markdown.table [ field ; format ; default ; descr ]
        (List.map
           (fun (fd,fmt,def,descr) -> [
                Markdown.tt fd ;
                mk_format def fmt ;
                mk_default def ;
                descr ;
              ])
           !fdocs)

  let of_json js =
    List.fold_left
      (fun r (fd,js) -> Fmap.add fd js r)
      (default ()) (Jutil.to_assoc js)

  let to_json r : json =
    `Assoc (Fmap.fold (fun fd js fds -> (fd,js) :: fds) r [])

end

(* -------------------------------------------------------------------------- *)
(* --- Index                                                              --- *)
(* -------------------------------------------------------------------------- *)

(** Simplified [Map.S] *)
module type Map =
sig
  type 'a t
  type key
  val empty : 'a t
  val add : key -> 'a -> 'a t -> 'a t
  val find : key -> 'a t -> 'a
end

module type Index =
sig
  include S_collection
  val get : t -> int
  val find : int -> t
  val clear : unit -> unit
end

module INDEXER(M : Map)(I : Info) :
sig
  type index
  val create : unit -> index
  val clear : index -> unit
  val get : index -> M.key -> int
  val find : index -> int -> M.key
  val to_json : index -> M.key -> json
  val of_json : index -> json -> M.key
end =
struct

  type index = {
    mutable kid : int ;
    mutable index : int M.t ;
    lookup : (int,M.key) Hashtbl.t ;
  }

  let create () = {
    kid = 0 ;
    index = M.empty ;
    lookup = Hashtbl.create 0 ;
  }

  let clear m =
    begin
      m.kid <- 0 ;
      m.index <- M.empty ;
      Hashtbl.clear m.lookup ;
    end

  let get m a =
    try M.find a m.index
    with Not_found ->
      let id = m.kid in
      m.kid <- succ id ;
      m.index <- M.add a id m.index ;
      Hashtbl.add m.lookup id a ; id

  let find m id = Hashtbl.find m.lookup id

  let to_json m a = `Int (get m a)
  let of_json m js =
    let id = Jutil.to_int js in
    try find m id
    with Not_found ->
      let msg = Printf.sprintf "[%s] No registered id #%d" I.name id in
      raise (Jutil.Type_error(msg,js))

end

module Static(M : Map)(I : Info) : Index with type t = M.key =
struct
  module INDEX = INDEXER(M)(I)
  let index = INDEX.create ()
  let clear () = INDEX.clear index
  let get = INDEX.get index
  let find = INDEX.find index
  include Collection
      (struct
        type t = M.key
        let descr = I.descr
        let of_json = INDEX.of_json index
        let to_json = INDEX.to_json index
      end)
end

module Index(M : Map)(I : Info) : Index with type t = M.key =
struct

  module INDEX = INDEXER(M)(I)
  module TYPE : Datatype.S with type t = INDEX.index =
    Datatype.Make
      (struct
        type t = INDEX.index
        include Datatype.Undefined
        let reprs = [INDEX.create()]
        let name = "Server.Data.Index.Type." ^ I.name
        let mem_project = Datatype.never_any_project
      end)
  module STATE = State_builder.Ref(TYPE)
      (struct
        let name = "Server.Data.Index.State." ^ I.name
        let dependencies = []
        let default = INDEX.create
      end)

  let index () = STATE.get ()
  let clear () = INDEX.clear (index())

  let get a = INDEX.get (index()) a
  let find id = INDEX.find (index()) id

  include Collection
      (struct
        type t = M.key
        let descr = I.descr
        let of_json js = INDEX.of_json (index()) js
        let to_json v = INDEX.to_json (index()) v
      end)

end

module type IdentifiedType =
sig
  type t
  val id : t -> int
  include Info
end

module Identified(A : IdentifiedType) : Index with type t = A.t =
struct

  type index = (int,A.t) Hashtbl.t

  module TYPE : Datatype.S with type t = index =
    Datatype.Make
      (struct
        type t = index
        include Datatype.Undefined
        let reprs = [Hashtbl.create 0]
        let name = "Server.Data.Identified.Type." ^ A.name
        let mem_project = Datatype.never_any_project
      end)
  module STATE = State_builder.Ref(TYPE)
      (struct
        let name = "Server.Data.Identified.State." ^ A.name
        let dependencies = []
        let default () = Hashtbl.create 0
      end)

  let lookup () = STATE.get ()
  let clear () = Hashtbl.clear (lookup())

  let get = A.id
  let find id = Hashtbl.find (lookup()) id

  include Collection
      (struct
        type t = A.t
        let descr = A.descr
        let to_json a = `Int (get a)
        let of_json js =
          let k = Jutil.to_int js in
          try find k
          with Not_found ->
            let msg = Printf.sprintf "[%s] No registered id #%d" A.name k in
            raise (Jutil.Type_error(msg,js))
      end)

end

(* -------------------------------------------------------------------------- *)
(* --- Dictionnary                                                        --- *)
(* -------------------------------------------------------------------------- *)

module type Enum =
sig
  type t
  val values : (t * string * Markdown.text) list
  include Info
end

module Dictionary(E : Enum) :
sig
  val descr_table :
    ?tag:Markdown.column ->
    ?descr:Markdown.column ->
    unit -> Markdown.block
  include S_collection with type t = E.t
end =
struct

  let registered = ref false
  let index = Hashtbl.create 0
  let lookup = Hashtbl.create 0

  let register () =
    if not !registered then
      begin
        registered := true ;
        let invalid msg tag =
          let msg = Printf.sprintf "Server.Data.Enum.%s: duplicate %s (%S)"
              E.name msg tag in
          raise (Invalid_argument msg)
        in
        List.iter
          (fun (value,tag,_) ->
             if Hashtbl.mem index value then invalid "value" tag ;
             Hashtbl.add index value tag ;
             if Hashtbl.mem lookup tag then invalid "tag" tag ;
             Hashtbl.add lookup tag value ;
          ) E.values
      end

  let descr_table ?(tag=`Center E.name) ?(descr=`Left "Description") () =
    Markdown.table
      [ tag ; descr ]
      (List.map
         (fun (_,tag,descr) ->
            [ Markdown.tt (Printf.sprintf "%S" tag) ; descr ]
         ) E.values)

  include Collection
      (struct
        type t = E.t

        let descr = E.descr

        let to_json value =
          register () ;
          try `String (Hashtbl.find index value)
          with Not_found ->
            raise (Invalid_argument
                     (Printf.sprintf "[%s] Unregistered value" E.name))

        let of_json js =
          register () ;
          let tag = Jutil.to_string js in
          try Hashtbl.find lookup tag
          with Not_found ->
            let msg = Printf.sprintf "[%s] Unregistered tag %S" E.name tag in
            raise (Jutil.Type_error(msg,js))

      end)

end

(* -------------------------------------------------------------------------- *)
