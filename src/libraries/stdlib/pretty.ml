(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type 'a aformatter = Format.formatter -> 'a -> unit
type tformatter = Format.formatter -> unit
type nonrec 'a format = ('a,Format.formatter,unit) format

(* These functions are similar to Pretty_utils.pp_iter, but must be redefined
   here to avoid cyclic dependencies as Pretty_utils depends on Array and List.
   They also allow for a slightly more generic formats. *)

let pretty_iter ~format ~item ~sep ~iter pp_item fmt collection =
  let need_sep = ref false in
  let pp_elements fmt =
    iter (fun elt ->
        if !need_sep then Format.fprintf fmt sep else need_sep := true;
        Format.fprintf fmt item pp_item elt;
      ) collection;
  in
  Format.fprintf fmt format pp_elements

let pretty_iter2 ~format ~item ~sep ~iter pp_key pp_val fmt collection =
  let iter f = iter (fun k v -> f (k,v))
  and pp fmt (k,v) = Format.fprintf fmt item pp_key k pp_val v in
  pretty_iter ~format ~sep ~item:"%a" ~iter pp fmt collection

let pretty_seq ~format ~item ~sep ?(last=sep) ?empty pp_item fmt seq =
  match Seq.uncons seq with
  | Some (first, remaining) ->
    let pretty_nonempty fmt =
      Format.fprintf fmt item pp_item first;
      match Seq.uncons remaining with
      | None -> () (* Only one element, already printed *)
      | Some (second, remaining) ->
        let pp previous current =
          Format.fprintf fmt sep;
          Format.fprintf fmt item pp_item previous;
          current
        in
        let last_elt = Seq.fold_left pp second remaining in
        Format.fprintf fmt last;
        Format.fprintf fmt item pp_item last_elt
    in
    Format.fprintf fmt format pretty_nonempty
  | None ->
    (* Empty sequence *)
    match empty with
    | None -> Format.fprintf fmt format ignore
    | Some empty -> Format.fprintf fmt empty
