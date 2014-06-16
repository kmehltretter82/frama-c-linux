
static char data_rights_legend [ ] = 
  "This software (or technical data) was produced for the U. S. \
   Government under contract 2009-0917826-016 and is subject to \
   the Rights in Data-General Clause 52.227-14. Alt. IV (DEC 2007). \
\
   (c) Copyright 2012 The MITRE Corporation. All Rights Reserved.";




/********************************************************************
 ** This software (or technical data) was produced for the U. S.
 ** Government under contract 2009-0917826-016 and is subject to 
 ** the Rights in Data-General Clause 52.227-14. Alt. IV (DEC 2007).
 ** 
 ** (c) Copyright 2012 The MITRE Corporation. All Rights Reserved.
 ********************************************************************/


#include <string.h>

#include "interfile.h"

void do_weakness(char *k, char** argv)
{
	strcpy(k, argv[1]);  // STONESOUP:INTERACTION_POINT  // STONESOUP:CROSSOVER_POINT  // STONESOUP:TRIGGER_POINT  // STONESOUP:SOURCE_TAINT:COMMAND_LINE
}
