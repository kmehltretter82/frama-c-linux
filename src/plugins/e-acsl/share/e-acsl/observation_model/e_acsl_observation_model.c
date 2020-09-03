/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2020                                               */
/*    CEA (Commissariat à l'énergie atomique et aux énergies              */
/*         alternatives)                                                  */
/*                                                                        */
/*  you can redistribute it and/or modify it under the terms of the GNU   */
/*  Lesser General Public License as published by the Free Software       */
/*  Foundation, version 2.1.                                              */
/*                                                                        */
/*  It is distributed in the hope that it will be useful,                 */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*  GNU Lesser General Public License for more details.                   */
/*                                                                        */
/*  See the GNU Lesser General Public License version 2.1                 */
/*  for more details (enclosed in the file licenses/LGPLv2.1).            */
/*                                                                        */
/**************************************************************************/

#include "internals/e_acsl_heap_tracking.c"
#include "internals/e_acsl_safe_locations.c"

/* Select memory model, either segment-based or bittree-based model should
   be defined */
#if defined E_ACSL_SEGMENT_MMODEL
# include "segment_model/e_acsl_segment_observation_model.c"
# include "segment_model/e_acsl_segment_tracking.c"
# include "segment_model/e_acsl_shadow_layout.c"
# include "segment_model/e_acsl_segment_omodel_debug.c"
# include "segment_model/e_acsl_segment_timestamp_retrieval.c"
#elif defined E_ACSL_BITTREE_MMODEL
# include "bittree_model/e_acsl_bittree_observation_model.c"
# include "bittree_model/e_acsl_bittree.c"
# include "bittree_model/e_acsl_bittree_omodel_debug.c"
# include "bittree_model/e_acsl_bittree_timestamp_retrieval.c"
#else
# error "No E-ACSL memory model defined. Aborting compilation"
#endif
