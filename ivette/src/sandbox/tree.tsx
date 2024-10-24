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
/* --- Sandbox Testing of Tree                                            --- */
/* --- Only appears in DEVEL mode.                                        --- */
/* -------------------------------------------------------------------------- */

import React from 'react';
import { IconButton } from 'dome/controls/buttons';
import { registerSandbox } from 'ivette';
import { Tree, ITree, useTree, TFoldIconPosition } from 'dome/frame/tree';
import './style.css';
import { Label } from 'dome/controls/labels';
import { Panel } from 'dome/frame/panel';

/* -------------------------------------------------------------------------- */
/* --- Use Panel                                                          --- */
/* -------------------------------------------------------------------------- */
function SandboxTree(): JSX.Element {
  const tree = {
    id: '0', label: 'Node 0', subTree: [
      { id: '1', label: 'Node 1', subTree: [
          { id: '1.1', label: 'Node 1.1', subTree: [
              { id: '1.1.1', label: 'Node 1.1.1', subTree: [], },
              { id: '1.1.2', label: 'Node 1.1.2', subTree: [], },
            ],
          },
          { id: '1.2', label: 'Node 1.2', subTree: [
              { id: '1.2.1', label: 'Node 1.2.1', subTree: [], },
            ],
          },
        ],
      },
      { id: '2', label: 'Node 2', subTree: [
          { id: '2.1', label: 'Node 2.1', subTree: [
              { id: '2.1.1', label: 'Node 2.1.1', subTree: [], },
            ],
          },
          { id: '2.2', label: 'Node 2.2', subTree: [
              { id: '2.2.1', label: 'Node 2.2.1', subTree: [], },
              { id: '2.2.2', label: 'Node 2.2.2', subTree: [
                  { id: '2.2.2.1', label: 'Node 2.2.2.1', subTree: [], },
                ],
              },
            ],
          },
        ],
      },
      { id: '3', label: 'Node 3', subTree: [], },
      { id: '4', label: 'Node 4', subTree: [
          { id: '4.1', label: 'Node 4.1', subTree: [
              { id: '4.1.1', label: 'Node 4.1.1', subTree: [], },
            ],
          },
          { id: '4.2', label: 'Node 4.2', subTree: [
              { id: '4.2.1', label: 'Node 4.2.1', subTree: [], },
              { id: '4.2.2', label: 'Node 4.2.2 - with a long label', subTree: [
                  { id: '4.2.2.1', label: 'Node 4.2.2.1', subTree: [], },
                ],
              },
            ],
          },
        ],
      },
      { id: '5', label: 'Node 5', subTree: [
          { id: '5.1', label: 'Node 5.1', subTree: [
              { id: '5.1.1', label: 'Node 5.1.1', subTree: [], },
            ],
          },
          { id: '5.2', label: 'Node 5.2', subTree: [
              { id: '5.2.1', label: 'Node 5.2.1', subTree: [
                { id: '5.2.1.1', label: 'Node 5.2.1.1', subTree: [
                    { id: '5.2.1.1.1', label: 'Node 5.2.1.1.1', subTree: [], },
                  ],
                },
              ],
            },
            ],
          },
        ],
      },
    ]
  };

  const uTree = useTree(tree);

  const getActions = (t: ITree): JSX.Element => {
    return <IconButton
      icon={t.selected ? 'FAVORITE':'STAR'}
      title={t.selected ? 'Selected':'Select'}
      onClick={() => {
        uTree.flipSelect(t.id);
      }}
    />;
  };
  const [ position, setPosition ] = React.useState<TFoldIconPosition>('right');

  return (
    <>
      <div style={{ position: 'relative', height: '100%' }}>
        <Panel position='left' display={true}>
          <div className='sandbox-xTree-title'>
            <Label icon={'TREE'} label={'Tree structure'} />
            <div className='sandbox-xTree-actions'>
              <IconButton
                icon='CHEVRON.EXPAND'
                title='Change folding button position'
                size={16}
                className={'sandbox-xTree-folding-position'}
                onClick={() => {
                  setPosition((val) => val === 'left' ? 'right' : 'left');
                }}
              />
              <IconButton icon='ANGLE.DOWN' title='Unfold all' size={14}
                onClick={() => {
                  uTree.unfoldAll();
                }}
              />
              <IconButton icon='ANGLE.UP' title='fold all' size={14}
                onClick={() => {
                  uTree.foldAll();
                }}
              />
            </div>
          </div>
          <div className='sandbox-xTree-separator'></div>
          <Tree uTree={uTree} getActions={getActions}
            options={{
              foldingButtonPosition: position
            }}
          />
        </Panel>
      </div>
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.tree',
  label: 'Tree',
  children: <SandboxTree />,
});

/* -------------------------------------------------------------------------- */
