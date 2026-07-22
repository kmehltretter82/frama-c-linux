(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- VList Builtins                                                     --- *)
(* -------------------------------------------------------------------------- *)
let dkey = Wp_parameters.register_category "sequence"
let debug fmt = Wp_parameters.debug ~dkey fmt
let debugN level fmt = Wp_parameters.debug ~level ~dkey fmt

open Lang.E
open Lang.F
module L = Qed.Logic
module E = Qed.Engine

(* -------------------------------------------------------------------------- *)
(* --- Driver                                                             --- *)
(* -------------------------------------------------------------------------- *)

(*--- Typechecking ---*)
let a_list = Lang.extern_t "list.List.list"
let alist e = Lang.t_data !@a_list [e]

(*--- Qed Symbols ---*)

let f_nil = Lang.extern_f ~category:Constructor "frama_c_wp.vlist.Vlist.nil"
let f_elt = Lang.extern_f ~category:Constructor "frama_c_wp.vlist.Vlist.elt"
let f_nth = Lang.extern_f "frama_c_wp.vlist.Vlist.nth"
let f_cons = Lang.extern_f "frama_c_wp.vlist.Vlist.cons"
let f_length = Lang.extern_f "frama_c_wp.vlist.Vlist.length"
let f_concat =
  let category = L.Operator {
      invertible = true ;
      associative = true ;
      commutative = false ;
      idempotent = false ;
      neutral = E_fun(f_nil,[]) ;
      absorbent = E_none ;
    } in
  Lang.extern_f ~category "frama_c_wp.vlist.Vlist.concat"
let f_repeat = Lang.extern_f "frama_c_wp.vlist.Vlist.repeat"

(* TODO[LC] specialized list equality *)
let _vlist_eq = Lang.extern_f "frama_c_wp.vlist.Vlist.vlist_eq"

(*--- ACSL Builtins ---*)

let () =
  begin
    let open LogicBuiltins in
    add_builtin "\\Nil"    []    f_nil ;
    add_builtin "\\Cons"   [A;A] f_cons ;
    add_builtin "\\nth"    [A;Z] f_nth ;
    add_builtin "\\length" [A]   f_length ;
    add_builtin "\\concat" [A;A] f_concat ;
    add_builtin "\\repeat" [A;Z] f_repeat ;
  end

let category e =
  match repr e with
  | Qed.Logic.Fun (f,_) when f_nil    @= f -> "Nil"
  | Qed.Logic.Fun (f,_) when f_cons   @= f -> "Cons"
  | Qed.Logic.Fun (f,_) when f_nth    @= f -> "Nth"
  | Qed.Logic.Fun (f,_) when f_length @= f -> "Length"
  | Qed.Logic.Fun (f,_) when f_concat @= f -> "Concat"
  | Qed.Logic.Fun (f,_) when f_repeat @= f -> "Repeat"
  | _ -> "_"

let rec pp_pattern fmt e =
  match repr e with
  | Qed.Logic.Fun (f, args) when
      f_nil    @= f ||
      f_cons   @= f ||
      f_nth    @= f ||
      f_length @= f ||
      f_concat @= f ||
      f_repeat @= f
    -> Format.fprintf fmt "(%s %a)" (category e) (Format.pp_print_list ~pp_sep:(fun fmt () -> Format.pp_print_string fmt " ") pp_pattern) args
  | _ -> Format.pp_print_string fmt "_"

(*--- Smart Constructors ---*)

let is_nil e = (* under-approximation of e==[] *)
  match repr e with
  | Qed.Logic.Fun (f,_) -> f_nil @= f
  | _ -> false

let v_nil t = e_fun ~result:t !@f_nil []
let v_elt e = e_fun !@f_elt [e]
let v_concat es tau = e_fun !@f_concat es ~result:tau
let v_length l = e_fun !@f_length [l]
let v_repeat s n tau = e_fun !@f_repeat [s;n] ~result:tau

