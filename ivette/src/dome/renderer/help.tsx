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
import { Button, ButtonGroup } from './frame/toolbars';

/* --------------------------------------------------------------------------*/
/* --- Help                                                                  */
/* --------------------------------------------------------------------------*/

export const docHistory = new GlobalState<string[]>(['']);
const posHistory = new GlobalState(0);

interface HelpButtonProps {
  /** id */
  id: string;
  /** icon size */
  size?: number;
}

export function HelpButton(props: HelpButtonProps): JSX.Element {
  const { id, size } = props;
  const history = useHelpHistory();

  return (
    <IconButton
      icon='HELP'
      size={size}
      className='dome-xDoc-icon'
      title={'Help'}
      onClick={() => {
          history.addElement(id);
          showModal(<GeneralDocModal />);
        }
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

interface History {
  current: string;
  addElement: (id: string) => void;
  previous: () => void;
  next: () => void;
  isFirstpos: () => boolean;
  isLastpos: () => boolean;
}

function useHelpHistory(): History {
  const [ history, setHistory ] = useGlobalState(docHistory);
  const [ position, setPosition ] = useGlobalState(posHistory);
  const current = React.useMemo(() => history[position], [history, position]);

  function addElement(id: string): void {
    if (id === current) return;
    const newHistory = history.toSpliced(position+1);
    if(newHistory.push(id) > 20) newHistory.shift();
    setHistory(newHistory);
    setPosition(newHistory.length-1);
  }
  function previous(): void {
    setPosition(position > 0 ? position-1 : 0 );
  }
  function next(): void {
    setPosition(position < history.length-1 ? position+1 : position );
  }
  function isFirstpos(): boolean { return position === 0; }
  function isLastpos(): boolean { return position === history.length-1; }

  return {
    current: current,
    addElement: addElement,
    previous: previous,
    next: next,
    isFirstpos: isFirstpos,
    isLastpos: isLastpos
  };
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
function GeneralDocModal(): JSX.Element {
  const [ unfoldAll, setUnfoldAll ] = React.useState<boolean|undefined>(true);
  const history = useHelpHistory();
  const selectedId = React.useMemo(() => history.current, [history]);

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

  const actionsHeader = <ButtonGroup>
    <Button icon='ANGLE.LEFT'
      disabled={history.isFirstpos()}
      onClick={ history.previous } />
    <Button icon='ANGLE.RIGHT'
      disabled={history.isLastpos()}
      onClick={ history.next } />
  </ButtonGroup>;

  return (
    <Modal className='modal-framac-doc' label={title} actions={actionsHeader}>
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
            selected={selectedId}
            onClick={(id) => history.addElement(id) }
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
