// --------------------------------------------------------------------------
// --- Diff Text Rendering
// --------------------------------------------------------------------------

import React from 'react';
import { Change, diffChars } from 'diff';

const MODIFIED = 'eva-diff eva-diff-modified';
const REMOVED = 'eva-diff eva-diff-removed';
const ADDED = 'eva-diff eva-diff-added';
const SHADOW = 'eva-diff eva-diff-shadow';

export class DiffBuffer {

  private added = false;
  private removed = false;
  private value = '';
  private scratch = '';
  private contents: React.ReactNode[] = [];

  constructor() {
    this.push = this.push.bind(this);
  }

  clear() {
    this.added = false;
    this.removed = false;
    this.value = '';
    this.scratch = '';
    this.contents = [];
  }

  push(c: Change) {
    if (!c.added && !c.removed) {
      this.flush();
      this.value += c.value;
      this.flush();
    } else {
      if (c.added) this.added = true;
      if (c.removed) {
        this.removed = true;
        this.value += c.value;
      }
    }
  }

  private flush() {
    const { value, added, removed } = this;
    if (added && removed) {
      if (value) {
        this.scratch += '\0'.repeat(value.length);
        this.contents.push(
          <span className={MODIFIED} title="Modified"> {value}</span>,
        );
      }
    } else if (removed) {
      if (value) {
        this.contents.push(
          <span className={REMOVED} title="Removed">{value}</span>,
        );
      }
    } else if (added) {
      this.contents.push(
        <span className={ADDED}><span className={SHADOW} /></span>,
      );
    } else if (value) {
      this.scratch += value;
      this.contents.push(value);
    }
    this.value = '';
    this.added = false;
    this.removed = false;
  }

  getContents(): React.ReactNode {
    this.flush();
    return React.Children.toArray(this.contents);
  }

  getScratch() {
    this.flush();
    return this.scratch;
  }

}

/* --------------------------------------------------------------------------*/
/* --- Diff2 Component                                                    ---*/
/* --------------------------------------------------------------------------*/

export interface Diff2Props {
  text: string;
  diff: string;
}

export function Diff2(props: Diff2Props) {
  const { text, diff } = props;
  const contents = React.useMemo<React.ReactNode>(() => {
    if (text === diff) return text;
    const buffer = new DiffBuffer();
    const chunks = diffChars(text, diff);
    chunks.forEach(buffer.push);
    return buffer.getContents();
  }, [text, diff]);
  return <>{contents}</>;
}

/* --------------------------------------------------------------------------*/
/* --- Diff3 Component                                                    ---*/
/* --------------------------------------------------------------------------*/

export interface Diff3Props {
  text: string;
  diffA: string;
  diffB: string;
}

export function Diff3(props: Diff3Props) {
  const { text, diffA, diffB } = props;
  const contents = React.useMemo<React.ReactNode>(() => {
    if (text === diffA && text === diffB) return text;
    const buffer = new DiffBuffer();
    diffChars(diffA, diffB).forEach(buffer.push);
    const scratch = buffer.getScratch();
    buffer.clear();
    diffChars(text, scratch).forEach(buffer.push);
    return buffer.getContents();
  }, [text, diffA, diffB]);
  return <>{contents}</>;
}

/* --------------------------------------------------------------------------*/
/* --- Diff Component                                                     ---*/
/* --------------------------------------------------------------------------*/

export interface DiffProps {
  text: string;
  diff?: string;
  diffA?: string;
  diffB?: string;
}

export function Diff(props: DiffProps) {
  const { text, diff, diffA, diffB } = props;
  if (text === diff) return <>{text}</>;
  if (diff !== undefined)
    return <Diff2 text={text} diff={diff} />;
  if (diffA === undefined) {
    if (diffB === undefined) return <>{text}</>;
    return <Diff2 text={text} diff={diffB} />;
  } if (diffB === undefined) {
    if (diffA === undefined) return <>{text}</>;
    return <Diff2 text={text} diff={diffA} />;
  }
  return <Diff3 text={text} diffA={diffA} diffB={diffB} />;
}

// --------------------------------------------------------------------------