let concat vs =
  let tl = typeof (List.hd vs) in
  v_concat vs tl

let list es = concat (List.map v_elt es)
let repeat s n = v_repeat s n (typeof s)
let vrepeat = function [s;n] -> repeat s n | _ -> raise Not_found

(* -------------------------------------------------------------------------- *)
(* --- Rewriters                                                          --- *)
(* -------------------------------------------------------------------------- *)

let rewrite_cons a w tau = (* a::w == [a]^w *)
  v_concat [v_elt a ; w] (Option.get tau)

let rewrite_length e =
  match repr e with
  | L.Fun( nil , [] ) when f_nil @= nil -> e_zero (* \length([]) == 0 *)
  | L.Fun( elt , [_] ) when f_elt @= elt -> e_one (* \length([x]) == 1 *)
  | L.Fun( concat , es ) when f_concat @= concat -> (* \length(\concat(...,x_i,...)) == \sum(...,\length(x_i),...)  *)
    e_sum (List.map v_length es)
  | L.Fun( repeat , [ u ; n ] ) when f_repeat @= repeat ->
    (* \length(u ^* n) == if 0<=n then n * \length(u) else 0 *)
    e_if (e_leq e_zero n) (e_mul n (v_length u)) e_zero
  | _ ->
    (* NB. do not considers \Cons because they are removed *)
    raise Not_found

let match_natural k =
  match repr k with
  | L.Kint z ->
    let k = try Z.to_int z with Z.Overflow -> raise Not_found in
    if 0 <= k then k else raise Not_found
  | _ -> raise Not_found

(* Why3 definition: [\nth(e,k)] is undefined for [k<0 || k>=\length(e)].
   So, the list cannot be destructured when the length is unknown  *)
let rec get_nth k e =
  match repr e with
  | L.Fun( concat , list ) when f_concat @= concat -> get_nth_list k list
  | L.Fun( elt , [x] ) when f_elt @= elt ->
    get_nth_elt k x (fun _ -> raise Not_found)
  | L.Fun( repeat , [x;n] ) when f_repeat @= repeat ->
    get_nth_repeat k x n (fun _ -> raise Not_found)
  | _ -> raise Not_found

and get_nth_list k = function
  | head::tail ->
    begin
      match repr head with
      | L.Fun( elt , [x] ) when f_elt @= elt ->
        get_nth_elt k x (fun k -> get_nth_list k tail)
      | L.Fun( repeat , [x;n] ) when f_repeat @= repeat ->
        get_nth_repeat k x n (fun k -> get_nth_list k tail)
      | _ -> raise Not_found
    end
  | [] -> raise Not_found

and get_nth_elt k x f =
  if k = 0 then x else (f (k-1))

and get_nth_repeat k x n f =
  let n = match_natural n in
  if n = 0 then raise Not_found ;
  let m = match_natural (rewrite_length x) in
  if m = 0 then raise Not_found ;
  let en = Z.of_int n in
  let em = Z.of_int m in
  let ek = Z.of_int k in
  if Z.(geq ek (mul en em)) then f (k -(n*m))
  else get_nth (k mod m) x

let rewrite_nth s k =
  get_nth (match_natural k) s

let rewrite_repeat s n =
  if decide (e_leq n e_zero) then (* n <=0 ==> (s *^ n) == [] *)
    v_nil (typeof s)
  else if equal n e_one then (* (s *^ 1) == s *)
    s
  else if is_nil s then (* ([] *^ n) == [] ; even if [n] is negative *)
    s
  else
    match repr s with
    | L.Fun( repeat , [s0 ; n0] ) (* n0>=0 && n>=0 ==> ((s0 *^ n0) *^ n) == (s0 *^ (n0 * n)) *)
      when (f_repeat @= repeat) &&
           (Cint.is_positive_or_null n) &&
           (Cint.is_positive_or_null n0) -> v_repeat s0 (e_mul n0 n) (typeof s)
    | _ -> raise Not_found

