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
import ReactMarkdown, { Components, Options } from 'react-markdown';

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

class Counter {
  private val: number = 0;
  increment(): number { return this.val++; }
}

// --------------------------------------------------------------------------
// --- Replacement function
// --------------------------------------------------------------------------
/**
 * Replace all tag in the text.
 * This function doesn't replace any tags added by a previous replacement.
 */
function replaceTagsByElement(
  text: string,
  counter: Counter,
  patterns?: Pattern[],
): (string | JSX.Element | null)[] {
  if(!patterns || patterns.length < 1) return [text];

  const { pattern, replace } = patterns[0];
  patterns.shift();

  const newContent = [];
  let match;
  let lastIndex = 0;

  while ((match = pattern.exec(text)) !== null) {
    if (match.index > lastIndex) {
      const before = replaceTagsByElement(
        text.slice(lastIndex, match.index), counter, patterns
      );
      before.forEach((elt) => newContent.push(elt));
    }
    newContent.push(replace(counter.increment(), match));
    lastIndex = pattern.lastIndex;
  }
  if (lastIndex < text.length) {
    const after = replaceTagsByElement(
      text.slice(lastIndex), counter, patterns);
    after.forEach((elt) => newContent.push(elt));
  }
  return newContent;
}

function replaceTags(
  children: React.ReactNode,
  patterns: Pattern[],
  counter: Counter
): React.ReactNode {
  const childrenTab = React.Children.toArray(children);

  const newContent = childrenTab.map((child) => {
    if (typeof child === 'string') {
      return replaceTagsByElement(child, counter, patterns.slice());
    }
    return child;
  });

  return newContent;
}

// --------------------------------------------------------------------------
// --- Markdown component
// --------------------------------------------------------------------------
type tagHtmlList = [ k: keyof Components, v: keyof Components ][]

interface MarkdownProps {
  /** classes for Markdown component */
  className?: string;
  /** html tag of the markdown to be processed and possible replacement */
  htmlTag?: tagHtmlList;
  /** Tab of tag replacement */
  pattern?: Pattern[];
  /** Children */
  children?: string | null;
}

export function Markdown(
  props: MarkdownProps
): JSX.Element {
  const { className, pattern, htmlTag, children } = props;
  const markdownClasses = classes(
    "dome-xMarkdown", "dome-pages",
    className,
  );

  const counter = new Counter();
  const transformChildren = (c: React.ReactNode): React.ReactNode => {
    return !pattern ? c : replaceTags(c, pattern, counter);
  };

  const getComponentsOption = (): Components | null => {
    if(!htmlTag) return null;

    const getDynamicElement = (
      tagName: keyof JSX.IntrinsicElements,
      children: React.ReactNode
    ): JSX.Element => {
      const Tag = tagName;
      return <Tag>{children}</Tag>;
    };

    const component = [];
    for (const [key, val] of htmlTag) {
      component.push([key, ({ children }: {
        children: React.ReactNode;
      }) => getDynamicElement(val, transformChildren(children))]);
    }

    return Object.fromEntries(component);
  };

  const options: Options = {
    className: markdownClasses,
    components: getComponentsOption()
  };

  return <ReactMarkdown {...options}>{ children }</ReactMarkdown>;
}

/* -------------------------------------------------------------------------- */
