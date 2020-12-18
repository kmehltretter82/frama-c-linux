// --------------------------------------------------------------------------
// --- Diff Text Rendering
// --------------------------------------------------------------------------

import React from 'react';
import { Change, diffChars } from 'diff';

export class DiffBuffer {

  private readonly contents: React.ReactNode[] = [];
  private added = false;
  private removed = false;
  private value = '';

  constructor() {
    this.push = this.push.bind(this);
  }

  push(c: Change) {
    if (!c.added && !c.removed) this.flush();
    if (c.added) this.added = true;
    if (c.removed) this.removed = true;
    if (!c.added) this.value += c.value;
  }

  flush(): React.ReactNode[] {
    const { value, added, removed, contents } = this;
    if (value) {
      if (added && removed) {
        contents.push(<span className="eva-diff-modified">{value}</span>);
      } else if (removed) {
        contents.push(<span className="eva-diff-removed">{value}</span>);
      } else if (added) {
        contents.push(<span className="eva-diff-added" />);
      } else {
        contents.push(value);
      }
      this.value = '';
      this.added = false;
      this.removed = false;
    }
    return this.contents;
  }

}

/* --------------------------------------------------------------------------*/
/* --- Component with memoized diff                                       ---*/
/* --------------------------------------------------------------------------*/

export interface DiffedProps {
  original?: string;
  modified?: string;
}

export function Diffed(props: DiffedProps) {
  const { original = '', modified = '' } = props;
  const contents = React.useMemo(() => {
    if (original === modified) return original;
    const buffer = new DiffBuffer();
    diffChars(original, modified).forEach(buffer.push);
    return buffer.flush();
  }, [original, modified]);
  return <>{contents}</>;
}

// --------------------------------------------------------------------------