let rec leftmost a ms =
  match repr a with
  | L.Fun( concat , e :: es ) when f_concat @= concat ->
    leftmost e (es@ms)
  | L.Fun( repeat , [ u ; n ] ) when f_repeat @= repeat -> begin
      match (* tries to perform some rolling that do not depend on [n] *)
        (match ms with
         | b::ms ->
           let b,ms = leftmost b ms in
           let u,us = leftmost u [] in
           if decide (e_eq u b) then
             (*  u=b ==>  ((u^us)*^n) ^ b ^ ms  == u ^ (us^b)*^n) ^ ms *)
             Some (u, v_repeat (v_concat (us@[b]) (typeof a)) n (typeof a) :: ms)
           else None
         | _ -> None) with
      | Some res -> res
      | None ->
        if decide (e_lt e_zero n) then
          (* 0<n ==> (u*^n) ^ ms ==  u ^ (u*^(n-1)) ^ ms *)
          leftmost u (v_repeat u (e_sub n e_one) (typeof a) :: ms)
        else a , ms
    end
  | _ -> a , ms

(* [leftmost a] returns [s,xs] such that [a = s ^ x1 ^ ... ^ xn] *)
let leftmost a =
  let r = leftmost a [] in
  debugN 2 "Vlist.leftmost %a@ = %a (form: %s) ^ ... (%d more)@."
    pp_term a
    pp_term (fst r) (category (fst r))
    (List.length (snd r)) ;
  r

let rec rightmost ms a =
  match repr a with
  | L.Fun( concat , es ) when f_concat @= concat ->
    begin match List.rev es with
      | [] -> ms , a
      | e::es -> rightmost (ms @ List.rev es) e
    end
  | L.Fun( repeat , [ u ; n ] ) when f_repeat @= repeat -> begin
      match (* tries to perform some rolling that do not depend on [n] *)
        (match List.rev ms with
         | b::ms ->
           let ms,b = rightmost (List.rev ms) b in
           let us,u = rightmost [] u in
           if decide (e_eq u b) then
             (*  u=b ==>  (ms ^ b ^ (us^u)*^n) == ms ^ (b^us)*^n) ^ u *)
             Some (ms @ [ v_repeat (v_concat (b::us) (typeof a)) n (typeof a)], u)
           else None
         | _ -> None) with
      | Some res -> res
      | None ->
        if decide (e_lt e_zero n) then
          (* 0<n ==> ms ^ (u*^n) ==  ms ^ (u*^(n-1)) ^ u *)
          rightmost (ms @ [v_repeat u (e_sub n e_one) (typeof a)]) u
        else ms , a
    end
  | _ -> ms , a

(* [rightmost a] returns [s,xs] such that [a = x1 ^ ... ^ xn ^ s] *)
let rightmost a =
  let r = rightmost [] a in
  debugN 2 "Vlist.rightmost %a@ = (%d more) ... ^ %a (form: %s)@."
    pp_term a (List.length (fst r))
    pp_term (snd r) (category (snd r)) ;
  r

let leftmost_eq a b =
  let a , u = leftmost a in
  let b , v = leftmost b in
  if u <> [] || v <> [] then
    match is_equal a b with
    | L.Yes ->
      (* s ^ u1 ^ ...  = s ^ v1 ^ ...  <=>  u1 ^ ... = v1 ^ ... *)
      p_equal (v_concat u (typeof a)) (v_concat v (typeof a))
    | L.No when decide (e_eq (v_length a) (v_length b)) ->
      (* a <> b && \length(a)=\length(b) ==> a ^ u1 ^ ... <> b ^ v1 ^ ... *)
      p_false
    | _ -> raise Not_found
  else
    raise Not_found

