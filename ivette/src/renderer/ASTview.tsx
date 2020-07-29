// --------------------------------------------------------------------------
// --- AST Source Code
// --------------------------------------------------------------------------

import React from 'react';
import _ from 'lodash';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Utils from 'frama-c/utils';

import * as Dome from 'dome';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { IconButton } from 'dome/controls/buttons';
import { Component, TitleBar } from 'frama-c/LabViews';
import { printFunction, markerInfo } from 'api/kernel/ast';
import { getCallers, getDeadCode } from 'api/plugins/eva/general';

import 'codemirror/mode/clike/clike';
import 'codemirror/theme/ambiance.css';
import 'codemirror/theme/solarized.css';

const THEMES = [
  { id: 'default', label: 'Default' },
  { id: 'ambiance', label: 'Ambiance' },
  { id: 'solarized light', label: 'Solarized Light' },
  { id: 'solarized dark', label: 'Solarized Dark' },
];

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

const PP = new Dome.PP('AST View');

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
        PP.error(
          'Fail to obtain AST', theFunction, theMarker, err,
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
    PP.error(`Fail to retrieve callers of function '${functionName}':`, err);
    return [];
  }
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
  const [theme, setTheme] = Dome.useGlobalSetting('ASTview.theme', 'default');
  const [fontSize, setFontSize] = Dome.useGlobalSetting('ASTview.fontSize', 12);
  const [wrapText, setWrapText] = Dome.useSwitch('ASTview.wrapText', false);
  const markersInfo = States.useSyncArray(markerInfo).getArray();

  const theFunction = selection?.current?.function;
  const theMarker = selection?.current?.marker;

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

  // Callbacks
  const zoomIn = () => fontSize < 48 && setFontSize(fontSize + 2);
  const zoomOut = () => fontSize > 4 && setFontSize(fontSize - 2);

  function onTextSelection(id: string) {
    if (selection.current) {
      const location = { ...selection.current, marker: id };
      updateSelection({ location });
    }
  }

  async function onContextMenu(id: string) {
    const items = [];
    const selectedMarkerInfo = markersInfo.find((e) => e.key === id);
    if (selectedMarkerInfo?.var === 'function') {
      if (selectedMarkerInfo.kind === 'declaration') {
        if (selectedMarkerInfo?.name) {
          const locations = await functionCallers(selectedMarkerInfo.name);
          const locationsByFunction = _.groupBy(locations, (e) => e.function);
          _.forEach(locationsByFunction,
            (e) => {
              const callerName = e[0].function;
              items.push({
                label:
                  `Go to caller ${callerName} ` +
                  `${e.length > 1 ? `(${e.length} call sites)` : ''}`,
                onClick: () => updateSelection({
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
    if (items.length > 0)
      Dome.popupMenu(items);
  }

  // Theme Popup
  const selectTheme = (id?: string) => id && setTheme(id);
  const checkTheme =
    (th: { id: string }) => ({ checked: th.id === theme, ...th });
  const themePopup =
    () => Dome.popupMenu(THEMES.map(checkTheme), selectTheme);

  // Component
  return (
    <>
      <TitleBar>
        <IconButton
          icon="ZOOM.OUT"
          onClick={zoomOut}
          disabled={!theFunction}
          title="Decrease font size"
        />
        <IconButton
          icon="ZOOM.IN"
          onClick={zoomIn}
          disabled={!theFunction}
          title="Increase font size"
        />
        <IconButton
          icon="PAINTBRUSH"
          onClick={themePopup}
          title="Choose theme"
        />
        <IconButton
          icon="WRAPTEXT"
          selected={wrapText}
          onClick={setWrapText}
          title="Wrap text"
        />
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
