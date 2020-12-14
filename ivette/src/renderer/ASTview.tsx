// --------------------------------------------------------------------------
// --- AST Source Code
// --------------------------------------------------------------------------

import React from 'react';
import _ from 'lodash';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Utils from 'frama-c/utils';

import * as Dome from 'dome';
import * as Json from 'dome/data/json';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { Component, TitleBar } from 'frama-c/LabViews';
import { printFunction, markerInfo, markerInfoData }
  from 'frama-c/api/kernel/ast';
import { getCallers, getDeadCode } from 'frama-c/api/plugins/eva/general';
import { getWritesLval, getReadsLval } from 'frama-c/api/plugins/studia/studia';

import * as Preferences from './Preferences';

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

const D = new Dome.Debug('AST View');

// --------------------------------------------------------------------------
// --- Rich Text Printer
// --------------------------------------------------------------------------

async function loadAST(
  buffer: RichTextBuffer, theFunction?: string, theMarker?: string,
) {
  buffer.clear();
  if (theFunction) {
    buffer.log('// Loading', theFunction, '…');
    (async () => {
      try {
        const data = await Server.send(printFunction, theFunction);
        buffer.clear();
        if (!data) {
          buffer.log('// No code for function', theFunction);
        }
        Utils.printTextWithTags(buffer, data);
        if (theMarker)
          buffer.scroll(theMarker);
      } catch (err) {
        D.error(
          `Fail to retrieve the AST of function '${theFunction}' ` +
          `and marker '${theMarker}':`, err,
        );
      }
    })();
  }
}

/** Compute the [[functionName]] caller locations. */
async function functionCallers(functionName: string) {
  try {
    const data = await Server.send(getCallers, functionName);
    const locations = data.map(([fct, marker]) => ({ function: fct, marker }));
    return locations;
  } catch (err) {
    D.error(`Fail to retrieve callers of function '${functionName}':`, err);
    return [];
  }
}

type access = 'Reads' | 'Writes';

async function studia(marker: string, info: markerInfoData, kind: access) {
  const request = kind === 'Reads' ? getReadsLval : getWritesLval;
  const data = await Server.send(request, marker);
  const locations = data.direct.map(([f, m]) => ({ function: f, marker: m }));
  const lval = info.name;
  if (locations.length > 0) {
    const name = `${kind} of ${lval}`;
    const title = `List of statements ${
      (kind === 'Reads') ? 'accessing' : 'modifying'
    } the memory location pointed by ${lval}.`;
    return { name, title, locations, index: 0 };
  }
  const name = `No ${kind.toLowerCase()} of ${lval}`;
  return { name, title: '', locations: [], index: 0 };
}

// --------------------------------------------------------------------------
// --- AST Printer
// --------------------------------------------------------------------------

const ASTview = () => {

  // Hooks
  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const printed = React.useRef<string | undefined>();
  const [selection, updateSelection] = States.useSelection();
  const multipleSelections = selection?.multiple.allSelections;
  const theFunction = selection?.current?.function;
  const theMarker = selection?.current?.marker;
  const { buttons: themeButtons, theme, fontSize, wrapText } =
    Preferences.useThemeButtons({
      target: 'Internal AST',
      theme: Preferences.AstTheme,
      fontSize: Preferences.AstFontSize,
      wrapText: Preferences.AstWrapText,
      disabled: !theFunction,
    });
  const markersInfo = States.useSyncArray(markerInfo);

  const deadCode = States.useRequest(getDeadCode, theFunction);

  // Hook: async loading
  React.useEffect(() => {
    if (printed.current !== theFunction) {
      printed.current = theFunction;
      loadAST(buffer, theFunction, theMarker);
    }
  });

  React.useEffect(() => {
    const decorator = (marker: string) => {
      if (multipleSelections?.some((location) => location?.marker === marker))
        return 'highlighted-marker';
      if (deadCode?.unreachable?.some((m) => m === marker))
        return 'dead-code';
      if (deadCode?.nonTerminating?.some((m) => m === marker))
        return 'non-terminating';
      return undefined;
    };
    buffer.setDecorator(decorator);
  }, [buffer, multipleSelections, deadCode]);

  // Hook: marker scrolling
  React.useEffect(() => {
    if (theMarker) buffer.scroll(theMarker);
  }, [buffer, theMarker]);

  function onTextSelection(id: string) {
    if (selection.current) {
      const location = { ...selection.current, marker: id };
      updateSelection({ location });
    }
  }

  async function onContextMenu(id: string) {
    const items = [];
    const markerId = (id as Json.key<'#markerInfo'>);
    const selectedMarkerInfo = markersInfo.getData(markerId);
    if (selectedMarkerInfo?.var === 'function') {
      if (selectedMarkerInfo.kind === 'declaration') {
        const name = selectedMarkerInfo?.name;
        if (name) {
          const locations = await functionCallers(name);
          const locationsByFunction = _.groupBy(locations, (e) => e.function);
          _.forEach(locationsByFunction,
            (e) => {
              const callerName = e[0].function;
              items.push({
                label:
                  `Go to caller ${callerName} ` +
                  `${e.length > 1 ? `(${e.length} call sites)` : ''}`,
                onClick: () => updateSelection({
                  name: `Call sites of function ${name}`,
                  locations,
                  index: locations.findIndex((l) => l.function === callerName),
                }),
              });
            });
        }
      } else {
        items.push({
          label: `Go to definition of ${selectedMarkerInfo.name}`,
          onClick: () => {
            const location = { function: selectedMarkerInfo.name };
            updateSelection({ location });
          },
        });
      }
    }
    const enabled = selectedMarkerInfo?.kind === 'lvalue'
      || selectedMarkerInfo?.var === 'variable';
    function onClick(kind: access) {
      if (selectedMarkerInfo)
        studia(markerId, selectedMarkerInfo, kind).then(updateSelection);
    }
    items.push({
      label: 'Studia: select writes',
      enabled,
      onClick: () => onClick('Writes'),
    });
    items.push({
      label: 'Studia: select reads',
      enabled,
      onClick: () => onClick('Reads'),
    });
    if (items.length > 0)
      Dome.popupMenu(items);
  }

  // Component
  return (
    <>
      <TitleBar>
        {themeButtons}
      </TitleBar>
      <Text
        buffer={buffer}
        mode="text/x-csrc"
        theme={theme}
        fontSize={fontSize}
        lineWrapping={wrapText}
        selection={theMarker}
        onSelection={onTextSelection}
        onContextMenu={onContextMenu}
        readOnly
      />
    </>
  );

};

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="frama-c.astview"
    label="AST"
    title="Normalized source code representation"
  >
    <ASTview />
  </Component>
);

// --------------------------------------------------------------------------
