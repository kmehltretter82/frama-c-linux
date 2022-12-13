/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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

// --------------------------------------------------------------------------
// --- Frama-C Utilities
// --------------------------------------------------------------------------

/**
 * @packageDocumentation
 * @module frama-c/richtext
 */

import React from 'react';
import * as Dome from 'dome';
import * as DomeBuffers from 'dome/text/buffers';
import * as KernelData from 'frama-c/kernel/api/data';
import { classes } from 'dome/misc/utils';

const D = new Dome.Debug('Utils');

// --------------------------------------------------------------------------
// --- Print Utilities
// --------------------------------------------------------------------------

/**
 * Print text containing tags into buffer.
 * @param buffer Rich text buffer to print into.
 * @param text Actual text containing tags.
 * @param options Specify particular marker options.
 */
export function printTextWithTags(
  buffer: DomeBuffers.RichTextBuffer,
  text: KernelData.text,
  options?: DomeBuffers.MarkerProps,
): void {
  if (Array.isArray(text)) {
    const tag = text[0];
    const marker = typeof (tag) === 'string';
    if (marker) {
      buffer.openTextMarker({ id: tag, ...options ?? {} });
    }
    for (let k = marker ? 1 : 0; k < text.length; k++) {
      printTextWithTags(buffer, text[k], options);
    }
    if (marker) {
      buffer.closeTextMarker();
    }
  } else if (typeof text === 'string') {
    buffer.append(text);
  } else {
    D.error('Unexpected text', text);
  }
}

// --------------------------------------------------------------------------
// --- Lightweight Text Renderer
// --------------------------------------------------------------------------

export type Modifier = 'NORMAL' | 'DOUBLE' | 'META';

export interface MarkerProps {
  marker: string;
  onSelected?: (marker: string, meta: Modifier) => void;
  onHovered?: (marker: string | undefined) => void;
  children?: React.ReactNode;
}

export function Marker(props: MarkerProps): JSX.Element {
  const { marker, onSelected, onHovered, children } = props;
  const onDoubleClick = (): void => {
    onSelected && onSelected(marker, 'DOUBLE');
  };
  const onClick = (evt: React.MouseEvent): void => {
    evt.stopPropagation();
    onSelected && onSelected(marker, evt.altKey ? 'META' : 'NORMAL');
  };
  return (
    <span
      className="kernel-text-marker"
      onClick={onClick}
      onDoubleClick={onDoubleClick}
      onMouseEnter={() => onHovered && onHovered(marker)}
      onMouseLeave={() => onHovered && onHovered(undefined)}
    >
      {children}
    </span>
  );
}

export interface TextProps {
  text: KernelData.text;
  onSelected?: (marker: string, meta: Modifier) => void;
  onHovered?: (marker: string | undefined) => void;
  className?: string;
}

export function Text(props: TextProps): JSX.Element {
  const className = classes('kernel-text', 'dome-text-code', props.className);
  function makeContents(text: KernelData.text): React.ReactNode {
    if (Array.isArray(text)) {
      const tag = text[0];
      const marker = tag && typeof (tag) === 'string';
      const array = marker ? text.slice(1) : text;
      const contents = React.Children.toArray(array.map(makeContents));
      if (marker) {
        return (
          <Marker
            marker={tag}
            onSelected={props.onSelected}
            onHovered={props.onHovered}
          >
            {contents}
          </Marker>
        );
      }
      return <>{contents}</>;
    } if (typeof text === 'string') {
      return text;
    }
    D.error('Unexpected text', text);
    return null;
  }
  return <div className={className}>{makeContents(props.text)}</div>;
}

// --------------------------------------------------------------------------
