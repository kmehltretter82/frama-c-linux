(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(* Important notations and conventions.

   In all this file, the following notations are used :
   - I is the identity matrix ;
   - S is the shift matrix, i.e an identity matrix augmented with a zero-row
     on top and a zero column on the right ;
   - A is the filter's state matrix ;
   - B is a source matrix. *)



module Make (Field : Field.S) = struct

  module Linear = Linear.Space (Field)
  open Pretty_utils
  open Linear
  open Nat



  (* A source describes a source of measures, for instance a specific sensor,
     that is treated at each iteration by the filter. Measures can be centered
     around any scalar, and are thus described by a center and a deviation. The
     given source matrix describes how the current and past measures are taken
     into account by the filter. *)
  type 'n source =
    | Source : ('n, 'm succ) source_data -> 'n source

  and ('n, 'm) source_data =
    { matrix : ('n, 'm) matrix
    ; measure_center : scalar
    ; measure_deviation : scalar
    }

  (* Sources constructors. *)
  let source (type n m) ~(matrix : (n succ, m succ) matrix) ~center ~deviation =
    Source { matrix ; measure_center = center ; measure_deviation = deviation }

  (* Sources pretty printer. *)
  let pretty_source : type n. n source formatter = fun fmt (Source s) ->
    let { matrix = m ; measure_center = c ; measure_deviation = dev } = s in
    Format.fprintf fmt "@[<v>" ;
    Format.fprintf fmt "Source:@ " ;
    Format.fprintf fmt "- Measure : %a ± %a@ " Field.pretty c Field.pretty dev ;
    Format.fprintf fmt "- Contributions :@   @[<v>%a@]@ @ " Matrix.pretty m ;
    Format.fprintf fmt "@]"



  (* A filter is composed of a center, a constant vector added to the state at
     each iteration, a state matrix, describing how the current and past states
     are taken into account, and a list of sources. *)
  type 'n filter =
    | Filter : 'n succ filter_data -> 'n succ filter

  and 'n filter_data =
    { center  : 'n vector
    ; state   : ('n, 'n) matrix
    ; sources : 'n source list
    }

  (* Filters constructor. *)
  let create ~state ~center ~sources =
    Filter { center ; state ; sources }

  (* Filters pretty printers. *)
  let pretty : type n. n filter formatter = fun fmt (Filter f) ->
    let pp_sep = Format.pp_print_cut in
    let pp_sources = Format.pp_print_list ~pp_sep pretty_source in
    Format.fprintf fmt "@[<v>" ;
    Format.fprintf fmt "Filter:@ @ " ;
    Format.fprintf fmt "- Center  :@ @   @[<v>%a@]@ @ " Vector.pretty f.center ;
    Format.fprintf fmt "- State   :@ @   @[<v>%a@]@ @ " Matrix.pretty f.state ;
    Format.fprintf fmt "- Sources :@ @   @[<v>%a@]@ @ " pp_sources f.sources ;
    Format.fprintf fmt "@]"



  (* An extended source provides a way to compute the cumulated contribution of
     a measure at a given iteration [t]. This contribution is computed as the
     sum for i between 0 and [t] (both included) of A^(t-i) x B x S^i. *)
  type 'n extended_source =
    | Extended : ('n, 'm succ) extended_data -> 'n extended_source

  and ('n, 'm) extended_data =
    ('n, 'm) source_data * (int -> ('n, 'm) matrix)

  (* The function computing the cumulated contributions is memoized. *)
  let extend_source state (Source data) =
    let order, delay = Matrix.dimensions data.matrix in
    let shift = Matrix.power (Matrix.shift delay) in
    let cache = Datatype.Int.Hashtbl.create 17 in
    let find i = Datatype.Int.Hashtbl.find cache i in
    let save i v = Datatype.Int.Hashtbl.add cache i v ; v in
    let compute =
      let rec compute t i =
        if 0 <= i && i <= t then
          let from_state = state (t - i) in
          let from_shift = shift i in
          let from_iter = Matrix.(from_state * data.matrix * from_shift) in
          let from_previous = compute t (i + 1) in
          Matrix.(from_iter + from_previous)
        else Matrix.zero order delay
      in fun t -> try find t with Not_found -> compute t 0 |> save t
    in Extended (data, compute)



  (* A filter's invariant is a pair of vector, the first one containing lower
     bounds for each state variables, and the second one containing upper bounds
     for those state variables. *)
  type 'n invariant = 'n vector * 'n vector
  type 'n finite = 'n Finite.finite

  (* Lower bound for a given dimension. *)
  let lower : type n. n finite -> n invariant -> scalar = fun i (lower, _) ->
    Linear.Matrix.get i Finite.first lower

  (* Upper bound for a given dimension. *)
  let upper : type n. n finite -> n invariant -> scalar = fun i (_, upper) ->
    Linear.Matrix.get i Finite.first upper

  (* Bounds for a given dimension. *)
  let bounds i invariant = (lower i invariant, upper i invariant)



  (* Invariant computation. The computation of the sum of all past
     contributions, and in particuler the oldest ones, implies to check
     if an infinite series converge and to compute its limit. This is done
     by grouping iterations by pack of size [e] and factorizing the common
     state matrix power. This leads to an infinite geometric series in the
     matrix space. If the spectral radius of this matrix is stricly lower
     than one, then the series converge and its limit at infinity can be
     computed as (I - A^e)^(-1). *)
  let invariant : type n. n filter -> int -> n invariant option = fun f e ->
    let open Option.Operators in

    (* Computation of the spectral radius at the given exponent. As the power
       computation is memoized, it will be cheap to retrieve the spectral
       matrix later on. *)
    let Filter f = f in
    let state = Matrix.power f.state in
    let* StrictlyPositive exponent = Nat.of_strictly_positive_int e in
    let* spectral_norm =
      let spectral_matrix = state (Nat.to_int exponent) in
      let spectral_norm = Matrix.norm_inf spectral_matrix in
      if Field.(spectral_norm < one) then Some spectral_norm else None
    in

    (* Source extended with a function computing the cumulated contributions of
       a measure at a given iteration. Those computations are memoized to
       improve performances. *)
    let extended_sources = List.map (extend_source state) f.sources in

    (* Recovering the maximal delay of all sources. *)
    let* StrictlyPositive maximal_delay =
      let delay m = Matrix.dimensions m |> snd |> Nat.to_int in
      let max current (Source s) = Stdlib.(max current (delay s.matrix)) in
      List.fold_left max 0 f.sources |> Nat.of_strictly_positive_int
    in

    (* To compute the invariant center, we need to invert I - Aⁿ with A the
       state matrix and n the spectral exponent. *)
    let order, _ = Matrix.dimensions f.state in
    let+ invert = Matrix.(inverse (id order - state e)) in
    let state t = state (Finite.to_int t) in

    (* Contribution from the filter's center. The infinite series is handled
       as described previously. *)
    let center_from_filter =
      let zero = Matrix.zero order order in
      let add_iteration_state t acc = Matrix.(acc + state t) in
      let iterations = Finite.for_each add_iteration_state exponent zero in
      Matrix.(invert * iterations * f.center)
    in

    (* Contribution from the sources centers. *)
    let center_from_sources =
      let zero = Vector.zero order in
      let add_center_from_source acc (Extended (source, contributions)) =
        let order, delay = Matrix.dimensions source.matrix in
        let zero = Matrix.zero order delay in
        let base = Vector.base Finite.first delay in
        let measures_center = Matrix.(source.measure_center ** base) in
        let limit = contributions (Nat.to_int maximal_delay) in
        let contributions t = contributions (Finite.to_int t) in
        (* Recent contributions are the M last iterations, with M the maximal
           delay. The filter has not yet started to forget those measures. *)
        let add_recent_contrib t acc = Matrix.(acc + contributions t) in
        let recent = Finite.for_each add_recent_contrib maximal_delay zero in
        (* Old contributions come from all the previous iterations, for which
           the filter is forgeting more and more. This implies a limit
           computation, as described previously. *)
        let add_old_contrib t acc = Matrix.(acc + state t * limit) in
        let old = Finite.for_each add_old_contrib exponent zero in
        let old_at_infinity = Matrix.(invert * old) in
        (* The measures center is factorized and taken into account. *)
        Matrix.(acc + (recent + old_at_infinity) * measures_center)
      in List.fold_left add_center_from_source zero extended_sources
    in

    (* Invariant's deviation. *)
    let deviation =
      let zero = Vector.zero order in
      let add_dev_from_source acc (Extended (source, contributions)) =
        let _, delay = Matrix.dimensions source.matrix in
        let limit = contributions (Nat.to_int maximal_delay) in
        let contributions t = contributions (Finite.to_int t) in
        (* For recent and old contributions, we must look after the maximal
           deviation from cumulated measures. This is what this function do,
           based on a given function that returns how the measure at
           iteration [t] contributes. *)
        let base = Vector.base Finite.first delay in
        let deviation = Field.abs source.measure_deviation in
        let lower_measure = Matrix.(Field.neg deviation ** base) in
        let upper_measure = Matrix.(deviation ** base) in
        let add_contribution compute t acc =
          let lower = Matrix.(compute t * lower_measure) in
          let upper = Matrix.(compute t * upper_measure) in
          Matrix.(acc + Vector.(max (abs lower) (abs upper)))
        in
        (* The contributions from the recent measures is simply computed by
           accumulating each contribution multiplied by the measure producing
           the maximal deviation. *)
        let compute_recent_contrib = contributions in
        let add_recent_contrib = add_contribution compute_recent_contrib in
        let recent = Finite.for_each add_recent_contrib maximal_delay zero in
        (* For the old contributions, we use the same factorization as described
           previously. However, this time the common term is not independant
           from the exponent (i.e the index of the infinite sum). However, for
           each index [k], that common term actually behave the same, it is
           just a matter of rewritting. Thus, by computing the maximal deviation
           of this finite common up to rewritting term, we can actually consider
           it as a constant and thus use the same technique as previously
           described. *)
        let compute_old_contrib t = Matrix.(state t * limit) in
        let add_old_contrib = add_contribution compute_old_contrib in
        let old = Finite.for_each add_old_contrib exponent zero in
        (* The old contribution is raised to infinity by dividing it with the
           scalar (1 - ||A^q||), which is the limit of the norm of the infinite
           series. We do not use the same method as before because we observe
           experimentaly that it produces an under approximation. Even if we do
           not have a proof of why it is the case, our intuition is that by
           grouping the infinite sum with our rewritting, we do introduce
           correlations that lead to an underapproximation. Those correlations
           are however ignored through a norm based approach and thus the
           computation is correct. *)
        let scale_to_infinity = Field.(one / (one - spectral_norm)) in
        let old_at_infinity = Matrix.(scale_to_infinity ** old) in
        Matrix.(acc + recent + old_at_infinity)
      in List.fold_left add_dev_from_source zero extended_sources
    in

    let center = Matrix.(center_from_filter + center_from_sources) in
    Matrix.(center - deviation, center + deviation)

end
