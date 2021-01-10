// --------------------------------------------------------------------------
// --- AST Information
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';
import * as Utils from 'frama-c/utils';

import { Vfill } from 'dome/layout/boxes';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { Component } from 'ivette';
import { getInfo } from 'frama-c/api/kernel/ast';

// --------------------------------------------------------------------------
// --- Information Panel
// --------------------------------------------------------------------------

const ASTinfo = () => {

  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const [selection, updateSelection] = States.useSelection();
  const marker = selection?.current?.marker;
  const data = States.useRequest(getInfo, marker);

  React.useEffect(() => {
    buffer.clear();
    if (data) {
      Utils.printTextWithTags(buffer, data, { css: 'color: blue' });
    }
  }, [buffer, data]);

  // Callbacks
  function onTextSelection(id: string) {
    // For now, the only markers are functions.
    const location = { fct: id };
    updateSelection({ location });
  }

  // Component
  return (
    <>
      <Vfill>
        <Text
          buffer={buffer}
          mode="text"
          theme="default"
          onSelection={onTextSelection}
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
