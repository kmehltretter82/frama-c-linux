/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
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
import { Markdown, Pattern } from './text/markdown';
import { SideBar, SidebarTitle } from './frame/sidebars';
import { Tree, Node } from './frame/tree';
import { LSplit } from './layout/splitters';

import { Icon } from './controls/icons';
import { LED } from './controls/displays';
import { Button, ButtonGroup } from './frame/toolbars';

/* --------------------------------------------------------------------------*/
/* --- Help                                                                  */
/* --------------------------------------------------------------------------*/

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

/* --------------------------------------------------------------------------*/
/* --- General doc                                                           */
/* --------------------------------------------------------------------------*/

export const docChapters = new GlobalState<ChapterProps[]>([]);
export const docHistory = new GlobalState<string[]>(['']);
const posHistory = new GlobalState(0);

export interface ChapterProps {
  id: string;
  content: string;
  rank?: number;
  patterns?: Pattern[];
}

interface Index {
  id: string;
  label: string;
  level: number;
  errors: string[];
}

type IndexTab = [chapterId: string, indexes: Index[]];

interface HNode {
  id: string;
  label: string;
  errors?: string[];
  subTree: HNode[];
}

type HTree = HNode[];

/* --------------------------------------------------------------------------*/
/* --- Check errors                                                          */
/* --------------------------------------------------------------------------*/

// Check title list
function checkTitles(chapterId: string, titles: Index[]): string[] {
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
    if(id.split('-')[0] !== chapterId) badStartingIds.push(id);
  });
  // Add errors
  if(h1Error) errors.push(
    'The chapter must have one H1 and it must be placed at the beginning\n');
  if(duplicateIds.length > 0) {
    errors.push('Duplicate Ids are removed from table of content:');
    duplicateIds.forEach(id => errors.push(`- ${id}`));
  }
  if(badStartingIds.length > 0) {
    errors.push(`Id must start with "${chapterId}":`);
    badStartingIds.forEach(id => errors.push(`- ${id}`));
  }

  indexToDelete.forEach(i => titles.splice(i, 1));
  return errors;
}

