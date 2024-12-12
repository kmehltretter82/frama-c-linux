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

import * as Themes from 'dome/themes';
import { classes } from 'dome/misc/utils';
import { Icon } from 'dome/controls/icons';
import {
  CodeBlock, atomOneDark, atomOneLight
} from "react-code-blocks";
export interface Pattern {
  pattern: RegExp,
  replace: (key: number, match?: RegExpExecArray) => JSX.Element | null
}

export const iconTag: Pattern = {
  pattern: /(\[ex:\])?\[icon-([^\]]+)\]/g,
  replace: (key: number, match?: RegExpExecArray) => {
    if(match && match[1] === "[ex:]") {
      return <span key={key}>{`[icon-${match[2]}]`}</span>;
    }
    return match ? <Icon key={key} id={match[2]}/> : null;
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
  /** Anchors ref */
  anchorsRef: React.MutableRefObject<
    {[key: string] : HTMLHeadingElement | null}>;
  /** Children */
  children?: string | null;
}

export function Markdown(
  props: MarkdownProps
): JSX.Element {
  const { className, patterns, anchorsRef, children } = props;
  const theme = Themes.useColorTheme()[0];
  const markdownClasses = classes(
    "dome-xMarkdown", "dome-pages", className
  );

  /**
   * If children is a string this function return the
   * heading element with an id and save ref in anchorsRef
   */
  const getHtmlTitle = (
    children: React.ReactNode,
    tag: "h1" | "h2" = 'h1'
  ): JSX.Element => {
    const Tag = tag;
    const id = typeof children === "string" ?
      children.toLowerCase().replaceAll(' ', '-') : undefined;

    return id ?
      <Tag id={id} ref={(el) => anchorsRef.current[id] = el}>{children}</Tag>:
      <Tag>{children}</Tag>;
  };

  const options: Options = { className: markdownClasses };
  if(patterns && patterns.length > 0) options.components = {
    p: ({ children }) => <div>{replaceTags(children, patterns)}</div>,
    li: ({ children }) => <li>{replaceTags(children, patterns)}</li>,
    h1: ({ children }) => getHtmlTitle(children),
    h2: ({ children }) => getHtmlTitle(children, 'h2'),
    /** Uses codeBlock if ```` is used in markdown with a language,
     *  otherwise the code-inline class is added */
    code: ({ className, children }) => {
      if (className && className.includes("language-")
        && typeof children === "string"
      ) {
        const language = className.split("language-")[1];
        return <CodeBlock
          text={children}
          language={language}
          showLineNumbers={false}
          theme={theme === 'dark' ? atomOneDark : atomOneLight}
        />;
      }
      return <code className='code-inline'>{children}</code>;
    },
  };

  return <ReactMarkdown {...options}>{ children }</ReactMarkdown>;
}

/* -------------------------------------------------------------------------- */
