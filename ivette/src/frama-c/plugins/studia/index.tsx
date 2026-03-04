/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';

import * as Dome from 'dome';
import * as Display from 'ivette/display';
import { showHelp } from 'dome/help';
import { FieldState, TextField, useState } from 'dome/layout/forms';
import { closeModal, Modal, showModal } from 'dome/dialogs';
import { IconButton } from 'dome/controls/buttons';
import { Button, ButtonGroup } from 'dome/frame/toolbars';
import { Hbox } from 'dome/layout/boxes';
import { Code } from 'dome/controls/labels';
import { Icon } from 'dome/controls/icons';

import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/kernel/api/ast';
import * as ASTview from 'frama-c/kernel/ASTview';
import * as Locations from 'frama-c/kernel/Locations';
import { getWritesLval, getReadsLval } from 'frama-c/plugins/studia/api/studia';
import './style.css';

type access = 'Reads' | 'Writes';

function handleError(err: string): void {
  Display.showWarning({ label: 'Studia Failure', title: `Error (${err})` });
}

async function computeStudiaSelection(
  kind: access,
  marker: Ast.marker,
  descr: string,
  onError?: (err: string) => void,
  onSuccess?: () => void
): Promise<void> {
  const request = kind === 'Reads' ? getReadsLval : getWritesLval;
  const data = await Server.send(request, marker).catch((err: string) => {
    handleError(err);
    if(onError) onError(err);
  });
  const markers = data?.direct ?? [];
  if (markers.length > 0) {
    const label = (kind === 'Reads' ? 'Reads of ' : 'Writes to ') + `${descr}`;
    const access = kind === 'Reads' ? 'accessing' : 'modifying';
    const title =
      `Statements ${access} the memory location pointed by ${descr}.`;
    Locations.setSelection({
      plugin: 'Studia', label, title, markers,
    });
  } else {
    const label = `No ${kind.toLowerCase()} to ${descr}`;
    Locations.setSelection({
      plugin: 'Studia', label, markers: []
    });
  }
  if(onSuccess) onSuccess();
}

/** Builds the Studia entries in the contextual menu about a given marker.  */
export function buildMenu(
  menu: Dome.PopupMenuItem[],
  attr: Ast.markerAttributesData,
): void {
  function addSubMenu(submenu: Dome.PopupMenuItem[]): void {
    const helpItem = {
      label: 'Help',
      onClick: () => showHelp('eva-studia'),
    };
    submenu.push(helpItem);
    menu.push({ label: 'Studia', submenu });
  }
  const { marker, kind } = attr;
  switch (kind) {
    case 'LVAL':
    case 'DVAR':
    case 'LVAR':
      addSubMenu([
        {
          label: `Select reads`,
          onClick: () => computeStudiaSelection('Reads', marker, attr.descr)
        },
        {
          label: `Select writes`,
          onClick: () => computeStudiaSelection('Writes', marker, attr.descr)
        }
      ]);
      return;
    case 'STMT':
      menu.push({ label: 'Studia', onClick: () => showModalStudia(attr) });
      return;
  }
}

ASTview.registerMarkerMenuExtender(buildMenu);

/* -------------------------------------------------------------------------- */
/* --- Modal                                                              --- */
/* -------------------------------------------------------------------------- */

interface ModalTextFielddProps {
  attr: Ast.markerAttributesData;
}

function ModalStudiaSearch(props: ModalTextFielddProps)
: React.JSX.Element {
  const { attr } = props;
  const state = useState('');
  const [akind, setAkind] = React.useState<access>('Reads');
  const [error, setError] = React.useState<string | undefined>();

  const onValidate = React.useCallback(async (p: string) => {
    const marker = await Server.send(
      Ast.parseLval, { stmt: attr.marker, term: p }
    ).catch((err: string) => {
        handleError(err);
        setError(err);
      });
    if (marker)
      computeStudiaSelection(akind, marker, p, setError, () => closeModal());
  }, [akind, attr.marker, setError]);

  return <Modal
      className='modal-studia'
      label={`Studia: ${attr.sloc?.base}`}
      actions={<IconButton icon='HELP' size={15}
        onClick={() => showHelp('eva-studia')} />
      }
    >
    <div>
      <Hbox>
        <ButtonGroup>
          <Button
            label='Reads of'
            selected={akind === 'Reads'}
            onClick={() => setAkind('Reads')}
            />
          <Button
            label='Writes to'
            selected={akind === 'Writes'}
            onClick={() => setAkind('Writes')}
            />
        </ButtonGroup>
        <Code>{attr.descr}</Code>
      </Hbox>
      <Hbox>
        <TextField
          label=''
          autoFocus={true}
          state={state as FieldState<string | undefined>}
          onKeyDown={(e) => {
              if(e.key === "Enter")
                onValidate(state.value);
            }
          }
        />
        <Button
          label='Search'
          onClick={() => onValidate(state.value)}
          />
      </Hbox>
      { error &&
        <Hbox>
          <Icon id='WARNING' kind='warning' />
          <span>Studia Failure: {error}</span>
        </Hbox>
      }
    </div>
  </Modal>;
}

async function showModalStudia(
  attr: Ast.markerAttributesData
): Promise<void> {
  showModal(<ModalStudiaSearch attr={attr} />);
}
/* -------------------------------------------------------------------------- */
