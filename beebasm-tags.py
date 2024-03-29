#!/usr/bin/env python

import argparse
import collections
import os
import sys


def die(error):
    sys.stderr.write(os.path.basename(sys.argv[0]) + ': ' + error + '\n')
    sys.exit(1)


def tokenise(line):
    i = 0
    tokens = []
    statement = []
    while i < len(line):
        while i < len(line) and line[i].isspace():
            i += 1
        if i >= len(line):
            break
        if line[i] == '"':
            j = line.find('"', i+1)
            if j == -1:
                j = len(line) 
            else:
                j += 1
            statement.append(line[i:j])
            i = j
        else:
            special = '#:,.^*'
            if line[i] in special:
                j = i + 1
            else:
                j = i
                while j < len(line) and not line[j].isspace() and not line[j] in special:
                    j += 1
            token = line[i:j]
            if token in ('\\', ';'):
                break
            if token == ':':
                tokens.append(statement)
                statement = []
            else:
                statement.append(token)
            i = j
    if statement:
        tokens.append(statement)
    return tokens


# TODO: This is very simplistic.
def search_escape(s):
    # Note that we do *not* want to escape '.' and '*', it seems that in tags
    # these are normal characters by default and escaping them turns them
    # *into* regular expression characters.
    t = ''
    for c in s:
        if c in '\\/':
            t += '\\' + c
        else:
            t += c
    return t


def label(filename, line_number, line, statement):
    assert statement[0] == '.'
    for i, token in enumerate(statement):
        if i == 0:
            continue
        if token not in ('^', '*'):
            add_tag(filename, line_number, token, '^' + search_escape(line) + '$')
            return


def assignment(filename, line_number, line, statement):
    assert statement[1] == '='
    add_tag(filename, line_number, statement[0], '^' + search_escape(line) + '$')


def macro(filename, line_number, line, statement):
    assert statement[0].lower() == 'macro'
    if len(statement) < 2:
        return
    add_tag(filename, line_number, statement[1], '^' + search_escape(line) + '$')


def add_tag(filename, line_number, tag, address, tag_field = None):
    if tag is None:
        return
    tags.append((filename, line_number, tag, address, tag_field))


def vim_tag(tag):
    filename, line_number, tag, address, tag_field = tag

    if address is None:
        address = str(line_number)
    else:
        address = '/' + address + '/'

    if (tag, filename, address) in tags_generated:
        address = str(line_number)
    else:
        tags_generated.add((tag, filename, address))

    if tag_field is not None:
        address += ';"\t' + tag_field
    return tag + '\t' + filename + '\t' + address


def emacs_tag(line_number, tag, address, tag_field):
    if tag_field == 'F':
        return ('', '')
    assert address is not None
    assert address[0] == '^'
    assert address[-1] == '$'
    tag_definition = address[1:-1]
    i = tag_definition.find(tag)
    assert i != -1
    tag_definition = tag_definition[0:i+len(tag)+1] # +1 to try to avoid problems where one tag is an initial substring of another
    return (tag, '%s\x7f%s\x01%d,%d\n' % (tag_definition, tag, line_number, i))


def process_file(filename):
    try:
        with open(filename) as f:
            for (line_number, line) in enumerate(f):
                line_number += 1 # switch from 0 to 1 based
                if line[-1] == '\n':
                    line = line[0:-1]
                if len(line) > 0 and line[-1] == '\r':
                    line = line[0:-1]
                tokens = tokenise(line)
                for statement in tokens:
                    if statement[0] == '.':
                        label(filename, line_number, line, statement)
                    elif statement[0].lower() == 'macro':
                        macro(filename, line_number, line, statement)
                    elif len(statement) > 1 and statement[1] == '=':
                        assignment(filename, line_number, line, statement)
    except IOError as e:
        die('Cannot open source file "' + filename + '": ' + os.strerror(e.errno))


parser = argparse.ArgumentParser(description='Generate tags file from BeebAsm source files')
parser.add_argument('-f', metavar='tags_file', default=None, help='Write tags to specified file (default "tags", or "TAGS" if -e is used)')
parser.add_argument('-e', action='store_true', help='Output tag file for use with Emacs')
parser.add_argument('input_files', metavar='source_file', nargs='+', help='BeebAsm source file to scan')
args = parser.parse_args()
if args.f is None:
    args.f = "tags" if not args.e else "TAGS"

tags = []
tags_generated = set()
for input_file in args.input_files:
    add_tag(input_file, 1, input_file, None, "F")
    process_file(input_file)

if args.f == '-':
    tag_file = sys.stdout
else:
    ok = '!_TAG_FILE_FORMAT\t' if not args.e else '\x0c'
    # Following the lead of exuberant ctags, we refuse to proceed if the the output
    # file exists and is not a valid tags file; this avoids catastrophe if invoked
    # as 'beebasm-tags -f *.beebasm', which would otherwise overwrite the first
    # source file.
    try:
        with open(args.f, 'r' if not args.e else 'rb') as f:
            line = f.readline()
            if line[0:len(ok)] != ok:
                die('Refusing to overwrite non-tag file "' + args.f + '"')
    except IOError:
        pass
    tag_file = open(args.f, 'w' if not args.e else 'wb')

if not args.e:
    tag_file.write('!_TAG_FILE_FORMAT\t2\n')
    tag_file.write('!_TAG_FILE_SORTED\t1\n')
    tag_file.write('!_TAG_PROGRAM_NAME\tbeebasm-tags\n')
    for line in sorted(vim_tag(tag) for tag in tags):
        tag_file.write(line + '\n')
else:
    file_key_tags = collections.defaultdict(list)
    for filename, line_number, tag, address, tag_field in tags:
        file_key_tags[filename].append(emacs_tag(line_number, tag, address, tag_field))
    file_tags = {}
    # Sorting probably doesn't matter for emacs tags, but I'll leave it in now I've implemented it.
    for filename, key_tag_list in file_key_tags.items():
        file_tags[filename] = ''.join(x[1] for x in sorted(key_tag_list))
    for filename, tags in file_tags.items():
        tag_file.write('\x0c\n%s,%d\n%s' % (filename, len(tags), tags))

tag_file.close()
