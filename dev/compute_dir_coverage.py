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

# usage: compute_dir_coverage.py [-h] [-f] [-r] [-b] filepath
#
# positional arguments:
#   filepath     path to frama-c/_coverage/index.html file
#
# options:
#   -h, --help   show this help message and exit
#   -f, --files  display files coverage
#   -r, --ratio  display ratio (covered lines / total lines)
#   -b, --bar    display % bars

import re, sys, os.path
from bs4 import BeautifulSoup
import argparse

FILE_MARKER = "<files>"
DISPLAY_FILES = False
DISPLAY_RATIO = False
DISPLAY_BAR = False
root = {FILE_MARKER: []}
coverage = {}


# Generate command line arguments and format
def options():
    argparser = argparse.ArgumentParser()
    argparser.add_argument("filepath", help="path to frama-c/_coverage/index.html file")
    argparser.add_argument("-f", "--files", action="store_true", help="display files coverage")
    argparser.add_argument(
        "-r", "--ratio", action="store_true", help="display ratio (covered lines / total lines)"
    )
    argparser.add_argument("-b", "--bar", action="store_true", help="display %% bars")
    args = argparser.parse_args()
    return args


# Open the html file and create the structure to navigate inside
def parse(filename):
    if not os.path.exists(filename):
        print("No such file or directory: " + filename)
        exit()
    with open(filename) as fp:
        return BeautifulSoup(fp, "html.parser")


# From our html structure, extract files informations
# Return a list of nuples (file_path, covered_lines, total_lines)
def extract(html_parser):
    # This div contains all files data
    all_files = html_parser.find(id="files")

    file_list = list()
    for file in all_files.find_all("div"):
        # Access to covered/total lines data
        data = file.contents[3].contents[1].text.split("/", 1)
        covered_lines = int(re.sub(r"[^\d]+", "", data[0]))
        total_lines = int(re.sub(r"[^\d]+", "", data[1]))
        # Access to file path
        path_to_file = file.contents[5].text.strip()
        file_list.append((path_to_file, covered_lines, total_lines))
    return file_list


# Build file directory tree
# Each folder is a dictionnary containing a list of files marked with FILE_MARKER
# Other entries are folder
# We store each files with it's coverage data
def build_tree(path, covered_lines, total_lines, current_dir):
    parts = path.split("/", 1)  # Perform only 1 split
    if len(parts) == 1:  # path contains only a filename
        current_dir[FILE_MARKER].append((parts[0], covered_lines, total_lines))
    else:
        directory, remaining_path = parts
        if directory not in current_dir:
            current_dir[directory] = {FILE_MARKER: []}
        build_tree(remaining_path, covered_lines, total_lines, current_dir[directory])


def concat_path(path, file):
    if path == "":
        return file
    else:
        return path + "/" + file


def dir_coverage(d, path=""):
    acc_coverage, acc_total = 0, 0
    for key, value in d.items():
        if key == FILE_MARKER:  # Files
            # Add files stats to current dir
            for file, covered_lines, total_lines in value:
                acc_coverage = acc_coverage + covered_lines
                acc_total = acc_total + total_lines
        else:  # Directory
            currpath = concat_path(path, key)
            # Compute subdir stats
            covered_lines, total_lines = dir_coverage(value, currpath)
            coverage[currpath] = covered_lines, total_lines
            # Add subdir stats to current dir
            acc_coverage = acc_coverage + covered_lines
            acc_total = acc_total + total_lines
    return acc_coverage, acc_total


def percentage(covered_lines, total_lines):
    if total_lines != 0:
        return covered_lines / total_lines * 100
    else:
        return 0.0


###################
# Print functions #
###################


def str_per(per):
    return "{:>6.2f}".format(per)


def str_bar(per):
    if DISPLAY_BAR:
        nb = round(per / 5)
        return "|" + nb * "#" + (20 - nb) * "-" + "| "
    else:
        return ""


def str_ratio(covered_lines, total_lines):
    if DISPLAY_RATIO:
        return " : (" + str(covered_lines) + " / " + str(total_lines) + ")"
    else:
        return ""


def print_line(name, covered_lines, total_lines, indent):
    per = percentage(covered_lines, total_lines)

    bar = str_bar(per)
    p = str_per(per)
    ratio = str_ratio(covered_lines, total_lines)

    if indent != "":
        indent = indent + " "

    print(bar + p + "% " + indent + name + ratio)


def print_files(files, indent):
    for file, covered_lines, total_lines in files:
        print_line(file, covered_lines, total_lines, "---" + indent)


def print_dir(directory, children, path, indent):
    currpath = concat_path(path, directory)
    covered_lines, total_lines = coverage[currpath]
    print_line(directory, covered_lines, total_lines, indent)
    print_tree(children, "---" + indent, currpath)


# !!! dir_coverage must be called before !!!
def print_tree(d, indent="", path=""):
    for key, value in d.items():
        if key != FILE_MARKER:  # Direcory
            print_dir(key, value, path, indent)
        elif DISPLAY_FILES:  # Files
            print_files(value, indent)


def main():
    args = options()

    # Set options booleans
    global DISPLAY_FILES
    DISPLAY_FILES = args.files
    global DISPLAY_RATIO
    DISPLAY_RATIO = args.ratio
    global DISPLAY_BAR
    DISPLAY_BAR = args.bar

    html_parser = parse(args.filepath)
    files = extract(html_parser)

    for path_to_file, cov, tot in files:
        build_tree(path_to_file, cov, tot, root)

    dir_coverage(root)
    print_tree(root)


if __name__ == "__main__":
    main()
