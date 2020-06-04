// --------------------------------------------------------------------------
// --- AST Information
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';

import { Vfill } from 'dome/layout/boxes';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { Component } from 'frama-c/LabViews';

// --------------------------------------------------------------------------
// --- Information Panel
// --------------------------------------------------------------------------

const ASTinfo = () => {

  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const [select, setSelect] = States.useSelection();
  const marker = select && select.marker;
  const data = States.useRequest(
    'kernel.ast.info',
    marker,
    { offline: undefined },
  );

  React.useEffect(() => {
    buffer.clear();
    if (marker && data) {
      buffer.printTextWithTags(data, { css: 'color: blue' });
    }
  }, [marker, buffer, data]);

  // Callbacks
  function onSelection(name: string) {
    // For now, the only markers are functions.
    setSelect({ function: name, marker: undefined });
  }

  // Component
  return (
    <>
      <Vfill>
        <Text
          buffer={buffer}
          mode="text"
          theme="default"
          onSelection={onSelection}
          readOnly
        />
      </Vfill>
    </>
  );
};

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="frama-c.astinfo"
    label="Information"
    title="AST Information"
  >
    <ASTinfo />
  </Component>
);

// --------------------------------------------------------------------------
