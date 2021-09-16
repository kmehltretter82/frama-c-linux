/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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
import { TitleBar } from 'ivette';
import * as Preferences from 'ivette/prefs';

import * as Ast from 'frama-c/api/kernel/ast';
import * as Properties from 'frama-c/api/kernel/properties';
import { getCallers, getDeadCode } from 'frama-c/api/plugins/eva/general';
import { getWritesLval, getReadsLval } from 'frama-c/api/plugins/studia/studia';

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
        const data = await Server.send(Ast.printFunction, theFunction);
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
    const locations = data.map(([fct, marker]) => ({ fct, marker }));
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

async function studia(
  marker: string,
  info: Ast.markerInfoData,
  kind: access,
) {
  const request = kind === 'Reads' ? getReadsLval : getWritesLval;
  const data = await Server.send(request, marker);
  const locations = data.direct.map(([f, m]) => ({ fct: f, marker: m }));
  const lval = info.name;
  if (locations.length > 0) {
    const name = `${kind} of ${lval}`;
    const acc = (kind === 'Reads') ? 'accessing' : 'modifying';
    const title =
      `List of statements ${acc} the memory location pointed by ${lval}.`;
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
    case 'considered_valid': return '#73bbbb';
    case 'invalid_but_dead':
    case 'valid_but_dead':
    case 'unknown_but_dead': return '#000000';
    case 'never_tried': return '#FFFFFF';
    case 'inconsistent': return '#FF00FF';
    default: return '#FF8300';
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

export default function ASTview() {

  // Hooks
  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const printed = React.useRef<string | undefined>();
  const [selection, updateSelection] = States.useSelection();
  const multipleSelections = selection?.multiple.allSelections;
  const theFunction = selection?.current?.fct;
  const theMarker = selection?.current?.marker;
  const { buttons: themeButtons, theme, fontSize, wrapText } =
    Preferences.useThemeButtons({
      target: 'Internal AST',
      theme: Preferences.AstTheme,
      fontSize: Preferences.AstFontSize,
      wrapText: Preferences.AstWrapText,
      disabled: !theFunction,
    });

  const markersInfo = States.useSyncArray(Ast.markerInfo);
  const deadCode = States.useRequest(getDeadCode, theFunction);
  const propertyStatus = States.useSyncArray(Properties.status).getArray();
  const statusDict = States.useTags(Properties.propStatusTags);

  const setBullets = React.useCallback(() => {
    if (theFunction) {
      propertyStatus.forEach((prop) => {
        if (prop.fct === theFunction) {
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

  async function reload() {
    printed.current = theFunction;
    loadAST(buffer, theFunction, theMarker);
  }

  // Hook: async loading
  React.useEffect(() => {
    if (printed.current !== theFunction)
      reload();
  });

  // Also reload the buffer when the AST is recomputed.
  Server.onSignal(Ast.computed, reload);

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

  function onSelection(markerId: string, meta = false) {
    const fct = selection?.current?.fct;
    const location = { fct, marker: Ast.jMarker(markerId) };
    updateSelection({ location });
    if (meta) States.MetaSelection.emit(location);
  }

  async function onContextMenu(markerId: string) {
    const items = [];
    const selectedMarkerInfo = markersInfo.getData(markerId);
    if (selectedMarkerInfo?.var === 'function') {
      if (selectedMarkerInfo.kind === 'declaration') {
        const name = selectedMarkerInfo?.name;
        if (name) {
          const locations = await functionCallers(name);
          const locationsByFunction = _.groupBy(locations, (e) => e.fct);
          _.forEach(locationsByFunction,
            (e) => {
              const callerName = e[0].fct;
              items.push({
                label:
                  `Go to caller ${callerName} ` +
                  `${e.length > 1 ? `(${e.length} call sites)` : ''}`,
                onClick: () => updateSelection({
                  name: `Call sites of function ${name}`,
                  locations,
                  index: locations.findIndex((l) => l.fct === callerName),
                }),
              });
            });
        }
      } else {
        items.push({
          label: `Go to definition of ${selectedMarkerInfo.name}`,
          onClick: () => {
            const location = { fct: selectedMarkerInfo.name };
            updateSelection({ location });
          },
        });
      }
    }
    const enabled = selectedMarkerInfo?.kind === 'lvalue'
      || selectedMarkerInfo?.var === 'variable';
    function onClick(kind: access) {
      if (selectedMarkerInfo)
        studia(
          markerId,
          selectedMarkerInfo,
          kind,
        ).then(updateSelection);
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
        onSelection={onSelection}
        onContextMenu={onContextMenu}
        gutters={['bullet']}
        readOnly
      />
    </>
  );

}

// --------------------------------------------------------------------------
