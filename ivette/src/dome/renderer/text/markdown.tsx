/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';
import ReactMarkdown, { Options } from 'react-markdown';

import { classes } from 'dome/misc/utils';
import { Icon } from 'dome/controls/icons';

export interface Pattern {
  pattern: RegExp,
  replace: (key: number, match?: RegExpExecArray) => JSX.Element | null
}

export const iconTag: Pattern = {
  pattern: /\[icon-([^\]]+)\]/g,
  replace: (key: number, match?: RegExpExecArray) => {
    return match ? <Icon key={key} id={match[1]}/> : null;
  }
};

// --------------------------------------------------------------------------
// --- Replacement function
// --------------------------------------------------------------------------

/**
 * Replace all tag in children.
 * This function doesn't replace any tags added by a previous replacement.
 */
function replaceTags(
  children: React.ReactNode,
  patterns: Pattern[],
): React.ReactNode {
  if(patterns.length < 1) return children;

  const buffer: React.ReactNode[] = [];
  let counter = 0;
  const childrenTab = React.Children.toArray(children);

  const makeReplace = (text: string, index: number): void => {
    if(index >= patterns.length) {
      buffer.push(text);
      return;
    }
    const { pattern, replace } = patterns[index];

    let match;
    let lastIndex = 0;
    while ((match = pattern.exec(text)) !== null) {
      if (match.index > lastIndex) {
        makeReplace(text.slice(lastIndex, match.index), index+1);
      }
      buffer.push(replace(counter++, match));
      lastIndex = pattern.lastIndex;
    }
    if (lastIndex < text.length) {
      makeReplace(text.slice(lastIndex), index+1);
    }
  };

  /** makeReplace is applied if child is a string,
   * otherwise it is pushed into the buffer
   */
  childrenTab.forEach((child) => {
    if (typeof child === 'string') {
      return makeReplace(child, 0);
    }
    return buffer.push(child);
  });

  return buffer;
}

// --------------------------------------------------------------------------
// --- Markdown component
// --------------------------------------------------------------------------

interface MarkdownProps {
  /** classes for Markdown component */
  className?: string;
  /** Tab of patterns */
  patterns?: Pattern[];
  /** Children */
  children?: string | null;
}

export function Markdown(
  props: MarkdownProps
): JSX.Element {
  const { className, patterns, children } = props;
  const markdownClasses = classes(
    "dome-xMarkdown", "dome-pages", className
  );

  const options: Options = { className: markdownClasses };
  if(patterns && patterns.length > 0) options.components = {
    p: ({ children }) => <div>{replaceTags(children, patterns)}</div>,
    li: ({ children }) => <li>{replaceTags(children, patterns)}</li>
  };

  return <ReactMarkdown {...options}>{ children }</ReactMarkdown>;
}

/* -------------------------------------------------------------------------- */
