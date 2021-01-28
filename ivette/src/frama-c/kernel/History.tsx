/* --------------------------------------------------------------------------*/
/* --- Frama-C Selection History                                          ---*/
/* --------------------------------------------------------------------------*/

import React from 'react';
import * as Toolbar from 'dome/frame/toolbars';
import * as States from 'frama-c/states';

export default function History() {
  const [selection, updateSelection] = States.useSelection();

  const doPrevSelect = () => { updateSelection('HISTORY_PREV'); };
  const doNextSelect = () => { updateSelection('HISTORY_NEXT'); };

  return (
    <Toolbar.ButtonGroup>
      <Toolbar.Button
        icon="ANGLE.LEFT"
        onClick={doPrevSelect}
        disabled={!selection || selection.history.prevSelections.length === 0}
        title="Previous location"
      />
      <Toolbar.Button
        icon="ANGLE.RIGHT"
        onClick={doNextSelect}
        disabled={!selection || selection.history.nextSelections.length === 0}
        title="Next location"
      />
    </Toolbar.ButtonGroup>
  );
}

/* --------------------------------------------------------------------------*/
