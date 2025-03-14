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
import { modal } from 'dome';
import { GlobalState, useGlobalState } from 'dome/data/states';

import { IconButton } from './controls/buttons';
import { Modal, showModal, closeModal } from './dialogs';
import { Markdown } from './text/markdown';
import { SideBar, SidebarTitle } from './frame/sidebars';
import { Tree, Node } from './frame/tree';
import { LSplit } from './layout/splitters';

import * as Ivette from 'ivette';
import { ChapterProps } from 'ivette';
import { Icon } from './controls/icons';
import { LED } from './controls/displays';

/* --------------------------------------------------------------------------*/
/* --- Help                                                                  */
/* --------------------------------------------------------------------------*/

const lastDocOpened = new GlobalState<string>('ivette');

interface HelpButtonProps {
  /** id */
  id: string;
  /** icon size */
  size?: number;
}

export function HelpButton(props: HelpButtonProps): JSX.Element {
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
interface Index {
  level: number;
  label: string;
  id: string;
}

interface HNode {
  id: string;
  label: string;
  errors?: string[];
  subTree: HNode[];
}

type HTree = HNode[];

function getTableOfContents(chapter: ChapterProps): HTree {
  const regex = /^(#{1,4})\s(.+)\s\{#(.+)\}/gm;
  // Retrieving H1, H2, H3, H4 titles with an id
  let matches;
  const titles: Index[] = [];
  while ((matches = regex.exec(chapter.content)) !== null) {
      const level = matches[1].length;
      const label = matches[2];
      const id = matches[3];
      titles.push({ level, label, id });
  }

  // Check title list
  function checkTitles(): string[] {
    const errors: string[] = [];
    const ids: string[] = [];
    const indexToDelete: number[] = [];
    let h1Error = false;
    const duplicateIds: string[] = [];
    const badStartingIds: string[] = [];

    titles.forEach((title, index) => {
      const { level, id } = title;
      // Check H1
      if(!h1Error && (
        (level === 1 && index > 0) || (level !== 1 && index === 0))
      ) { h1Error = true; }
      // Check duplicate ID
      if(ids.find(e => e === id) !== undefined) {
        indexToDelete.push(index);
        duplicateIds.push(id);
      } else ids.push(id);
      // Check if ID stating with chapter.id
      if(id.split('-')[0] !== chapter.id) badStartingIds.push(id);
    });
    // Add errors
    if(h1Error) errors.push(
      'The chapter must have one H1 and it must be placed at the beginning\n');
    if(duplicateIds.length > 0) {
      errors.push('Duplicate Ids are removed from table of content:');
      duplicateIds.forEach(id => errors.push(`- ${id}`));
    }
    if(badStartingIds.length > 0) {
      errors.push(`Id must start with "${chapter.id}":`);
      badStartingIds.forEach(id => errors.push(`- ${id}`));
    }

    indexToDelete.forEach(i => titles.splice(i, 1));
    return errors;
  }
  const errors = checkTitles();

  // Calculate the tree from the titles list
  let i: number = 0;
  function toTree(): HTree {
    const t: HTree = [];
    while(i < titles.length) {
      const elt = titles[i];
      const newNode: HNode = {
        id: elt.id, label: elt.label, subTree: []
      };
      if(elt.level === 1) newNode.errors = errors;
      t.push(newNode);
      if(i+1 < titles.length) {
        const nextLevel = titles[i+1].level;
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
  return props.tree.map(({ id, label, errors, subTree }) => {
    const actions = errors && errors.length > 0 ? (
      <>
        <LED status="negative" blink={true} />
        <Icon id='WARNING' kind="negative" title={errors.join('\n')}></Icon>
        <LED status="negative" blink={true} />
      </>) :
      undefined;
    return <Node key={id} id={id} label={label} actions={actions}>
        { getSubTree(subTree) }</Node>;
  }
  );
}

/**
  * Each chapter must have a unique identifier.
  * If a chapter is saved with an existing identifier, the identifier will be
  * changed and errors will appear on the last chapter saved.
  * Each *.md file must declare a unique H1 key with
  * # <title> {#<id>} with <id> without -.
  * Each *.md file can then declare H2, H3 or H4 keys with
  * #+ <title> {#<id>-<subid>} with <subid>
  * which can optionally be compounded with - (unrelated to depth level).
*/
function GeneralDocModal(props: { id?: string }): JSX.Element {
  const { id } = props;
  const [ unfoldAll, setUnfoldAll ] = React.useState<boolean|undefined>(true);
  const [ lastId, setLastId ] = useGlobalState(lastDocOpened);
  const selectedIdState = React.useState<string>(id || lastId);
  const [ selectedId, setSelectedid ] = selectedIdState;

  const index = React.useMemo(() => {
    return Ivette.DOCCHAPTER.getElements()
      .sort((a, b) => {
        const A = a.rank ?? 50;
        const B = b.rank ?? 50;
        return A - B;
      })
      .map(item => {
        return getTableOfContents(item);
      });
  }, []);

  const currentDoc = React.useMemo(() => {
    const docId = selectedId.split('-')[0];
    return Ivette.DOCCHAPTER.getElements().find(elt => elt.id === docId);
  }, [selectedId]);

  const title = React.useMemo(() => {
    const ids = selectedId.split('-');
    const chapter = ids[0].charAt(0).toUpperCase() + ids[0].slice(1);
    const section = ids.slice(1).join(' ');
    return `Documentation ${chapter} ${section ? "- "+section: ""}`;
  }, [selectedId]);

  React.useEffect(() => { setLastId(selectedId); }, [selectedId, setLastId]);

  return (
    <Modal className='modal-framac-doc' label={title}>
      <LSplit settings="frama-c.modal-doc.split">
        <SideBar>
          <SidebarTitle label='Table of contents' >
            <div className='dome-xTree-actions'>
              <IconButton
                icon={ "CHEVRON.CONTRACT" }
                title="Fold all"
                disabled={unfoldAll === false}
                size={14}
                onClick={() => setUnfoldAll(false)}
              />
              <IconButton
                icon={ "CHEVRON.EXPAND" }
                title="Unfold all"
                disabled={unfoldAll}
                size={14}
                onClick={() => setUnfoldAll(true)}
              />
            </div>
          </SidebarTitle>
          <Tree
            unfoldAll={unfoldAll}
            setUnfoldAll={setUnfoldAll}
            foldButtonPosition='right'
            selected={selectedId}
            onClick={(id) => setSelectedid(id) }
          >
            { index.map((tree, i) => <Nodes
                key={i}
                tree={tree}
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

export function showHelp(): void {
  if(!modal.getValue()) showModal(<GeneralDocModal/>);
  else closeModal();
}
