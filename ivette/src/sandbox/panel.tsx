/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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

/* -------------------------------------------------------------------------- */
/* --- Sandbox Testing of Panel                                           --- */
/* --- Only appears in DEVEL mode.                                        --- */
/* -------------------------------------------------------------------------- */

import React from 'react';
import * as Dome from 'dome';
import { IconButton } from 'dome/controls/buttons';
import { registerSandbox, TitleBar } from 'ivette';
import {
  Panel, ListElement, Element, PanelPosition
} from 'dome/frame/panel';
import { Button, ButtonGroup } from 'dome/frame/toolbars';
import { Icon } from 'dome/controls/icons';
import './style.css';
import { Label } from 'dome/controls/labels';

/* -------------------------------------------------------------------------- */
/* --- Use Panel                                                          --- */
/* -------------------------------------------------------------------------- */
function UsePanel(): JSX.Element {
  const [position, setPosition] = React.useState<PanelPosition>('right');
  const [visible, flipVisible] = Dome.useFlipState(true);
  const [selected, setSelected] = React.useState(1);
  const [list, setList] = React.useState({
      flip: true,
      list: [
        { id: 1, children: <div>item 1</div> },
        { id: 2, children: <div>item 2</div> },
        { id: 3, children: <div>item 3</div> },
        { id: 4, children: <div>item 4</div> },
      ]
    }
  );

  return (
    <>
      <TitleBar>
        <IconButton
          icon='ANGLE.RIGHT'
          title="Change position of Panel."
          className={'sandbox-panel-button-position-'+position}
          onClick={() => setPosition((val) => {
              return val === 'right' ? 'bottom' :
                     val === 'bottom' ? 'left' :
                     val === 'left' ? 'top' :
                     'right';
            })
          }
        />

        <IconButton
          icon="SIDEBAR"
          title={"show or hide the panel"}
          onClick={flipVisible}
        />
      </TitleBar>
      <div style={{ position: 'relative', height: '100%' }}>
        <Panel visible={visible} position={position}>
          <Label
            label="label"
            title="Text Component"
            icon="CODE"
          >
            Content of the Text component.
          </Label>

          <Label>
            <ButtonGroup>
              <Button
                label='left'
                selected={position === 'left'}
                onClick={() => setPosition('left')} />
              <Button
                label='top'
                selected={position === 'top'}
                onClick={() => setPosition('top')} />
              <Button
                label='right'
                selected={position === 'right'}
                onClick={() => setPosition('right')} />
              <Button
                label='bottom'
                selected={position === 'bottom'}
                onClick={() => setPosition('bottom')} />
            </ButtonGroup>
            <Button
              icon='SIDEBAR'
              title="This button is always selected when the panel is visible."
              selected={visible}
              onClick={() => flipVisible()} />
          </Label>

          <Label
            label="List icon"
            title="Text Component"
          >
            <Icon id="WARNING"/>
            <Icon id="SETTINGS"/>
            <Icon id="RELOAD"/>
            <Icon id="DOWNLOAD"/>
            <Icon id="LOCK"/>
          </Label>

          <Label
            label="Add/remove element"
            title="Text Component"
          >
            <Button
              icon='PLUS'
              title="This button add an element t the end of the list."
              onClick={() => setList((elt) => {
                  const newId = elt.list.length + 1;
                  const newChild = "item "+newId;
                  elt.list.push({
                    id: newId, children: <div>{newChild}</div>
                  });
                  return { flip: !elt.flip, list: elt.list };
                }
              )}
            />
            <Button
              icon='MINUS'
              title="This button remove the last element of the list."
              onClick={() => setList((elt) => {
                  elt.list.pop();
                  return { flip: !elt.flip, list: elt.list };
                }
              )}
            />
          </Label>
          <ListElement>
            { list.list.map((elt, k) =>
              <Element
                key={k}
                selected={selected === elt.id}
                onSelection={() => setSelected(elt.id)}
              >
                {elt.children}
              </Element>
              )
            }
          </ListElement>
        </Panel>
      </div>
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.panel',
  label: 'Panel',
  children: <UsePanel />,
});

/* -------------------------------------------------------------------------- */
