

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


#ifndef __REGFUNCS_H__
#define __REGFUNCS_H__ 1

#define HKEY_CURRENT_USER "HKEY_CURRENT_USER"

#define KEY_READ 1

#define ERROR_SUCCESS 1
#define ERROR_FAIL 0

#define MAX_KEY_SZ 2000
typedef char *HKEY;
typedef char *LPBYTE;

int RegOpenKeyEx(char const *hv, char const *key, int dummy1, int valtyp, HKEY *k);
int RegQueryValueEx(HKEY key, char const *name, int dummy1, char *s, char *buf, unsigned long *bufsz);
void RegCloseKey(HKEY);

#endif

/* End of file */
