
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

/************************************************************************
**
** regfuncs.c
**
**  Created on: Sept 29, 2011
**      
**
**      MUST COMPILE WITH LINKER FLAGS -L/usr/X11R6/lib -lX11
**
**	Description:
**		These functions emulate the registry in the form of a configuration file
**		on Linux. The "Registry" Hive name, Key name, and Value name are stored in
**		the configuration file as one long string. The data value is '=' separated
**		from the name string. The name of the configuration file is
**		"registry.conf" and is expected to live in the testData directory.
**
************************************************************************/

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <malloc.h>

#include "regfuncs.h"

int RegOpenKeyEx(char const *hv, char const *key, int dummy1, int valtyp, HKEY *k)
{
	int ksz = strlen(hv) + strlen(key) + 2;

	if ((*k = malloc(MAX_KEY_SZ)) == NULL)
	{
		return (ERROR_FAIL);
	}

	if (ksz < MAX_KEY_SZ)
	{
		strcpy(*k, hv);
		strcat(*k, "\\");
		strcat(*k, key);
		return (ERROR_SUCCESS);
	}

	free(*k);
	*k = NULL;

	return (ERROR_FAIL);
}


int RegQueryValueEx(HKEY key, char const *name, int dummy1, char *s, char *buf, unsigned long *bufsz)
{
	int ksz = strlen(key);
	int nsz = strlen(name);
	char k[ksz + nsz + 2];
	strcpy(k, key);
	k[ksz] = '\\';
	strcpy(k + ksz + 1, name);
	ksz = strlen(k);

	char ln[MAX_KEY_SZ * 2];
	FILE *fp;

	if ((fp = fopen("registry.conf", "r")) == NULL)
	{
		return (ERROR_FAIL);
	}

	while (!feof(fp))
	{
		if (fgets(ln, sizeof(ln), fp) == NULL)
		{
			fclose(fp);
			return (ERROR_FAIL);
		}

		char *s = strstr(ln, k);
		if (s && ((ln[ksz] == '=') || (ln[ksz] == ' ') || (ln[ksz] == '\t')))
		{
			fclose(fp);

			int i = ksz;
			while ((i < sizeof(ln)) && (ln[i] != '\0') &&
				((ln[i] == '=') || (ln[i] == ' ') || (ln[i] == '\t'))) { i++; }
			int bsz = strlen(ln + i);
			if (bsz >= (*bufsz - 1))
			{
				return (ERROR_FAIL);
			}

			strcpy((char *)buf, ln + i);
			while ((buf[--bsz] == '\n') || (buf[bsz] == '\r'))
			{
				buf[bsz] = '\0';
			}

			return (ERROR_SUCCESS);
		}
	}

	fclose(fp);
	return (ERROR_FAIL);
}

void RegCloseKey(HKEY key)
{
	if (key)
	{
		free(key);
	}
}

/* End of file */
