##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2023                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  you can redistribute it and/or modify it under the terms of the GNU   #
#  Lesser General Public License as published by the Free Software       #
#  Foundation, version 2.1.                                              #
#                                                                        #
#  It is distributed in the hope that it will be useful,                 #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#  GNU Lesser General Public License for more details.                   #
#                                                                        #
#  See the GNU Lesser General Public License version 2.1                 #
#  for more details (enclosed in the file licenses/LGPLv2.1).            #
#                                                                        #
##########################################################################

import re

stat_file_re = re.compile("^([^=]*)=(.*)$", re.MULTILINE)


def load(filename):
    data = {}
    try:
        with open(filename, "r") as file:
            content = file.read()
            for key, value in stat_file_re.findall(content):
                data[key] = value
    except OSError:
        pass
    return data


re_escape_space = re.compile(r"\\ ")


def convert(data, key, to_type, default=None):
    try:
        value = data[key].strip()
        if to_type is str:
            value = re.sub(r"\\ ", " ", value)
            value = re.sub(r"\\,", ",", value)
            return value
        else:
            return to_type(value)
    except (ValueError, TypeError, KeyError):
        return default


def parse(data):
    result = {}
    result["timestamp"] = convert(data, "timestamp", str)
    result["sem_reach_fun"] = convert(data, "sem_reach_fun", int)
    result["syn_reach_fun"] = convert(data, "syn_reach_fun", int)
    result["total_fun"] = convert(data, "total_fun", int)
    result["sem_reach_stmt"] = convert(data, "sem_reach_stmt", int)
    result["syn_reach_stmt"] = convert(data, "syn_reach_stmt", int)
    result["alarms"] = convert(data, "alarms", int)
    result["warnings"] = convert(data, "warnings", int)
    result["user_time"] = convert(data, "user_time", float)
    result["memory"] = convert(data, "memory", int)
    result["cmd_args"] = convert(data, "cmd_args", str)
    result["benchmark_tag"] = convert(data, "benchmark_tag", str)
    if result["sem_reach_stmt"] is not None and result["syn_reach_stmt"] is not None:
        try:
            result["coverage"] = result["sem_reach_stmt"] / result["syn_reach_stmt"]
        except ZeroDivisionError:
            result["coverage"] = None
    else:
        result["coverage"] = None        
    result["sum_saved_fun"] = convert(data, "sum_saved_fun", int)
    result["sum_reloaded_fun"] = convert(data, "sum_reloaded_fun", int)
    result["eva_time"] = convert(data, "eva_time", float)
    result["sum_hits"] = convert(data, "sum_hits", int)
    result["sum_misses"] = convert(data, "sum_misses", int)
    result["inv_reused"] = convert(data, "inv_reused", int)
    result["inv_saved"] = convert(data, "inv_saved", int)
    result["total_iterations"] = convert(data, "total_iterations", int)
    result["cache_load"] = convert(data, "cache_load", int)
    result["ast_diff"] = convert(data, "ast_diff", int)
    result["filesize_mb"] = convert(data, "filesize_mb", float)
    return result


def read(filename):
    return parse(load(filename))