let rightmost_eq a b =
  let u , a = rightmost a in
  let v , b = rightmost b in
  if u <> [] || v <> [] then
    match is_equal a b with
    | L.Yes ->
      (* u1 ^ ... ^ s = v1 ^ ... ^ s  <=>  u1 ^ ... = v1 ^ ... *)
      p_equal (v_concat u (typeof a)) (v_concat v (typeof a))
    | L.No when decide (e_eq (v_length a) (v_length b)) ->
      (* a <> b && \length(a)=\length(b) ==> u1 ^ ... ^ a <> v1 ^ ... ^ b *)
      p_false
    | _ -> raise Not_found
  else
    raise Not_found

let rewrite_is_nil ~nil a =
  let p_is_nil a = p_equal nil a  in
  match repr a with
  | L.Fun(concat,es) when f_concat @= concat ->
    (* \concat (s1,...,sn)==[] <==> (s1==[] && ... && sn==[]) *)
    p_all p_is_nil es
  | L.Fun(elt,[_]) when f_elt @= elt -> p_false (* [x]==[] <==> false *)
  | L.Fun(repeat,[s;n]) when f_repeat @= repeat ->
    (* (s *^ n)==[] <==> (s==[] || n<=0)  *)
    p_or (p_leq n e_zero) (p_is_nil s)
  | _ ->
    raise Not_found

(* Ensures xs to be a sub-sequence of ys, otherwise raise Not_found
   In such a case, (concat xs = concat ys) <==> (forall r in result, r = nil) *)
let rec subsequence xs ys =
  match xs , ys with
  | [],ys -> ys
  | x::rxs, y::rys ->
    if (decide (e_eq x y)) then subsequence rxs rys else y :: subsequence xs rys
  | _ -> raise Not_found

let elements a =
  match repr a with
  | L.Fun(concat,es) when f_concat @= concat -> true, es
  | _ -> false, [ a ]

(* Ensures that [a] or [b] is a sub-sequence of the other, otherwise [raise Not_found]
   In such a case, (concat xs = concat ys) <==> (forall r in result, r = nil) *)
let subsequence a b =
  let destruct_a, xs = elements a in
  let destruct_b, ys = elements b in
  if not (destruct_a || destruct_b) then raise Not_found;
  let shortest,xs,ys = if List.length xs <= List.length ys then a,xs,ys else b,ys,xs in
  let es = subsequence xs ys in
  (* xs=ys <==> forall s in es ; s = nil *)
  let nil = v_nil (typeof shortest) in
  (* [s] are elements of [ys] (the longest sequence) and [nil] has the same type than the [shortest] sequence *)
  let p_is_nil s = p_equal nil s in
  p_all p_is_nil es