function checkLinks(chapter: ChapterProps, indexes: IndexTab[]): string[] {
  const errors: string[] = [];
  const linkRegex = /\[(.*?)\]\(#([^\s)]+)\)/gm;
  let matches;
  while ((matches = linkRegex.exec(chapter.content)) !== null) {
    const id = matches[2];
    if(!indexes.find(elt => elt[1].find(title => title.id === id)))
      errors.push(id);
  }

  if(errors.length > 0) { errors.unshift('Errors in following links:'); }
  return errors;
}

function getErrors(chapters: ChapterProps[], indexes: IndexTab[]): IndexTab[] {
  const news = indexes.slice();
  news.forEach(([ chapterId, chapterIndexes ]) => {
    // check titles
    const titlesErrors = checkTitles(chapterId, chapterIndexes);
    if(titlesErrors.length > 0) {
      chapterIndexes[0].errors = chapterIndexes[0].errors.concat(titlesErrors);
    }
    // check links
    const chapter = chapters.find(elt => elt.id === chapterId);
    if(chapter) {
      const linkErrors = checkLinks(chapter, indexes);
      if(linkErrors.length > 0) {
        chapterIndexes[0].errors = chapterIndexes[0].errors.concat(linkErrors);
      }
    }
  });
  return news;
}

/* --------------------------------------------------------------------------*/
/* --- Table of content                                                      */
/* --------------------------------------------------------------------------*/

export function getIndexes(chapters: ChapterProps[]): IndexTab[] {
  const regex = /^(#{1,6})\s(.+)\s((\{#([\w-]+)\})|(\|\|#([\w-]+)\|\|))/gm;
  // Retrieving H1, H2, H3, H4 titles with an id
  let matches;
  const titles: [string, Index[]][] = [];
  chapters.forEach(chapter => {
    const tmp = [];
    while ((matches = regex.exec(chapter.content)) !== null) {
      const level = matches[1].length;
      const label = matches[2];
      const id = matches[5] || matches[7];
      tmp.push({ level, label, id, errors: [] });
    }
    if(tmp.length > 0) titles.push([chapter.id, tmp]);
  });
  return titles;
}

function getTableOfContents(indexes: IndexTab[]): HTree[] {
  let i = 0;
  const tree: HTree[] = [];

  function toTree(titles: Index[]): HTree {
    const t: HTree = [];
    while(i < titles.length && titles[i].level < 5) {
      const elt = titles[i];
      const newNode: HNode = {
        id: elt.id, label: elt.label, subTree: []
      };
      if(elt.level === 1) newNode.errors = elt.errors;
      t.push(newNode);
      if(i+1 < titles.length) {
        const nextLevel = titles[i+1].level;
        if(nextLevel > elt.level) {
          i++;
          newNode.subTree = toTree(titles);
        } else if(nextLevel < elt.level) break;
      }
      i++;
    }
    return t;
  }

  indexes.forEach(([, index]) => {
    i = 0;
    tree.push(toTree(index));
  });

  return tree;
}

/* --------------------------------------------------------------------------*/
/* --- Nodes                                                                 */
/* --------------------------------------------------------------------------*/

function getSubTree(tree: HTree): React.ReactNode {
  return tree.length > 0 ? <Nodes tree={tree} /> : null;
}

function Nodes(props: { tree: HTree, path?: string }): React.ReactNode {
  return props.tree.map(({ id, label, errors, subTree }) => {
    const actions = errors && errors.length > 0 ? (
      <>
        <LED status="negative" blink={true} />
        <Icon id='WARNING' kind="negative" title={errors.join('\n')}></Icon>
        <LED status="negative" blink={true} />
      </>) :
      undefined;
    const path = props.path ? props.path+" - "+label : label;
    return <Node key={id} id={id} label={label} title={path} actions={actions}
      >{ getSubTree(subTree) }</Node>;
  }
  );
}

/* --------------------------------------------------------------------------*/
/* --- History                                                               */
/* --------------------------------------------------------------------------*/

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
  * # <title> <{#<id>} | ||#<id>||> with alphanumeric <id> .
  * Each *.md file can then declare H2, H3 or H4 keys with
  * #+ <title> <{#<id>-<subid>} | ||#<id>-<subid>||> with alphanumeric <subid>
  * which can optionally be compounded with - (unrelated to depth level).
*/
function GeneralDocModal(): JSX.Element {
  const [ chapters, ] = useGlobalState(docChapters);

  const [ unfoldAll, setUnfoldAll ] = React.useState<boolean|undefined>(true);
  const history = useHelpHistory();
  const selectedId = React.useMemo(() => history.current, [history]);

  const indexes = React.useMemo(() => {
    const news = getIndexes(chapters.sort((a, b) => {
      const A = a.rank ?? 50;
      const B = b.rank ?? 50;
      return A - B;
    }));
    return getErrors(chapters, news);
  }, [chapters]);

  const tableOfContent = React.useMemo(() => {
    return getTableOfContents(indexes);
  }, [indexes]);

  const currentDoc = React.useMemo(() => {
    const docId = selectedId.split('-')[0];
    return chapters.find(elt => elt.id === docId);
  }, [selectedId, chapters]);

  const title = React.useMemo(() => {
    const ids = selectedId.split('-');
    const chapter = ids[0].charAt(0).toUpperCase() + ids[0].slice(1);
    const section = ids.slice(1).join(' ');
    return `Documentation ${chapter} ${section ? "- "+section: ""}`;
  }, [selectedId]);

  function onLinkClick(id: string): void { history.addElement(id); }
  function checkLink(id: string): boolean {
    return Boolean(indexes.find(elt => elt[1].find(title => title.id === id)));
  }

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
      <LSplit settings="frama-c.modal-doc.split"
        defaultPosition={250}
      >
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
            { tableOfContent.map((tree, i) => <Nodes
                key={i}
                tree={tree}
              ></Nodes> ) }
          </Tree>
        </SideBar>
        <Markdown
          patterns={currentDoc?.patterns}
          scrollTo={selectedId}
          onLinkClick={onLinkClick}
          checkLink={checkLink}
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
