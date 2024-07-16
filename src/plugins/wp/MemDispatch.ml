(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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
(* --- Empty Memory Model                                                 --- *)
(* -------------------------------------------------------------------------- *)

open Either
open Product
open Lang.F
open Sigs
open Vset
open Dispatcher


module Make(D: Dispatcher) : Sigs.Model =
struct
  module ML = D.ML
  module MR = D.MR

  type loc = D.loc

  let datatype = "MemDispatch.Make"
  (** For projectification. Must be unique among models. *)

  let configure () =
    begin
      let rollback () =
        ML.configure () () ;
        MR.configure () () ;
      in
      rollback
    end
  (** Initializers to be run before using the model.
      Typically push {i Context} values and returns a function to rollback.
  *)

  let configure_ia ia =
    D.configure_ia ia
  (** Given an automaton, return a vertex's binder.
      Currently used by the automata compiler to bind current vertex.

  *)

  let hypotheses p =
    D.hypotheses p
  (** Computes the memory model partitionning of the memory locations.
      This function typically adds new elements to the partition received
      in input (that can be empty).
      ============================> TODO <======================================
  *)

  module Chunk : Chunk
    with type t = (ML.chunk, MR.chunk) Either.t =
  struct
    type t = (ML.chunk, MR.chunk) Either.t

    let self = "MemDispatcher.Chunk"
    (** Chunk names, for pretty-printing. *)

    let hash = function
      | Left  cl -> ML.Chunk.hash cl
      | Right cr -> 0x1000 + MR.Chunk.hash cr

    let equal ca cb =
      match ca, cb with
      | Left  c1, Left  c2 -> ML.Chunk.equal c1 c2
      | Right c1, Right c2 -> MR.Chunk.equal c1 c2
      | _, _ -> false

    let compare c1 c2 = (hash c1) - (hash c2)

    let pretty fmt = function
      | Left  cl -> Format.fprintf fmt "ML.%a" ML.Chunk.pretty cl
      | Right cr -> Format.fprintf fmt "MR.%a" MR.Chunk.pretty cr


    let tau_of_chunk = function
      | Left  c1 -> ML.Chunk.tau_of_chunk c1
      | Right c2 -> MR.Chunk.tau_of_chunk c2

    let basename_of_chunk = function
      | Left  c1 -> String.concat "." [ "ML" ; ML.Chunk.basename_of_chunk c1 ]
      | Right c2 -> String.concat "." [ "MR" ; MR.Chunk.basename_of_chunk c2 ]
    (** Used when generating fresh variables for a chunk. *)

    let is_framed = function
      | Left  c1 -> ML.Chunk.is_framed c1
      | Right c2 -> MR.Chunk.is_framed c2
      (** Whether the chunk is local to a function call.

          Means the chunk is separated from anyother call side-effects.
          If [true], entails that a function assigning everything can not modify
          the chunk. Only used for optimisation, it would be safe to always
          return [false]. *)
  end
  (** Memory Chunks.

      The concrete memory is partionned into a vector of abstract data.
      Each component of the partition is called a {i memory chunk} and
      holds an abstract representation of some part of the memory.

      Remark: memory chunks are not required to be independant from each other,
      provided the memory model implementation is consistent with the chosen
      representation. Conversely, a given object might be represented by
      several memory chunks.

  *)

  (* Chunks Sets and Maps. *)

  module Heap : Qed.Collection.S
    with type t = (ML.chunk, MR.chunk) t
    = Qed.Collection.Make(Chunk)

  type sigma = (ML.Sigma.t, MR.Sigma.t) product

  module Sigma =
  struct

    type chunk = (ML.chunk, MR.chunk) Either.t

    module Chunk = Heap

    type domain = Chunk.set
    type dom = (ML.Sigma.domain, MR.Sigma.domain) product

    let of_domain (domain:domain) : dom =
      let ldomain = Heap.Set.elements domain in
      let (left,right) = split ldomain in
      let left = ML.Sigma.Chunk.Set.of_list left in
      let right = MR.Sigma.Chunk.Set.of_list right in
      { left ; right }

    let to_domain (dom:dom) : domain =
      let left  = ML.Heap.Set.elements dom.left  in
      let right = MR.Heap.Set.elements dom.right in
      let left  = Heap.Set.of_list (List.map (fun l -> Left l)  left)  in
      let right = Heap.Set.of_list (List.map (fun r -> Right r) right) in
      Heap.Set.union left right

    type t = sigma

    let create () = {
      left  = ML.Sigma.create () ;
      right = MR.Sigma.create () ;
    }

    let pretty fmt sigma =
      Format.fprintf fmt "@[{@[%a@];@[%a@]}@]" ML.Sigma.pretty sigma.left MR.Sigma.pretty sigma.right

    let empty : domain = Heap.Set.empty

    let mem sigma = function
      | Left  cl -> ML.Sigma.mem sigma.left  cl
      | Right cr -> MR.Sigma.mem sigma.right cr

    let get sigma = function
      | Left  cl -> ML.Sigma.get sigma.left  cl
      | Right cr -> MR.Sigma.get sigma.right cr

    let writes (seq:sigma sequence) =
      to_domain {
        left  = ML.Sigma.writes (Product.sequence_left  seq) ;
        right = MR.Sigma.writes (Product.sequence_right seq) ;
      }

    let value sigma = function
      | Left  cl -> ML.Sigma.value sigma.left  cl
      | Right cr -> MR.Sigma.value sigma.right cr

    let copy = Product.map2 ML.Sigma.copy MR.Sigma.copy

    let join sigma1 sigma2 =
      Passive.union
        (ML.Sigma.join sigma1.left  sigma2.left )
        (MR.Sigma.join sigma1.right sigma2.right)

    let assigned ~pre:s1 ~post:s2 domain =
      let dom = of_domain domain in
      let bag_left  = ML.Sigma.assigned ~pre:s1.left  ~post:s2.left  dom.left  in
      let bag_right = MR.Sigma.assigned ~pre:s1.right ~post:s2.right dom.right in
      Bag.concat bag_left bag_right


    let choose = Product.map22 ML.Sigma.choose MR.Sigma.choose

    let merge s1 s2 =
      let (sl, pl1, pl2) = ML.Sigma.merge s1.left  s2.left  in
      let (sr, pr1, pr2) = MR.Sigma.merge s1.right s2.right in
      let s = { left = sl ; right = sr } in
      (s, Passive.union pl1 pr1, Passive.union pl2 pr2)

    let merge_list ls = (* TOCHECK *)
      let f (s1,lp) s2 =
        let (s,p1,p2) = merge s1 s2 in
        (s, p1::p2::lp)
      in
      match ls with
      | [] -> (create (), [])
      | [ s ] -> (s, [ Passive.empty ])
      | _ -> List.fold_left f (create (), []) ls

    let iter f sigma =
      ML.Sigma.iter (fun l -> f (Left  l)) sigma.left  ;
      MR.Sigma.iter (fun r -> f (Right r)) sigma.right ;
      ()

    let iter2 f =
      let f_left c v1 v2 = f (Left c) v1 v2 in
      let f_right c v1 v2 = f (Right c) v1 v2 in
      Product.iter2 (ML.Sigma.iter2 f_left) (MR.Sigma.iter2 f_right)

    let havoc_chunk = Product.map_either ML.Sigma.havoc_chunk MR.Sigma.havoc_chunk

    let havoc sigma domain =
      let dom = of_domain domain in
      Product.map22 ML.Sigma.havoc MR.Sigma.havoc sigma dom

    let havoc_any ~call:call = Product.map2 (ML.Sigma.havoc_any ~call) (MR.Sigma.havoc_any ~call)

    let remove_chunks sigma domain =
      let dom = of_domain domain in
      Product.map22 ML.Sigma.remove_chunks MR.Sigma.remove_chunks sigma dom

    let dom = Product.map2 ML.Sigma.domain MR.Sigma.domain

    let domain sigma =
      let dom = dom sigma in
      let domain = List.append
          (List.map (fun l -> Left  l) (ML.Heap.Set.elements dom.left ))
          (List.map (fun r -> Right r) (MR.Heap.Set.elements dom.right))
      in
      Chunk.Set.of_list domain

    let union = Chunk.Set.union

  end

  type chunk = Chunk.t
  type domain = Sigma.domain
  type segment = loc rloc

  type state = (ML.state, MR.state) product
  (** Internal (private) memory state description for later reversing the model. *)

  (** Returns a memory state description from a memory environement. *)
  let state = Product.map2 ML.state MR.state

  (** Try to interpret a term as an in-memory operation
      located at this program point. Only best-effort
      shall be performed, otherwise return [Mvalue].

      Recognized [Cil] patterns:
      - [Mvar x,[Mindex 0]] is rendered as [*x] when [x] has a pointer type
      - [Mmem p,[Mfield f;...]] is rendered as [p->f...] like in Cil
      - [Mmem p,[Mindex k;...]] is rendered as [p[k]...] to catch Cil [Mem(AddPI(p,k)),...] *)
  let lookup state term =
    try ML.lookup state.left term with
    | Not_found -> MR.lookup state.right term

  (** Try to interpret a sequence of states into updates.

      The result shall be exhaustive with respect to values that are printed as [Sigs.mval]
      values at [post] label {i via} the [lookup] function.
      Otherwise, those values would not be pretty-printed to the user. *)
  let updates states var =
    let bag_left  = ML.updates (Product.sequence_left  states) var in
    let bag_right = MR.updates (Product.sequence_right states) var in
    Bag.concat bag_left bag_right


  (** Propagate a sequent substitution inside the memory state. *)
  let apply f = Product.map2  (ML.apply f) (MR.apply f)


  (** Debug *)
  let iter f state = Product.iter (ML.iter f) (MR.iter f) state

  let pretty fmt loc = match loc with
    | Left  ll -> Format.fprintf fmt "ML.%a" ML.pretty ll
    | Right lr -> Format.fprintf fmt "MR.%a" MR.pretty lr
  (** pretty printing of memory location *)


  (** {2 Memory Model API} *)

  let vars = function
    | Left  ll -> ML.vars ll
    | Right lr -> MR.vars lr

  (** Return the logic variables from which the given location depend on. *)

  let occurs var = function
    | Left  ll -> ML.occurs var ll
    | Right lr -> MR.occurs var lr
  (** Test if a location depend on a given logic variable *)

  let null = D.null
  (** Return the location of the null pointer *)

  let literal ~eid:eid name = D.literal ~eid name
  (** Return the memory location of a constant string,
      the id is a unique identifier. *)

  let cvar var = D.cvar var
  (** Return the location of a C variable. *)

  let pointer_loc term = D.pointer_loc term
  (** Interpret an address value (a pointer) as an abstract location.
      Might fail on memory models not supporting pointers. *)

  let pointer_val = function
    | Left  ll -> ML.pointer_val ll
    | Right lr -> MR.pointer_val lr
  (** Return the adress value (a pointer) of an abstract location.
      Might fail on memory models not capable of representing pointers. *)

  let field loc fieldinfo =
    let left  = fun l -> ML.field l fieldinfo in
    let right = fun r -> MR.field r fieldinfo in
    Either.map ~left ~right loc
  (** Return the memory location obtained by field access from a given
      memory location. *)

  let shift loc ty term = match loc with
    | Left  l -> D.deref_left  l (ML.shift l ty term)
    | Right r -> D.deref_right r (MR.shift r ty term)
  (** Return the memory location obtained by array access at an index
      represented by the given {!term}. The element of the array are of
      the given {!c_object} type. *)

  let base_addr = Either.map ~left:ML.base_addr ~right:MR.base_addr
  (** Return the memory location of the base address of a given memory
      location. *)

  let base_offset = function
    | Left  ll -> ML.base_offset ll
    | Right lr -> MR.base_offset lr
  (** Return the offset of the location, in bytes, from its base_addr. *)

  let block_length (sigma:sigma) ty = function
    | Left  ll -> ML.block_length sigma.left  ty ll
    | Right lr -> MR.block_length sigma.right ty lr
  (**  Returns the length (in bytes) of the allocated block containing
       the given location. *)

  let cast objs = Either.map ~left:(ML.cast objs) ~right:(MR.cast objs)

  (** Cast a memory location into another memory location.
      For [cast ty loc] the cast is done from [ty.pre] to [ty.post].
      Might fail on memory models not supporting pointer casts. *)

  let loc_of_int ty term = D.loc_of_int ty term
  (** Cast a term representing an absolute memory address (to some c_object)
      given as an integer, into an abstract memory location. The sigma parameter
      is meant to assure that the cast returns a pointer only if in this given
      sigma, the physical address makes sense.

      @before Frama-C+dev there was no sigma parameter
  *)

  let int_of_loc c_int = function
    | Left  ll -> ML.int_of_loc c_int ll
    | Right lr -> MR.int_of_loc c_int lr
  (** Cast a memory location into its absolute memory address,
      given as an integer with the given C-type. *)

  let domain ty = function
    | Left  ll -> Heap.Set.of_list (List.map (fun l -> Left l)  (ML.Heap.Set.elements (ML.domain ty ll)))
    | Right lr -> Heap.Set.of_list (List.map (fun r -> Right r) (MR.Heap.Set.elements (MR.domain ty lr)))
  (** Compute the set of chunks that hold the value of an object with
      the given C-type. It is safe to retun an over-approximation of the
      chunks involved. *)

  let is_well_formed sigma =
    p_and (ML.is_well_formed sigma.left) (MR.is_well_formed sigma.right)
  (** Provides the constraint corresponding to the kind of data stored by all
      chunks in sigma. *)

  let load sigma ty = function
    | Left  ll1 -> begin match ML.load sigma.left  ty ll1 with
        | Val t   -> Val t
        | Loc ll2 -> Loc (D.deref_left  ll1 ll2)
      end
    | Right lr1 -> begin match MR.load sigma.right ty lr1 with
        | Val t   -> Val t
        | Loc lr2 -> Loc (D.deref_right lr1 lr2)
      end
  (** Return the value of the object of the given type at the given location in
      the given memory state. *)

  let load_init sigma ty = function
    | Left  ll -> ML.load_init sigma.left  ty ll
    | Right lr -> MR.load_init sigma.right ty lr
  (** Return the initialization status at the given location in the given
      memory state. *)

  let stored sigmas ty loc term = match loc with
    | Left  ll -> ML.stored (Product.sequence_left  sigmas) ty ll term
    | Right lr -> MR.stored (Product.sequence_right sigmas) ty lr term
  (**
     Return a set of formula that express a modification between two memory
     state.

     [stored sigma ty loc t] returns a set of formula expressing that
     [sigma.pre] and [sigma.post] are identical except for an object [ty] at
     location [loc] which is represented by [t] in [sigma.post].
  *)

  let stored_init sigmas ty loc term = match loc with
    | Left  ll -> ML.stored_init (Product.sequence_left  sigmas) ty ll term
    | Right lr -> MR.stored_init (Product.sequence_right sigmas) ty lr term
  (**
     Return a set of formula that express a modification of the initialization
     status between two memory state.

     [stored_init sigma ty loc t] returns a set of formula expressing that
     [sigma.pre] and [sigma.post] are identical except for an object [ty] at
     location [loc] which has a new init represented by [t] in [sigma.post].
  *)

  let copied sigmas ty loc1 loc2 = (* TOCHECK *) match loc1, loc2 with
    | Left  ll1, Left  ll2 ->
      ML.copied (Product.sequence_left  sigmas) ty ll1 ll2
    | Right lr1, Right lr2 ->
      MR.copied (Product.sequence_right sigmas) ty lr1 lr2
    | _,_ -> begin match load sigmas.pre ty loc1 with
        | Val t   -> stored sigmas ty loc2 t
        | Loc loc -> stored sigmas ty loc2 (pointer_val loc)
      end
  (**
     Return a set of equations that express a copy between two memory state.

     [copied sigma ty loc1 loc2] returns a set of formula expressing that the
     content for an object [ty] is the same in [sigma.pre] at [loc1] and in
     [sigma.post] at [loc2].
  *)

  let copied_init sigmas ty loc1 loc2 = (* TOCHECK *) match loc1, loc2 with
    | Left  ll1, Left  ll2 ->
      ML.copied_init (Product.sequence_left  sigmas) ty ll1 ll2
    | Right lr1, Right lr2 ->
      MR.copied_init (Product.sequence_right sigmas) ty lr1 lr2
    | _,_ ->
      stored_init sigmas ty loc2 (load_init sigmas.pre ty loc1)
  (**
     Return a set of equations that express a copy of an initialized state
     between two memory state.

     [copied sigma ty loc1 loc2] returns a set of formula expressing that the
     initialization status for an object [ty] is the same in [sigma.pre] at
     [loc1] and in [sigma.post] at [loc2].
  *)

  let assigned sigma ty divergent_locs =
    match divergent_locs with
    (* loc_left *)
    | Sloc (Left ll) -> ML.assigned (Product.sequence_left sigma) ty (Sloc ll)
    | Sarray (Left ll, ty, size) -> ML.assigned (Product.sequence_left sigma) ty (Sarray (ll,ty,size))
    | Srange (Left ll, ty, inf, sup) -> ML.assigned (Product.sequence_left sigma) ty (Srange (ll, ty, inf, sup))
    | Sdescr (vars, Left ll, p) -> ML.assigned (Product.sequence_left sigma) ty (Sdescr (vars, ll, p))
    (* loc_right *)
    | Sloc (Right lr) -> MR.assigned (Product.sequence_right sigma) ty (Sloc lr)
    | Sarray (Right lr, ty, size) -> MR.assigned (Product.sequence_right sigma) ty (Sarray (lr,ty,size))
    | Srange (Right lr, ty, inf, sup) -> MR.assigned (Product.sequence_right sigma) ty (Srange (lr, ty, inf, sup))
    | Sdescr (vars, Right lr, p) -> MR.assigned (Product.sequence_right sigma) ty (Sdescr (vars, lr, p))
  (**
     Return a set of formula that express that two memory state are the same
     except at the given set of memory location.

     This function can over-approximate the set of given memory location (e.g
     it can return [true] as if the all set of memory location was given).
  *)

  let is_null l = D.is_null l
  (** Return the formula that check if a given location is null *)

  let loc_eq loc_a loc_b = (* TODO: déléguer le cas croisé à D ==> plutôt mettre assert false *)
    match loc_a, loc_b with
    | Right _, Left _| Left _, Right _ -> p_and (is_null loc_a) (is_null loc_b)
    | Left  la, Left  lb -> ML.loc_eq la lb
    | Right la, Right lb -> MR.loc_eq la lb
  let loc_lt loc_a loc_b = match loc_a, loc_b with
    | Right _, Left _| Left _, Right _ -> assert false
    | Left  la, Left  lb -> ML.loc_lt la lb
    | Right la, Right lb -> MR.loc_lt la lb
  let loc_neq loc_a loc_b = (* TODO: déléguer le cas croisé à D ==> plutôt mettre assert false *)
    match loc_a, loc_b with
    | Right _, Left _| Left _, Right _ -> p_or (p_not (is_null loc_a)) (p_not (is_null loc_b))
    | Left  la, Left  lb -> ML.loc_neq la lb
    | Right la, Right lb -> MR.loc_neq la lb
  let loc_leq loc_a loc_b = match loc_a, loc_b with
    | Right _, Left _| Left _, Right _ -> assert false
    | Left  la, Left  lb -> ML.loc_leq la lb
    | Right la, Right lb -> MR.loc_leq la lb
  (** Memory location comparisons *)

  let loc_diff ty loc_a loc_b = match loc_a, loc_b with
    | Right _, Left _| Left _, Right _ -> assert false
    | Left  la, Left  lb -> ML.loc_diff ty la lb
    | Right la, Right lb -> MR.loc_diff ty la lb
  (** Compute the length in bytes between two memory locations *)

  let valid sigma acs = function
    (* loc_left *)
    | Rloc (ty, Left  ll) -> ML.valid sigma.left acs (Rloc (ty,ll))
    | Rrange (Left  ll, ty, inf, sup) -> ML.valid sigma.left  acs (Rrange (ll, ty, inf, sup))
    (* loc_right *)
    | Rloc (ty, Right lr) -> MR.valid sigma.right acs (Rloc (ty,lr))
    | Rrange (Right lr, ty, inf, sup) -> MR.valid sigma.right acs (Rrange (lr, ty, inf, sup))
  (** Return the formula that tests if a memory state is valid
      (according to {!acs}) in the given memory state at the given
      segment.
  *)

  let frame sigma = List.append (ML.frame sigma.left) (MR.frame sigma.right)
  (** Assert the memory is a proper heap state preceeding the function
      entry point. *)

  let alloc sigma vars =
    let (varl, varr) = partition D.cvar vars in
    Product.map2 (fun s -> ML.alloc s varl) (fun s -> MR.alloc s varr) sigma
  (** Allocates new chunk for the validity of variables. *)

  let initialized sigma segment =
    match segment with
    (* loc_left *)
    | Rloc (ty, Left ll) -> ML.initialized sigma.left (Rloc (ty,ll))
    | Rrange (Left ll, ty, inf, sup) -> ML.initialized sigma.left (Rrange (ll, ty, inf, sup))
    (* loc_right *)
    | Rloc (ty, Right lr) -> MR.initialized sigma.right (Rloc (ty,lr))
    | Rrange (Right lr, ty, inf, sup) -> MR.initialized sigma.right (Rrange (lr, ty, inf, sup))
  (** Return the formula that tests if a memory state is initialized
      (according to {!acs}) in the given memory state at the given
      segment.
  *)

  let invalid sigma = function
    (* loc_left *)
    | Rloc (ty, Left  l) -> ML.invalid sigma.left  (Rloc (ty,l))
    | Rrange (Left  l, ty, inf, sup) -> ML.invalid sigma.left  (Rrange (l, ty, inf, sup))
    (* loc_right *)
    | Rloc (ty, Right l) -> MR.invalid sigma.right (Rloc (ty,l))
    | Rrange (Right l, ty, inf, sup) -> MR.invalid sigma.right (Rrange (l, ty, inf, sup))

  (** Returns the formula that tests if the entire memory is invalid
      for write access. *)

  let scope sigma scope vars =
    let (varl, varr) = partition D.cvar vars in
    List.append
      (ML.scope (Product.sequence_left  sigma) scope varl)
      (MR.scope (Product.sequence_right sigma) scope varr)
  (** Manage the scope of variables.  Returns the updated memory model
      and hypotheses modeling the new validity-scope of the variables. *)

  let global sigma p =
    p_and (ML.global sigma.left p) (MR.global sigma.right p)
  (** Given a pointer value [p], assumes this pointer [p] (when valid)
      is allocated outside the function frame under analysis. This means
      separated from the formals and locals of the function. *)

  let included s1 s2 = (* TODO: dans la construction des range, multiplier la taille de tau1 ou tau2 (ici o1 ou o2) *) match s1, s2 with
    (* loc_left x2 *)
    | Rloc (ty1, Left ll1), Rloc (ty2, Left ll2) ->
      ML.included (Rloc (ty1, ll1)) (Rloc (ty2, ll2))
    | Rloc (ty1, Left ll1), Rrange (Left ll2, ty2, inf, sup) ->
      ML.included (Rloc (ty1,ll1)) (Rrange (ll2,ty2,inf,sup))
    | Rrange (Left ll1, ty1, inf, sup), Rloc (ty2, Left ll2) ->
      ML.included (Rrange (ll1,ty1,inf,sup)) (Rloc (ty2,ll2))
    | Rrange (Left ll1, ty1, inf1, sup1), Rrange (Left ll2, ty2, inf2, sup2) ->
      ML.included (Rrange (ll1,ty1,inf1,sup1)) (Rrange (ll2,ty2,inf2,sup2))
    (* loc_right x2 *)
    | Rloc (ty1, Right lr1), Rloc (ty2, Right lr2) ->
      MR.included (Rloc (ty1, lr1)) (Rloc (ty2, lr2))
    | Rloc (ty1, Right lr1), Rrange (Right lr2, ty2, inf, sup) ->
      MR.included (Rloc (ty1,lr1)) (Rrange (lr2,ty2,inf,sup))
    | Rrange (Right ll1, ty1, inf, sup), Rloc (ty2, Right ll2) ->
      MR.included (Rrange (ll1,ty1,inf,sup)) (Rloc (ty2,ll2))
    | Rrange (Right lr1, ty1, inf1, sup1), Rrange (Right lr2, ty2, inf2, sup2) ->
      MR.included (Rrange (lr1,ty1,inf1,sup1)) (Rrange (lr2,ty2,inf2,sup2))
    (* Cross case: Rloc x Rloc *)
    | Rloc (tyl, Left  ll), Rloc (tyr, Right lr) ->
      p_and (ML.is_null ll) (MR.included (Rloc (tyl, MR.null)) (Rloc (tyr, lr)))
    | Rloc (tyr, Right lr), Rloc (tyl, Left  ll) ->
      p_and (MR.is_null lr) (ML.included (Rloc (tyr, ML.null)) (Rloc (tyl, ll)))
    (* Cross case: Rloc x Rrange *)
    | Rloc (tyl, Left  ll), Rrange (Right lr, tyr, infr, supr) ->
      p_and (ML.is_null ll) (MR.included (Rloc (tyl, MR.null)) (Rrange (lr, tyr, infr, supr)))
    | Rloc (tyr, Right lr), Rrange (Left  ll, tyl, infl, supl) ->
      p_and (MR.is_null lr) (ML.included (Rloc (tyr, ML.null)) (Rrange (ll, tyl, infl, supl)))
    (* Cross case: Rrange x Rloc *)
    | Rrange (Right lr, tyr, infr, supr), Rloc (tyl, Left  ll) ->
      let r_range : set = [ Range (infr, supr) ] in
      p_or (Vset.is_empty r_range) (
        p_and
          (ML.is_null (ML.base_addr ll))
          (MR.included (Rrange (lr, tyr, infr, supr)) (Rloc (tyl, MR.null)))
      )
    | Rrange (Left  ll, tyl, infl, supl), Rloc (tyr, Right lr) ->
      let l_range : set = [ Range (infl, supl) ] in
      p_or (Vset.is_empty l_range) (
        p_and
          (MR.is_null (MR.base_addr lr))
          (ML.included (Rrange (ll, tyl, infl, supl)) (Rloc (tyr, ML.null)))
      )
    (* Cross case: Rrange x Rrange *)
    | Rrange (Right lr, _tyr, infr, supr), Rrange (Left  ll, _tyl, infl, supl) ->
      let r_range : set = [ Range (infr, supr) ] in
      let l_range : set = [ Range (infl, supl) ] in
      (* TOCHECK: should we unify tyl and tyr ? *)
      p_or (Vset.is_empty r_range) (
        p_and (ML.is_null (ML.base_addr ll)) (
          p_and (MR.is_null (MR.base_addr lr))
            (subset r_range l_range)
        ))
    | Rrange (Left  ll, _tyl, infl, supl), Rrange (Right lr, _tyr, infr, supr) ->
      let r_range : set = [ Range (infr, supr) ] in
      let l_range : set = [ Range (infl, supl) ] in
      (* TOCHECK: should we unify tyl and tyr ? *)
      p_or (Vset.is_empty l_range) (
        p_and (ML.is_null (ML.base_addr ll)) (
          p_and (MR.is_null (MR.base_addr lr))
            (subset l_range r_range)
        ))
  (* Rrange left + la..lb , Rrange right + ra..rb ->
     construire des range avec Vset et faire les tests avec Vset
     (is_empty la lb)
     \/ (ML.is_null (base_addr l)
        /\ MR.is_null (base_addr r)
        /\ la..lb included in ra..rb)  *)
  (* Rloc left ,  Rrange right + ra..rb
     -> ML.is_null left /\ MR.is_null right /\ 0 \in ra..rb *)
  (** Return the formula that tests if two segment are included *)

  let separated s1 s2 = match s1, s2 with
    (* loc_left x2 *)
    | Rloc (ty1, Left ll1), Rloc (ty2, Left ll2) ->
      ML.separated (Rloc (ty1, ll1)) (Rloc (ty2, ll2))
    | Rloc (ty1, Left ll1), Rrange (Left ll2, ty2, inf, sup) ->
      ML.separated (Rloc (ty1,ll1)) (Rrange (ll2,ty2,inf,sup))
    | Rrange (Left ll2, ty2, inf, sup), Rloc (ty1, Left ll1) ->
      ML.separated (Rrange (ll2,ty2,inf,sup)) (Rloc (ty1,ll1))
    | Rrange (Left ll1, ty1, inf1, sup1), Rrange (Left ll2, ty2, inf2, sup2) ->
      ML.separated (Rrange (ll1,ty1,inf1,sup1)) (Rrange (ll2,ty2,inf2,sup2))
    (* loc_right x2 *)
    | Rloc (ty1, Right lr1), Rloc (ty2, Right lr2) ->
      MR.separated (Rloc (ty1, lr1)) (Rloc (ty2, lr2))
    | Rloc (ty1, Right lr1), Rrange (Right lr2, ty2, inf, sup) ->
      MR.separated (Rloc (ty1,lr1)) (Rrange (lr2,ty2,inf,sup))
    | Rrange (Right lr2, ty2, inf, sup), Rloc (ty1, Right lr1) ->
      MR.separated (Rrange (lr2,ty2,inf,sup)) (Rloc (ty1,lr1))
    | Rrange (Right lr1, ty1, inf1, sup1), Rrange (Right lr2, ty2, inf2, sup2) ->
      MR.separated (Rrange (lr1,ty1,inf1,sup1)) (Rrange (lr2,ty2,inf2,sup2))
    (* Cross case: Rloc x Rloc *)
    | Rloc (tyl, Left  ll), Rloc (tyr, Right lr) ->
      p_imply (ML.is_null ll) (MR.separated (Rloc (tyl, MR.null)) (Rloc (tyr, lr)))
    | Rloc (tyr, Right lr), Rloc (tyl, Left  ll) ->
      p_imply (MR.is_null lr) (ML.separated (Rloc (tyr, ML.null)) (Rloc (tyl, ll)))
    (* Cross case: Rloc x Rrange *)
    | Rloc (tyl, Left  ll), Rrange (Right lr, tyr, infr, supr) ->
      p_imply (ML.is_null ll) (MR.separated (Rloc (tyl, MR.null)) (Rrange (lr, tyr, infr, supr)))
    | Rloc (tyr, Right lr), Rrange (Left  ll, tyl, infl, supl) ->
      p_imply (MR.is_null lr) (ML.separated (Rloc (tyr, ML.null)) (Rrange (ll, tyl, infl, supl)))
    (* Cross case: Rrange x Rloc *)
    | Rrange (Right lr, tyr, infr, supr), Rloc (tyl, Left  ll) ->
      let r_range : set = [ Range (infr, supr) ] in
      p_or (Vset.is_empty r_range) (
        p_and (ML.is_null (ML.base_addr ll)) (MR.included (Rrange (lr, tyr, infr, supr)) (Rloc (tyl, MR.null)))
      )
    | Rrange (Left  ll, tyl, infl, supl), Rloc (tyr, Right lr) ->
      let l_range : set = [ Range (infl, supl) ] in
      p_or (Vset.is_empty l_range) (
        p_and (MR.is_null (MR.base_addr lr)) (ML.included (Rrange (ll, tyl, infl, supl)) (Rloc (tyr, ML.null)))
      )
    (* Cross case: Rrange x Rrange *)
    | Rrange (Right lr, _tyr, infr, supr), Rrange (Left  ll, _tyl, infl, supl) ->
      let r_range : set = [ Range (infr, supr) ] in
      let l_range : set = [ Range (infl, supl) ] in
      (* TOCHECK: should we unify tyl and tyr ? *)
      p_or (Vset.is_empty r_range) (
        p_and (ML.is_null (ML.base_addr ll)) (
          p_and (MR.is_null (MR.base_addr lr)) (subset r_range l_range)
        ))
    | Rrange (Left  ll, _tyl, infl, supl), Rrange (Right lr, _tyr, infr, supr) ->
      let r_range : set = [ Range (infr, supr) ] in
      let l_range : set = [ Range (infl, supl) ] in
      (* TOCHECK: should we unify tyl and tyr ? *)
      p_or (Vset.is_empty l_range) (
        p_and (ML.is_null (ML.base_addr ll)) (
          p_and (MR.is_null (MR.base_addr lr)) (subset l_range r_range)
        ))
      (** Return the formula that tests if two segment are separated *)

end
