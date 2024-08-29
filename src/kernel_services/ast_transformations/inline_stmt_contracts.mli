(** transforms requires and ensures of statement contracts into assert.
    This transformation is done after cleanup
*)

val emitter : Emitter.t
val category : File.code_transformation_category
