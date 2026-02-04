(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* Notations and conventions :
 * - I is the identity matrix ;
 * - A is the system's state matrix ;
 * - B is the system's input matrix ;
 * - S is the system's shift ;
 * - μ is an infinite sequence of inputs ;
 * - C is the center of the inputs ball ;
 * - R is the radius of the inputs ball ;
 * - Everytime a radius is mentionned, it is always supposed all positive ;
 * - |.| is the componentwise absolute value on matrices and vectors. *)

module Make (K : Field.S) = struct

  (** Preliminary declarations **)

  module Linear = Linear.Space (K)
  module Ball = Ball.Make (K)
  open Option.Operators
  open Linear

  type 'n ball = 'n Ball.t


  (** Types specifications **)

  (* A LTI system full specification. *)
  type ('n, 'm) system =
    { state_matrix  : ('n, 'n) matrix
    ; input_matrix  : ('n, 'm) matrix
    ; input_space   : 'm ball
    ; shift         : 'n vector
    ; initial_state : 'n vector
    }

  (* Knowledge on LTI systems shared accross the module's functions:
   * - [n] is the system's order ;
   * - [center] corresponds to the constant part added at each iteration
   *   and is computed as {m B C + S} ;
   * - [radius] is simply {m |R|}. *)
  type ('n, 'm) knowledge =
    { n : 'n Nat.nat ; center : 'n vector ; radius : 'm vector }

  (* Information on an iteration {m n} of the system:
   * - [state_power] corresponds to the computation {m A^n}.
   * - [perturbations] corresponds to the maximal cumulative contributions of
   *   all previous inputs, which is a ball with center and radius computed
   *   respectively as {m ∑ A^t (B C + S)} and {m ∑ |A^t B| |R|},
   *   where {m t} is between {m 0} and {m n - 1}. *)
  type 'n iteration =
    { state_power : ('n, 'n) matrix ; perturbations : 'n ball }

  (* Behavior of the system, described as a transition phase of unrolled
   * iterations, and a permanent phase described by a unique overapproximated
   * ball. The spectral exponent used to computed the permanent abstraction
   * is also given. *)
  type 'n behavior =
    { transition : 'n ball list ; permanent : 'n ball }


  (** Behavior computation **)

  (* Computes the limit center. The computation is lazy for two reasons:
   * - The result is valid iif {m ρ(A) < 1}, which will eventually be
   *   proven through the limit computation.
   * - Proving {m ρ(A) < 1} comes down to finding a {m q ∈ ℕ} such
   *   as {m ||A^q||₁ < 1}. The limit center can then be computed
   *   as {m (I - A^q)^(-1) (∑ A^t (B C + S))} for {m t} between {m 0}
   *   and {m q - 1}. But, this computation's result is the same for
   *   all {m q} once the necessary condition is proven, so we only
   *   need to compute it as {m (I - A)^(-1) (B C + S)}.
   * Relying on lazyness is then a simple way to wait for a proof of
   * the necessary condition {m ρ(A) < 1} and then compute the
   * limit center only once. *)
  let compute_center_limit system knowledge = Lazy.from_fun @@ fun () ->
    let+ limit = Matrix.(inverse (id knowledge.n - system.state_matrix)) in
    Matrix.(limit * knowledge.center)

  (* Computes the systems iterations as a memoized infinite sequence
   * of [iteration] structures. *)
  let compute_iterations s { n ; center ; radius } =
    let zero = { state_power = Matrix.id n ; perturbations = Ball.zero n } in
    let compute_next_iteration { state_power ; perturbations } =
      let center = Matrix.(state_power * center) in
      let radius = Matrix.(abs (state_power * s.input_matrix) * radius) in
      let perturbations = Ball.(perturbations + make center radius) in
      (* Updating [state_power] at the end as [perturbations] is the sum
       * of all *previous* iterations contributions. *)
      let state_power = Matrix.(s.state_matrix * state_power) in
      { state_power ; perturbations }
    in Seq.(iterate compute_next_iteration zero |> memoize)

  (* Computes a ball overapproximating the system's behavior as the iteration
   * goes to infinity. The center of this ball is computed as described in
   * the [compute_center_limit] function. Its radius is an overapproximation
   * of the supremum for all possible input sequence {m μ} of the limit of
   * {m ∑ A^t B μ_(n - 1 - t)} with {m t} between {m 0} and {n - 1}.
   * The computation is done as follows:
   * - To prove that {m ρ(A) < 1}, the fonction searches for a {m q ∈ ℕ}
   *   such as {m ||A^q||₁ < 1}.
   * - The infinite sum is then divided in two: a finite sum of the {m q}
   *   first elements and the infinite reminding sum. Indeed, as {m q} grows,
   *   the finite sum becomes a better and better underapproximation of the
   *   limit radius, and the infinite reminder becomes smaller and smaller.
   * - The infinite reminder is approximated by the computation
   *   {m (I - |A^q|)^(-1) |A^q| (∑ |A^t B| |R|)}.
   * - The function checks that the overapproximated reminder does not count
   *   for more than a specified percentage of the limit ball's radius. *)
  let limit_behavior s ({ n ; _ } as knowledge) error_target iterations =
    let center_limit = compute_center_limit s knowledge in
    let ( let<?> ) b f = if b then f () else None in
    let compute_limit q { state_power ; perturbations } =
      let () = Async.yield () in
      let<?> () = K.(Matrix.norm_one state_power < one) in
      let abs_power = Matrix.abs state_power in
      let* center_limit = Lazy.force center_limit in
      let* limit = Matrix.(inverse (id n - abs_power)) in
      let underapprox = Ball.make center_limit perturbations.radius in
      let reminder = Matrix.(limit * abs_power * perturbations.radius) in
      let overapprox = Ball.(underapprox + make (Vector.zero n) reminder) in
      let error = Matrix.(scale (K.of_int 100) reminder / overapprox.radius) in
      let<?> () = K.(Vector.norm error < error_target) in
      Some (q, overapprox)
    in
    (* The sequence of limit overapproximations converges to the actual one,
     * but its not monotonous, and local minimums that are too precise to
     * work with may be there. To avoid this, we look for the worst
     * overapproximation in the first 10 candidates. *)
    let limits = Seq.(mapi compute_limit iterations |> filter_map Fun.id) in
    let limits = Seq.take 10 limits in
    let worst acc (q, candidate) =
      let () = Async.yield () in
      match acc with
      | None -> Some (q, candidate)
      | Some (q', worst) ->
        if Ball.is_included worst candidate
        then Some (q, candidate)
        else Some (q', worst)
    in Seq.fold_left worst None limits

  (* Searches for the first valid unrolling stop point for a given [limit]
   * found at the exponent [spectral]. A stop point [k] is valid if the
   * system behavior is included in [limit] for iteration [k] and for
   * the [spectral] following iterations. *)
  let search_unrolling_stop spectral limit iterations =
    let exception Found of int in
    let in_limit abst = Ball.is_included abst limit in
    let search window n abst =
      let () = Async.yield () in
      match window with
      | None -> if in_limit abst then Some (n, 1) else None
      | Some (start, l) when l = spectral -> raise (Found start)
      | Some (start, l) -> if in_limit abst then Some (start, l + 1) else None
    in
    try ignore (Seq.fold_lefti search None iterations) ; None
    with Found stop -> Some (Seq.take stop iterations |> List.of_seq)

  (* Computation of the system's behavior. No termination guarantee. *)
  let behavior_unbounded ~error_target (s : ('n, 'm) system) =
    let n = Vector.size s.initial_state in
    let radius = Matrix.(abs s.input_space.radius) in
    let center = Matrix.(s.input_matrix * s.input_space.center + s.shift) in
    let knowledge = { n ; radius ; center } in
    let iterations = compute_iterations s knowledge in
    let* spectral, limit = limit_behavior s knowledge error_target iterations in
    let reminder it = Matrix.(it.state_power * s.initial_state) in
    let abstraction it = Ball.(constant (reminder it) + it.perturbations) in
    let iterations = Seq.map abstraction iterations in
    let+ transition = search_unrolling_stop spectral limit iterations in
    { transition ; permanent = limit }

  (* Behavior computation with timeout mecanism. *)
  let behavior ?(timeout = 1.0) ~completion_target =
    let start = (Unix.times ()).tms_utime in
    let elapsed_time () = (Unix.times ()).tms_utime -. start in
    let cancel () = if elapsed_time () > timeout then Async.cancel () in
    Async.with_progress cancel @@ fun system ->
    let error_target = K.of_float (100.0 -. completion_target) in
    try behavior_unbounded ~error_target system
    with Async.Cancel -> None

  (* Pretty print a behavior. Used for test and debug purposes. *)
  let pretty_behavior fmt = function
    | None -> Unicode.pp_top fmt
    | Some { transition ; permanent } ->
      let lower, upper = Ball.bounds permanent in
      let pretty i =
        Format.fprintf fmt "* %d : [%a .. %a]@ "
          (Finite.to_int i)
          K.pretty (Vector.get i lower)
          K.pretty (Vector.get i upper)
      in
      Format.fprintf fmt "@[<v>" ;
      Format.fprintf fmt "Transition duration : %d iterations@ "
        (List.length transition) ;
      Format.fprintf fmt "State space invariant :@ " ;
      Finite.iter pretty (Vector.size lower) ;
      Format.fprintf fmt "@]"

end