let repeat_eq a x n b y m =
  let e_eq_x_y = e_eq x y in
  let e_eq_n_m = e_eq n m in
  if decide e_eq_x_y then
    (* s *^ n == s *^ m  <==>  ( n=m || (s *^ n == [] && s *^ m == []) ) *)
    let nil_a = v_nil (typeof a) in
    let nil_b = v_nil (typeof b) in
    p_or (p_bool e_eq_n_m)
      (p_and (p_equal a nil_b) (p_equal nil_a b))
  else if decide e_eq_n_m then
    (* x *^ n == y *^ n  <==> ( x == y || n<=0 ) *)
    p_or (p_leq n e_zero) (p_bool e_eq_x_y)
  else if decide (e_eq (v_length x) (v_length y)) then
    (* \length(x)=\length(y)  ==> ( x *^ n == y *^ m  <==> ( m == n && x == y) || (x *^ n == [] && y *^ m == [] ) *)
    let nil_a = v_nil (typeof a) in
    let nil_b = v_nil (typeof b) in
    p_or (p_and (p_bool e_eq_n_m) (p_bool e_eq_x_y))
      (p_and (p_equal a nil_b) (p_equal nil_a b))
  else raise Not_found

let rewrite_eq_sequence a b =
  debug "Vlist.rewrite_eq_sequence: tries to rewrite %a@ = %a@.- left pattern:  %a@.- right pattern: %a@."
    pp_term a pp_term b
    pp_pattern a pp_pattern b;
  match repr a , repr b with
  | L.Fun(nil,[]) , _ when f_nil @= nil -> rewrite_is_nil ~nil:a b
  | _ , L.Fun(nil,[]) when f_nil @= nil -> rewrite_is_nil ~nil:b a
  | _ -> try
      match repr a , repr b with
      | L.Fun(repeat_a, [x;n]), L.Fun(repeat_b, [y;m])
        when f_repeat @= repeat_a && f_repeat @= repeat_b ->
        repeat_eq a x n b y m
      | _ ->
        try leftmost_eq a b with Not_found ->
        try rightmost_eq a b with Not_found ->
          subsequence a b
    with Not_found ->
      if decide (e_neq (v_length a) (v_length b)) then
        p_false
      else raise Not_found

let rewrite_eq_length a b =
  match repr a , repr b with
  | L.Fun(length_a,[_]), L.Fun(length_b,[_]) when f_length @= length_a &&
                                                  f_length @= length_b ->
    (* N.B. cannot be simplified by the next patterns *)
    raise Not_found
  | _, L.Fun(length,[_]) when f_length @= length &&
                              decide (e_lt a e_zero) ->
    (* a < 0  ==>  ( a=\length(b) <=> false ) *)
    p_false
  | L.Fun(length,[_]), _ when f_length @= length &&
                              decide (e_lt b e_zero) ->
    (* b < 0  ==>  ( \length(a)<=b <=> false ) *)
    p_false
  | _ -> raise Not_found

let rewrite_leq_length a b =
  match repr a , repr b with
  | L.Fun(length_a,[_]), L.Fun(length_b,[_]) when f_length @= length_a &&
                                                  f_length @= length_b ->
    (* N.B. cannot be simplified by the next patterns *)
    raise Not_found
  | L.Fun(length,[_]), _ when f_length @= length &&
                              decide (e_lt b e_zero) ->
    (* b < 0  ==>  ( \length(a)<=b <=> false ) *)
    e_false
  (* N.B. the next rule does not allow to split on the sign of \length(a) with TIP
     | _, L.Fun(length,[_]) when f_length @= length &&
                              decide (e_leq a e_zero) ->
        (* a <= 0  ==>  ( a<=\length(b) <=> true ) *)
      e_true
  *)
  | _ -> raise Not_found


(* All Simplifications *)

let () =
  Context.register
    begin fun () ->
      set_builtin_2   !@f_nth rewrite_nth ;
      set_builtin_2'  !@f_cons rewrite_cons ;
      set_builtin_2   !@f_repeat rewrite_repeat ;
      set_builtin_1   !@f_length rewrite_length ;
      set_builtin_leq !@f_length rewrite_leq_length ;
      set_builtin_eqp !@f_length rewrite_eq_length ;
      set_builtin_eqp !@f_concat rewrite_eq_sequence ;
      set_builtin_eqp !@f_repeat rewrite_eq_sequence ;
      set_builtin_eqp !@f_nil rewrite_eq_sequence ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Typing                                                             --- *)
(* -------------------------------------------------------------------------- *)

let f_list = [ f_nil ; f_cons ; f_elt ; f_repeat ; f_concat ]

let check_adt = (@=) a_list
let check_tau = function L.Data(d,_) -> check_adt d | _ -> false
let check_term e =
  try match repr e with
    | L.Fvar x -> check_tau (tau_of_var x)
    | L.Bvar(_,t) -> check_tau t
    | L.Fun(lf , _ ) ->
      List.exists (fun f -> f @= lf) f_list || check_tau (typeof e)
    | _ -> false
  with Not_found -> false

let elist (t : tau) =
  match t with
  | L.Data(a,[e]) when check_adt a -> Some e
  | _ -> None

