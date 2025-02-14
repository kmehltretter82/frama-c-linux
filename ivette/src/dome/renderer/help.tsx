/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2025                                                */
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

/**
  @packageDocumentation
  @module dome/help
 */

import React from 'react';
import { IconButton } from './controls/buttons';
import { Modal, showModal } from './dialogs';
import { Markdown } from './text/markdown';
import { SideBar, SidebarTitle } from './frame/sidebars';
import { Tree, Node } from './frame/tree';
import { LSplit } from './layout/splitters';

import * as Ivette from 'ivette';
import { DocProps } from 'ivette';
import { ipcRenderer } from 'electron';

/* --------------------------------------------------------------------------*/
/* --- Help                                                                  */
/* --------------------------------------------------------------------------*/

interface HelpIconProps {
  /** id */
  id: string;
  /** icon size */
  size?: number;
}

export function HelpIcon(props: HelpIconProps): JSX.Element {
  const { id, size } = props;

  return (
    <IconButton
      icon='HELP'
      size={size}
      className='dome-xDoc-icon'
      title={'Help'}
      onClick={() => showModal(<GeneralDocModal id={id} />)
      }
    />
  );
}

/** General doc */

interface IndexTree {
  level: number;
  label: string;
  id: string;
}

interface HNode {
  id: string;
  label: string;
  subTree: HNode[];
}

type HTree = HNode[];

function getTableOfContents(doc: DocProps): HTree {
  const regex = /^(#{1,4})\s(.+)\s\{#(.+)\}/gm;
  // Retrieving the title list with an id
  let matches;
  const titleWithId: IndexTree[] = [];
  while ((matches = regex.exec(doc.content)) !== null) {
      const level = matches[1].length;
      const label = matches[2];
      const id = matches[3];
      titleWithId.push({ level, label, id });
  }
  // Calculate the tree from the title list
  let i: number = 0;
  function toTree(): HTree {
    const t: HTree = [];
    while(i < titleWithId.length) {
      const elt = titleWithId[i];
      const newNode: HNode = {
        id: elt.id, label: elt.label, subTree: []
      };
      t.push(newNode);
      if(i+1 < titleWithId.length) {
        const nextLevel = titleWithId[i+1].level;
        if(nextLevel > elt.level) {
          i++;
          newNode.subTree = toTree();
        } else if(nextLevel < elt.level) break;
      }
      i++;
    }
    return t;
  }
  return toTree();
}

function getSubTree(tree: HTree): React.ReactNode {
  return tree.length > 0 ? <Nodes tree={tree} /> : null;
}

function Nodes(props: { tree: HTree }): React.ReactNode {
  return props.tree.map(({ id, label, subTree }) =>
    <Node key={id} id={id} label={label}>{ getSubTree(subTree) }</Node>
  );
}

function GeneralDocModal(props: { id?: string }): JSX.Element {
  const { id } = props;

  const selectedIdState = React.useState<string>(id || 'ivette');
  const [selectedId, setSelectedid] = selectedIdState;
  // const docList = Ivette.DOCITEM.getElements();

  const index = React.useMemo(() => {
    return Ivette.DOCITEM.getElements().map(item => {
      return getTableOfContents(item);
    });
  }, []);

  const currentDoc = React.useMemo(() => {
    const docId = selectedId.split('-')[0];
    return Ivette.DOCITEM.getElements().find(elt => elt.id === docId);
  }, [selectedId]);

  return (
    <Modal className='modal-framac-doc' label='Documentation'>
      <LSplit settings="frama-c.modal-doc.split">
        <SideBar>
          <SidebarTitle label='Table of contents' />
          <Tree
            unfoldAll={true}
            foldButtonPosition='right'
            selected={selectedId}
            onClick={(id) => setSelectedid(id) }
          >
            { index.map((e, i) => <Nodes
                key={i}
                tree={e}
              ></Nodes> ) }
          </Tree>
        </SideBar>
        <Markdown
          patterns={currentDoc?.patterns}
          scrollTo={selectedId}
        >
          { currentDoc?.content ?? `No documentation for \`${selectedId}\`` }
        </Markdown>
      </LSplit>
    </Modal>
  );
}

export function showFramaCDocModal(): void { showModal(<GeneralDocModal/>); }

ipcRenderer.on('dome.menu.help.open.doc', showFramaCDocModal);
