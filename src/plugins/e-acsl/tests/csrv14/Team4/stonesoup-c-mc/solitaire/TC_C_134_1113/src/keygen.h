

/********************************************************************
 ** This software (or technical data) was produced for the U. S.
 ** Government under contract 2009-0917826-016 and is subject to 
 ** the Rights in Data-General Clause 52.227-14. Alt. IV (DEC 2007).
 ** 
 ** (c) Copyright 2012 The MITRE Corporation. All Rights Reserved.
 ********************************************************************/

/*
 * keygen.h
 *
 *  Created on: Oct 6, 2011
 *      
 */
#ifdef _WIN32
#include <windows.h>
#ifndef KEYGEN_H_
#define KEYGEN_H_
int getInt(int a);
char* decry(int argc, _TCHAR* argv[]);
int encry(int argc, _TCHAR* argv[]);

#endif /* KEYGEN_H_ */

#else
#ifndef KEYGEN_H_
#define KEYGEN_H_
int getInt(int a);
char* decry(int argc, char* argv[]);
char* encry(int argc, char* argv[]);

#endif /* KEYGEN_H_ */
#endif
