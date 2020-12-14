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
import * as Settings from 'dome/data/settings';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { IconButton } from 'dome/controls/buttons';
import { Component, TitleBar } from 'frama-c/LabViews';
import { printFunction, markerInfo, markerInfoData }
  from 'frama-c/api/kernel/ast';
import { getCallers, getDeadCode } from 'frama-c/api/plugins/eva/general';
import { getWritesLval, getReadsLval } from 'frama-c/api/plugins/studia/studia';

import 'codemirror/mode/clike/clike';
import 'codemirror/theme/ambiance.css';
import 'codemirror/theme/solarized.css';

import { Theme, FontSize } from './Preferences';

const THEMES = [
  { id: 'default', label: 'Default' },
  { id: 'ambiance', label: 'Ambiance' },
  { id: 'solarized light', label: 'Solarized Light' },
  { id: 'solarized dark', label: 'Solarized Dark' },
];

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

/* --------------------------------------------------------------------------*/
/* --- Function Callers                                                   ---*/
/* --------------------------------------------------------------------------*/

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

/* --------------------------------------------------------------------------*/
/* --- Studia Access                                                      ---*/
/* --------------------------------------------------------------------------*/

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

/* --------------------------------------------------------------------------*/
/* --- Property Bullets                                                   ---*/
/* --------------------------------------------------------------------------*/

function getBulletColor(status: States.Tag) {
  switch (status.name) {
    case 'unknown': return '#FF8300';
    case 'invalid':
    case 'invalid_under_hyp': return '#FF0000';
    case 'valid':
    case 'valid_under_hyp': return '#00B900';
    case 'considered_valid': return '#0000FF';
    case 'invalid_but_dead':
    case 'valid_but_dead':
    case 'unknown_but_dead': return '#000000';
    case 'never_tried': return '#FFFFFF';
    case 'inconsistent': return '#FF00FF';
    default: return '#0000FF';
  }
}

function makeBullet(status: States.Tag) {
  const marker = document.createElement('div');
  marker.style.color = getBulletColor(status);
  if (status.descr)
    marker.title = status.descr;
  marker.innerHTML = '◉';
  marker.align = 'center';
  return marker;
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
  const [theme, setTheme] = Settings.useGlobalSettings(Theme);
  const [fontSize, setFontSize] = Settings.useGlobalSettings(FontSize);
  const [wrapText, flipWrapText] = Dome.useFlipSettings('ASTview.wrapText');
  const markersInfo = States.useSyncArray(markerInfo);

  const theFunction = selection?.current?.function;
  const theMarker = selection?.current?.marker;

  const deadCode = States.useRequest(getDeadCode, theFunction);

  const propertyStatus = States.useSyncArray(Properties.status).getArray();
  const statusDict = States.useTags(Properties.propStatusTags);

  const setBullets = React.useCallback(() => {
    if (theFunction) {
      propertyStatus.forEach((prop) => {
        if (prop.function === theFunction) {
          const status = statusDict.get(prop.status);
          if (status) {
            const bullet = makeBullet(status);
            const markers = buffer.findTextMarker(prop.key);
            markers.forEach((marker) => {
              const pos = marker.find();
              buffer.forEach((cm) => {
                cm.setGutterMarker(pos.from.line, 'bullet', bullet);
              });
            });
          }
        }
      });
    }
  }, [buffer, theFunction, propertyStatus, statusDict]);

  React.useEffect(() => {
    buffer.on('change', setBullets);
    return () => { buffer.off('change', setBullets); };
  }, [buffer, setBullets]);

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

  // Theme Popup
  const selectTheme = (id?: string) => id && setTheme(id);
  const themeItem = (th: { id: string; label: string }) => (
    { checked: th.id === theme, ...th }
  );
  const themePopup = () => Dome.popupMenu(THEMES.map(themeItem), selectTheme);

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
          onClick={flipWrapText}
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
        gutters={['bullet']}
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
