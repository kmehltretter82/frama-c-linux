#!/usr/bin/env python3
#-*- coding: utf-8 -*-
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2020                                               #
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

# This script finds files containing likely declarations and definitions
# for a given function name, via heuristic syntactic matching.

import sys
import os
import re
import function_finder

MIN_PYTHON = (3, 5)
if sys.version_info < MIN_PYTHON:
    sys.exit("Python %s.%s or later is required.\n" % MIN_PYTHON)

arg = ""
if len(sys.argv) < 2:
    print(f"usage: {sys.argv[0]} file...")
    print("        builds a heuristic callgraph for the specified files.")
    sys.exit(1)
else:
    files = sys.argv[1:]

class Callgraph:
    """
    Heuristics-based callgraphs.
    Nodes are function names. Edges (caller, callee, locations) contain the source
    and target nodes, plus a list of locations (file, line) where calls from
    [caller] to [callee] occur.
    """

    # maps each caller to the list of its callees
    succs = {}

    # maps (caller, callee) to the list of call locations
    edges = {}

    def add_edge(self, caller, callee, loc):
        if (caller, callee) in self.edges:
            # edge already exists
            self.edges[(caller, callee)].append(loc)
        else:
            # new edge: check if caller exists
            if not caller in self.succs:
                self.succs[caller] = []
            # add callee as successor of caller
            self.succs[caller].append(callee)
            # add call location to edge information
            self.edges[(caller, callee)] = [loc]

    def nodes(self):
        return self.succs.keys()

    def __repr__(self):
        return f"Callgraph({self.succs}, {self.edges})"

def compute(files):
    #print(f"Computing callgraph for {len(files)} file(s)...")
    cg = Callgraph()
    for f in files:
        #print(f"Processing {os.path.relpath(f)}...")
        newlines = function_finder.compute_newline_offsets(f)
        defs = function_finder.find_definitions_and_declarations(True, False, f, newlines)
        calls = function_finder.find_calls(f, newlines)
        for call in calls:
            caller = function_finder.find_caller(defs, call)
            if caller:
                called = call[0]
                line = call[1]
                loc = (f, line)
                cg.add_edge(caller, called, loc)
    #print(f"Callgraph computed ({len(cg.succs)} node(s), {len(cg.edges)} edge(s))")
    return cg

def print_edge(cg, caller, called, padding="", end="\n"):
    locs = cg.edges[(caller, called)]
    for (filename, line) in locs:
        print(f"{padding}{os.path.relpath(filename)}:{line}: {caller} -> {called}", end=end)

def print_cg(cg):
    for (caller, called) in cg.edges:
        print_edge(cg, caller, called)

# succs: dict, input, not modified
# visited: set, input-output, modified
# just_visited: set, input-output, modified
# n: input, not modified
#
# The difference between visited and just_visited is that the latter refers
# to the current dfs; nodes visited in previous dfs already had their cycles
# reported, so we do not report them multiple times.
def cycle_dfs(cg, visited, just_visited, n):
    just_visited.add(n)
    if n not in cg.succs:
        return []
    for succ in cg.succs[n]:
        if succ in just_visited:
            return [(n, succ)]
        elif succ in visited:
            # already reported in a previous iteration
            return []
        else:
            res = cycle_dfs(cg, visited, just_visited, succ)
            if res:
                caller = res[0][0]
                return [(n, caller)] + res
            else:
                return []
    return []

def detect_recursion(cg):
    #print(f"Detecting recursive calls...")
    to_visit = set(cg.nodes())
    #if len(to_visit) > 100:
    #    print(f"Checking recursion ({len(to_visit)} nodes)...")
    if not to_visit: # empty graph -> no recursion
        return False
    visited = set()
    has_cycle = False
    while to_visit:
        just_visited = set()
        n = sorted(list(to_visit))[0]
        cycle = cycle_dfs(cg, visited, just_visited, n)
        visited = visited.union(just_visited)
        if cycle:
            has_cycle = True
            print(f"recursive cycle detected: ")
            for (caller, called) in cycle:
                print_edge(cg, caller, called, padding="  ")
        to_visit -= visited
    if not has_cycle:
        print(f"no recursive calls detected")
