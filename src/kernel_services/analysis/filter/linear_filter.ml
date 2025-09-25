(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* Notations and conventions :
   - I is the identity matrix ;
   - A is the filter's state matrix ;
   - B is the filter's measure matrix ;
   - S is the filter's shift ;
   - ε is an infinite sequence of measures ;
   - C is the center of the measures' box ;
   - R is the radius of the measures' box ;
   - Everytime a radius is mentionned, it is always supposed all positive ;
   - |.| is the componentwise absolute value on matrices and vectors. *)

module Make (K : Field.S) = struct

  module Linear = Linear.Space (K)
  open Linear

  (* A 'n box is a 'n vector of intervals that, instead of being described as
     'n intervals, is described as a 'n vector center and a 'n vector radius. *)
  type 'n box = { center : 'n vector ; radius : 'n vector }

  (* Utilitary functions on boxes. The radius is forced to be all positive by
     the box constructor. Inclusion is componentwise. *)
  module Box = struct
    let ( < ) = Matrix.all_components_lower_than
    let make center radius = { center ; radius = Matrix.abs radius }
    let shift delta box = { box with center = Matrix.(box.center + delta) }
    let lower { center ; radius } = Matrix.(center - radius)
    let upper { center ; radius } = Matrix.(center + radius)
    let is_included l r = lower r < lower l && upper l < upper r
  end



  (* A filter is composed of an initial state, a state related structure and
     a measures related structure. *)
  type ('n, 'm) filter =
    { initial : 'n vector ; state : 'n state ; measure : ('n, 'm) measure }

  (* State related data are the filter's shift and its state matrix. *)
  and 'n state =
    { shift : 'n vector ; matrix : ('n, 'n) matrix }

  (* Measures related data are the measure space's box and the measure matrix. *)
  and ('n, 'm) measure =
    { space : 'm box ; matrix : ('n, 'm) matrix }

  (* Filter's constructor. *)
  let create ~initial ~shift
      ~measure_center ~measure_radius
      ~measure_matrix ~state_matrix =
    let state = { shift ; matrix = state_matrix } in
    let space = Box.make measure_center measure_radius in
    let measure = { space ; matrix = measure_matrix } in
    { initial ; state ; measure }



  (* Let binding operator memoizing sequences' elements. *)
  let ( let@ ) seq f = f (Seq.memoize seq)

  (* Returns the first non none element of a sequence, if any. Do not terminate
     on an infinite sequence of nones. *)
  let first s = Option.map fst Seq.(filter_map Datatype.identity s |> uncons)

  (* Returns the first window satisfying a given predicate until completed
     if any. For instance, using the predicate [x < 3] and the completion
     condition [start = length] on the sequence [5, 1, 4, 2, 3, 1, 4, ...],
     the returned window will be { start = 3 ; length = 3 }. The function
     stops the sequence evaluation as soon as a valid window is found.
     Do not terminate on a infinite sequence with no valid window. *)
  type window = { start : int ; length : int }
  let find_window pred completed seq =
    let exception Found of window in
    let incr w = { w with length = w.length + 1 } in
    let search window i data =
      let () = Async.yield () in
      match window with
      | None -> if pred data then Some { start = i ; length = 1 } else None
      | Some window when completed window -> raise (Found window)
      | Some window -> if pred data then Some (incr window) else None
    in
    try Seq.fold_lefti search None seq |> ignore ; None
    with Found window -> Some window



  (* This function performs a dichotomy search in the interval [0 .. 1] for
     as long as the given [duration], evaluating the given [compute] function
     at each step and returning the last result found. The first computed
     value is with the input one, then a half if the computation lead to
     a result, and so on and so forth. The implementation relies on the
     [Async] module and thus should be portable on Windows. *)
  let rec timed_dichotomy compute duration =
    let start = (Unix.times ()).tms_utime in
    let elapsed_time () = (Unix.times ()).tms_utime -. start in
    let cancel () = if elapsed_time () > duration then Async.cancel () in
    let start () = try compute K.one with Async.Cancel -> None in
    let job () = start () |> cancelable_dichotomy compute K.zero K.one in
    Async.with_progress cancel job ()

  (* Each dichotomy step is wrapped in a try-with that returns the last known
     result if the exception [Async.Cancel] is catched. *)
  and cancelable_dichotomy compute lower upper acc =
    try dichotomy_step compute lower upper acc
    with Async.Cancel -> acc

  (* At each step, if the computation leads to a result for the half-point
     candidate, the next step is perform on the lower half interval.
     Conservely, if no result is obtained, the next step is perform on the
     upper half interval. *)
  and dichotomy_step compute lower upper acc =
    let current = K.((upper + lower) / (of_int 2)) in
    let () = Async.yield () in
    match compute current with
    | None -> cancelable_dichotomy compute current upper acc
    | acc  -> cancelable_dichotomy compute lower current acc



  (* Let n ∈ ℕ, [state_power] be A^n and [measure] be the cumulated
     overapproximation of the n first measures represented as a box
     of center γ and of radius σ.
     The result of [limit state_power measure] is, assuming that the
     norm one of A^n is strictly lower than one, an overapproximation
     of the permanent behavior computed as the following box :
     { center = (I - A^n)^{-1} γ ; radius = (I - |A^n|)^{-1} σ }. *)
  let limit state_power measure =
    let open Option.Operators in
    let norm = Matrix.norm_one state_power in
    let n, _ = Matrix.dimensions state_power in
    let* state_power = if K.(norm < one) then Some state_power else None in
    let* center_shift = Matrix.(id n - state_power |> inverse) in
    let+ radius_shift = Matrix.(id n - abs state_power |> inverse) in
    let center = Matrix.(center_shift * measure.center) in
    let radius = Matrix.(radius_shift * measure.radius) in
    Box.make center radius

  (* Search for the first valid unrolling stop point, returning it along
     the permanent phase's overapproximation for which the unrolling stop
     point is valid. *)
  let stop_point state_powers measures abstractions max_unrolling threshold =
    let open Option.Operators in
    let below norm = K.(norm < threshold) in
    (* Compute the sequence of ||A^q|| here instead of in the map_fold to
       memoize the results. Not a huge optimization, but an easy one. *)
    let@ norms = Seq.map Matrix.norm_one state_powers in
    (* Simulate a map_fold using the three sequences and the iteration as
       the propagated state. At each step, we thus check if the assumptions
       on ||A^n|| is verified, compute the limit and check if we can find n
       consecutive iterations that are included in the limit. We have to cut
       the infinite sequence of abstractions here to ensure that we actually
       try to unroll more. Indeed, there is examples where, for a given
       iteration, there is no such window even if one can be found if we
       unroll once more. *)
    let folder (state_powers, measures, norms, spectral) =
      let* state_power, state_powers = Seq.uncons state_powers in
      let* measure, measures = Seq.uncons measures in
      let* norm, norms = Seq.uncons norms in
      let result =
        if below norm && Seq.(take spectral norms |> for_all below) then
          let* limit = limit state_power measure in
          let completed window = spectral = window.length in
          let is_included abstraction = Box.is_included abstraction limit in
          let abstractions = Seq.take (spectral + max_unrolling) abstractions in
          let+ window = find_window is_included completed abstractions in
          window.start, limit
        else None
      in Some (result, (state_powers, measures, norms, spectral + 1))
    in Seq.unfold folder (state_powers, measures, norms, 0) |> first



  (* A filter behavior is described as a transition phase and a permanent
     phase. The first one is a list of abstractions corresponding to the
     unrolled iterations. The second is an overapproximation of the filter's
     behavior up to infinity. *)
  type 'n bounds = 'n vector Field.bounds
  type 'n behavior = { transition : 'n bounds list ; permanent : 'n bounds }

  (* Behavior computation. Comes down to build the needed sequences, then use
     the timed dichotomic search to find the stop point and the limit. As the
     infinite sequence of unrolled abstractions is needed to search for the
     stop point, once it is found, we just have to gather the results. *)
  let behavior ?(timeout = 1.0) ?(maximal_unrolling = 200) f =
    let open Option.Operators in
    let dim = Vector.size f.initial in
    (* Sequence of all A^n. *)
    let power = Matrix.( * ) f.state.matrix in
    let@ state_powers = Seq.iterate power (Matrix.id dim) in
    (* Sequence of all A^n × X0. *)
    let reminder p = Matrix.(p * f.initial) in
    let@ initial_state_reminder = Seq.map reminder state_powers in
    (* Sequence of all ∑ A^t (B C + S) for t between 0 and n - 1. *)
    let measure_center = Matrix.(f.measure.matrix * f.measure.space.center) in
    let measure_center_shift = Matrix.(measure_center + f.state.shift) in
    let next_center center p = Matrix.(center + p * measure_center_shift) in
    let measures_center = Seq.scan next_center (Vector.zero dim) state_powers in
    (* Sequence of all ∑ |A^t| |B| |R| for t between 0 and n - 1. *)
    let delta = Matrix.(abs f.measure.matrix * abs f.measure.space.radius) in
    let next_radius radius p = Matrix.(radius + abs p * delta) in
    let measures_radius = Seq.scan next_radius (Vector.zero dim) state_powers in
    (* Sequence of overapproximating boxes related to measures, i.e without
       taking the initial state into account. *)
    let@ measures = Seq.map2 Box.make measures_center measures_radius in
    (* Sequence of complete overapproximations for each iterations, i.e
       including the initial state contributions. *)
    let@ abstractions = Seq.map2 Box.shift initial_state_reminder measures in
    (* Dichotomic search of the stop point. *)
    let search = stop_point state_powers measures abstractions in
    let+ until, limit = timed_dichotomy (search maximal_unrolling) timeout in
    (* Building the behavior data structure. *)
    let bounds box = Field.{ lower = Box.lower box ; upper = Box.upper box } in
    let transition = Seq.(take until abstractions |> map bounds) in
    { transition = List.of_seq transition ; permanent = bounds limit }

end