(* -------------------------------------------------------------------------- *)
(* --- Export                                                             --- *)
(* -------------------------------------------------------------------------- *)

class type engine =
  object
    method callstyle : Qed.Engine.callstyle
    method pp_atom : Format.formatter -> term -> unit
    method pp_flow : Format.formatter -> term -> unit
  end

let rec export (engine : #engine) fmt = function
  | [] ->
    begin match engine#callstyle with
      | E.CallVoid -> Format.pp_print_string fmt "nil()"
      | E.CallVar|E.CallApply -> Format.pp_print_string fmt "nil"
    end
  | e::es ->
    begin match repr e with
      | L.Fun( elt , [x] ) when f_elt @= elt ->
        apply engine fmt "cons" x es
      | _ ->
        apply engine fmt "concat" e es
    end

and apply (engine : #engine) fmt f x es =
  match engine#callstyle with
  | E.CallVar | E.CallVoid ->
    Format.fprintf fmt "@[<hov 2>%s(@,%a,@,%a)@]"
      f engine#pp_flow x (export engine) es
  | E.CallApply ->
    Format.fprintf fmt "@[<hov 2>(%s@ %a@ %a)@]"
      f engine#pp_atom x (export engine) es

let () =
  let open ExportWhy3.CC in
  Context.register
    begin fun () ->
      hack !@f_concat @@
      fun env tr ts ->
      let ty = cc_tau env tr in
      let rec elements = function
        | [] ->
          let nil = find_ls env "list.List.Nil" in
          Why3.Term.t_app nil [] ty
        | e::es ->
          let ls = elements es in
          match Lang.F.repr e with
          | Fun(f,[x]) when f_elt @= f ->
            let e = cc_term env x in
            let cons = find_ls env "list.List.Cons" in
            Why3.Term.t_app cons [e;ls] ty
          | _ ->
            let l = cc_term env e in
            let append = find_ls env "list.Append.(++)" in
            Why3.Term.t_app append [l;ls] ty
      in elements ts
    end

let () = Tactical.add_computer "wp:list" list
let () = Tactical.add_computer "wp:concat" concat
let () = Tactical.add_computer "wp:repeat" vrepeat

(* -------------------------------------------------------------------------- *)

let rec collect xs = function
  | [] -> List.rev xs , []
  | (e::es) as w ->
    begin match repr e with
      | L.Fun( elt , [x] ) when f_elt @= elt -> collect (x::xs) es
      | _ -> List.rev xs , w
    end

let pplist engine fmt xs = Qed.Plib.pp_listsep ~sep:"," engine#pp_flow fmt xs

let elements (engine : #engine) fmt xs =
  Format.fprintf fmt "@[<hov 2>[ %a ]@]" (pplist engine) xs

let rec pp_concat (engine : #engine) fmt es =
  let xs , es = collect [] es in
  begin
    (if xs <> [] then elements engine fmt xs) ;
    match es with
    | [] -> ()
    | m::ms ->
      if xs <> [] then Format.fprintf fmt " ^@ " ;
      engine#pp_atom fmt m ;
      if ms <> [] then
        ( Format.fprintf fmt " ^@ " ; pp_concat engine fmt ms )
  end

let pretty (engine : #engine) fmt es =
  if es = [] then Format.pp_print_string fmt "[]" else
    Format.fprintf fmt "@[<hov 2>%a@]" (pp_concat engine) es

let pprepeat (engine : #engine) fmt = function
  | [l;n] -> Format.fprintf fmt "@[<hov 2>(%a *^@ %a)@]" engine#pp_flow l engine#pp_flow n
  | es -> Format.fprintf fmt "@[<hov 2>repeat(%a)@]" (pplist engine) es

let shareable e =
  match repr e with
  | L.Fun( f , es ) -> not (f_elt @= f) && es != []
  | _ -> true

(* -------------------------------------------------------------------------- *)
