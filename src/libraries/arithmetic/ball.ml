(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)


module Make (K : Field.S) = struct

  open Linear.Space (K)
  type 'n t = { center : 'n vector ; radius : 'n vector }

  let make center radius = { center ; radius = Matrix.abs radius }
  let zero n = make (Vector.zero n) (Vector.zero n)
  let constant v = make v Vector.(size v |> zero)
  let ( + ) l r = make Matrix.(l.center + r.center) Matrix.(l.radius + r.radius)

  let is_included l r =
    let ( < ) = Matrix.all_components_lower_than in
    let lower { center ; radius } = Matrix.(center - radius) in
    let upper { center ; radius } = Matrix.(center + radius) in
    lower r < lower l && upper l < upper r

  let pretty fmt ball =
    let n = Vector.size ball.center in
    let pretty i () =
      let c = Vector.get i ball.center in
      let r = Vector.get i ball.radius in
      if Finite.(i != first) then Format.fprintf fmt " ; " ;
      Format.fprintf fmt "%a ± %a" K.pretty c K.pretty r ;
    in
    Format.fprintf fmt "@[[" ;
    Finite.for_each pretty n () ;
    Format.fprintf fmt "]@]"

end

