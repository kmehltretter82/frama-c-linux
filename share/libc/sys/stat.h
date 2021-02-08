/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2021                                               */
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

#ifndef __FC_SYS_STAT_H
#define __FC_SYS_STAT_H
#include "features.h"
__PUSH_FC_STDLIB
__BEGIN_DECLS

#include "../__fc_define_stat.h"
#include "../__fc_string_axiomatic.h"

extern int    chmod(const char *, mode_t);
extern int    fchmod(int, mode_t);
extern int    fstat(int, struct stat *);

/*@ // missing: may assign to errno: EACCES, ELOOP, ENAMETOOLONG,
    //                               ENOENT, ENOMEM, ENOTDIR, EOVERFLOW,
    //                               EINVAL
    // missing: assigns \result, *buf \from 'filesystem'
  requires valid_path: valid_read_string(path);
  requires valid_buf: \valid(buf);
  assigns \result, *buf \from indirect:path, indirect:path[0..strlen(path)];
  ensures result_ok_or_error: \result == 0 || \result == -1;
*/
extern int    lstat(const char *path, struct stat *buf);

/*@ // missing: may assign to errno: EACCES, EEXIST, ELOOP, EMLINK,
    //                               ENAMETOOLONG, ENOENT, ENOSPC,
    //                               ENOTDIR, EROFS
    // missing: assigns \result \from 'filesystem'
  requires valid_path: valid_read_string(path);
  assigns \result \from indirect:path, indirect:path[0..strlen(path)],
                        indirect:mode;
  ensures result_ok_or_error: \result == 0 || \result == -1;
*/
extern int    mkdir(const char *path, mode_t mode);

/*@ // missing: may assign to errno: EACCES, EEXIST, ELOOP, ENAMETOOLONG,
    //                               ENOENT, ENOTDIR, ENOSPC, EROFS
    // missing: assigns \result \from 'filesystem'
    // missing: assigns 'filesystem' \from indirect:path,
    //                                     indirect:path[0..strlen(path)], mode;
  requires valid_path: valid_read_string(path);
  assigns \result \from indirect:path, indirect:path[0..strlen(path)],
                        indirect:mode;
  ensures result_ok_or_error: \result == 0 || \result == -1;
*/
extern int    mkfifo(const char *path, mode_t mode);

/*@ // missing: may assign to errno: EACCES, EEXIST, EINVAL, EIO, ELOOP,
    //                               ENAMETOOLONG, ENOENT, ENOTDIR, ENOSPC,
    //                               EPERM, EROFS
    // missing: assigns \result \from 'filesystem'
    // missing: assigns 'filesystem' \from indirect:path,
    //          indirect:path[0..strlen(path)], mode, dev;
  requires valid_path: valid_read_string(path);
  assigns \result \from indirect:path, indirect:path[0..strlen(path)],
                        indirect:mode, indirect:dev;
  ensures result_ok_or_error: \result == 0 || \result == -1;
*/
extern int    mknod(const char *path, mode_t mode, dev_t dev);

/*@ //missing: assigns \from 'filesystem'
  requires valid_pathname: valid_read_string(pathname);
  requires valid_buf: \valid(buf);
  assigns \result, *buf \from pathname[0..strlen(pathname)];
  ensures result_ok_or_error: \result == 0 || \result == -1;
  ensures init_on_success:initialization:buf:
    \result == 0 ==> \initialized(buf);
*/
extern int    stat(const char *pathname, struct stat *buf);

/*@ //missing: assigns 'process umask' \from cmask;
    //missing: assigns \result \from 'old process umask'
  assigns \result \from indirect:cmask;
*/
extern mode_t umask(mode_t cmask);

__END_DECLS
__POP_FC_STDLIB
#endif
