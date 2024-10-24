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

/**
  This package provide components to displayed a tree

  @packageDocumentation
  @module dome/frame/Tree
*/

import React from 'react';
import { classes } from 'dome/misc/utils';
import { Label, LabelProps } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Actions } from 'dome/layout/forms';

/**
 * Fold/unfold children in a tree, starting from the depth chosen
 *
 * @param tree The tree to be treated
 * @param from The depth where the folding/unfolding start
 * @param show false to fold, true to unfold
 * @param depth The current depth
 */
function foldUnfold(
  tree: ITree, from: number, show: boolean, depth: number = 0
): void {
  if(depth >= from) tree.showChildren = show;
  if(tree.subTree && tree.subTree.length > 0) {
    for(const subtree of tree.subTree) {
      foldUnfold(subtree, from, show, depth + 1);
    }
  }
}

/**
 * Unfold children in a tree, starting from the depth chosen
 *
 * @param tree The tree to be treated
 * @param from The depth where the folding start
 */
function unfold(tree: ITree, from: number): void {
  foldUnfold(tree, from, true);
}

/**
 * Fold children in a tree, starting from the depth chosen
 *
 * @param tree The tree to be treated
 * @param from The depth where the folding start
 */
function fold(tree: ITree, from: number): void {
  foldUnfold(tree, from, false);
}

/**
 * Apply the function in parameters to all tree chosen
 *
 * @param tree The tree to be treated
 * @param ids Array of tree id
 * @param f Function to be applied
 */
function modifyTreeIds(
  tree: ITree, ids: string[], f: (t: ITree) => void
): void {
  if(ids.includes(tree.id)) {
    f(tree);
    const index = ids.findIndex((id) => id === tree.id);
    ids.splice(index, 1);
  }
  if(ids.length === 0 ) return;
  if(tree.subTree && tree.subTree.length > 0) {
    for(const subtree of tree.subTree) {
      modifyTreeIds(subtree, ids, f);
    }
  }
}

/**
 * Reverse folding of chosen trees
 *
 * @param tree The tree to be treated
 * @param ids Array of tree id
 */
function flipFolding(tree: ITree, ids: string[]): void {
  const f = (t: ITree): void => {
    t.showChildren = !(t.showChildren !== false);
  };
  modifyTreeIds(tree, ids, f);
}

/**
 * Reverse the selection of chosen trees
 *
 * @param tree The tree to be treated
 * @param ids Array of tree id
 */
function flipSelectNodes(tree: ITree, ids: string[]): void {
  const f = (t: ITree): void => { t.selected = !t.selected; };
  modifyTreeIds(tree, ids, f);
}

/* --------------------------------------------------------------------------*/
/* --- Hook Tree                                                             */
/* --------------------------------------------------------------------------*/
export interface IUseTree {
  tree: ITree,
  unfoldAll: (top?: number) => void,
  foldAll: (top?: number) => void,
  flipFoldingOne: (id: string) => void
  flipSelect: (id: string) => void
  updateTree: () => void,
  setTree: (t: ITree) => void
}

export function useTree(tree: ITree): IUseTree {
  const [ , setUpdateTree ] = React.useState(false);
  const [ internalTree, setInternalTree] = React.useState(tree);

  function updateTree(): void { setUpdateTree((v) => !v); }

  function unfoldAll(top: number = 0): void {
    unfold(internalTree, top);
    updateTree();
  }

  function foldAll(top: number = 0): void {
    fold(internalTree, top);
    updateTree();
  }

  function flipFoldingOne(id: string): void {
    flipFolding(internalTree, [id]);
    updateTree();
  }

  function flipSelect(id: string): void {
    flipSelectNodes(internalTree, [id]);
    updateTree();
  }

  return {
    tree: internalTree,
    unfoldAll: unfoldAll,
    foldAll: foldAll,
    flipFoldingOne: flipFoldingOne,
    flipSelect: flipSelect,
    updateTree: updateTree,
    setTree: setInternalTree
  };
}

/* --------------------------------------------------------------------------*/
/* --- Tree                                                                  */
/* --------------------------------------------------------------------------*/
export type TFoldIconPosition = 'left' | 'right';

export interface ITree extends LabelProps {
  id: string;
  selected?: boolean;
  selectedChildren?: boolean;
  subTree?: ITree[];
  showChildren?: boolean;
}

interface ElementProps {
  tree: ITree,
  flipFoldingOne: (id: string) => void,
  foldAll: (top?: number) => void,
  unfoldAll: (top?: number) => void,
  onChildHeightChange?: (v: number) => void,
  getActions?: (tree: ITree) => JSX.Element,
  onClick?: (tree: ITree) => void,
  depth?: number,
  options?: ITreeOptions;
  firstId?: string;
}

function TreeNode(props: ElementProps): JSX.Element {
  const { tree, options, depth = 0, firstId,
    flipFoldingOne, foldAll, unfoldAll, getActions,
    onChildHeightChange, onClick } = props;
  const { addActionsOnRoot = false } = options || {};
  const [ isOpen, setIsOpen ] = React.useState(
    tree.id === firstId || tree.showChildren !== false
  );

  React.useEffect(() => {
    setIsOpen(tree.showChildren !== false);
  }, [tree.showChildren]);

  const className = classes(
    'dome-xTree-node',
    isOpen ? 'dome-xTree-show-children':'dome-xTree-hide-children',
    tree?.subTree && tree.subTree.length > 0 && "dome-xTree-has-subtree",
  );

  /** ************************************************************ */
  /** Animation */
  const [maxHeight, setMaxHeight] = React.useState(0);
  const [oldMaxHeight, setOldMaxHeight] = React.useState(maxHeight);
  const listRef = React.useRef<HTMLUListElement | null>(null);

  const updateParentMaxHeight = (v: number): void => {
    setOldMaxHeight(maxHeight);
    setMaxHeight((h) => h + v);
  };

  /** calculate max height when folding/unfolding */
  React.useEffect(() => {
    if (listRef.current) {
      const newHeight = isOpen ? listRef.current.scrollHeight : 0;
      setMaxHeight(newHeight);
    }
  }, [isOpen, tree]);

  /** calculte parent if max height changed */
  React.useEffect(() => {
    if (onChildHeightChange) {
      onChildHeightChange(maxHeight - oldMaxHeight);
    }
  }, [maxHeight, oldMaxHeight, onChildHeightChange]);
  /** ************************************************************ */

  const foldIconPosition: TFoldIconPosition = React.useMemo(() => {
    return options?.foldingButtonPosition || 'left';
  }, [options?.foldingButtonPosition]);

  const foldIcon = ( tree.id === firstId ?
    ( tree.subTree && tree.subTree.length > 0 &&
      <>
        <IconButton
            icon={ "CHEVRON.EXPAND" }
            size={14}
            onClick={() => unfoldAll()}
        />
        <IconButton
            icon={ "CHEVRON.CONTRACT" }
            size={14}
            onClick={() => foldAll(1)}
        />
      </>
    ):
    <IconButton
      className='dome-xTree-folding-button'
      style={(tree.subTree && tree.subTree.length > 0) ?
        { visibility: 'visible' } :
        { visibility: 'hidden' }
      }
      icon={ "ANGLE.DOWN" }
      onClick={() => flipFoldingOne(tree.id) }
    />
  );

  const isActions = getActions && ((depth > 0 || addActionsOnRoot ));

  return (
    <li className={className} >
      <div onClick={() => { onClick && onClick(tree); }}>
        <div>
          { foldIconPosition === 'left' && foldIcon }
          <Label {...tree}/>
        </div>
        { (isActions || foldIconPosition === 'right') &&
          <Actions>
            { isActions && getActions(tree) }
            { foldIconPosition === 'right' && foldIcon }
          </Actions>
        }
      </div>
      { tree.subTree && tree.subTree.length > 0 &&
        <ul
          ref={listRef}
          style={{ maxHeight: maxHeight+"px" }}
        >
          { tree.subTree.map((elt) => <TreeNode
            key={elt.id}
            tree={elt}
            flipFoldingOne={flipFoldingOne}
            foldAll={foldAll}
            unfoldAll={unfoldAll}
            getActions={getActions}
            onClick={onClick}
            options={options}
            onChildHeightChange={updateParentMaxHeight}
            depth={depth + 1}
          />
        )}
        </ul>
      }
    </li>
  );
}

interface ITreeOptions {
  /** default: left */
  foldingButtonPosition?: TFoldIconPosition;
  /** default: false */
  addActionsOnRoot?: boolean;
}

interface ITreeProps {
  uTree:  IUseTree;
  /** Additional class. */
  className?: string;
  /** Defaults to `true`. */
  visible?: boolean;
  /** Defaults to `true`. */
  display?: boolean;
  /** options */
  options?: ITreeOptions;
  /** Actions */
  getActions?: (tree: ITree) => JSX.Element;
  /** onClick */
  onClick?: (tree: ITree) => void,
}

export function Tree(props: ITreeProps): JSX.Element {
  const { uTree, getActions, onClick, options,
    visible = true, display = true, className } = props;

  const classNames = classes(
    'dome-xTree',
    visible ? 'dome-xTree-open' : 'dome-xTree-close',
    !display && 'dome-control-erased',
    className,
  );


  return (
    <div className={classNames}>
      <ul>
        <TreeNode
          key={uTree.tree.id}
          tree={uTree.tree}
          flipFoldingOne={uTree.flipFoldingOne}
          foldAll={uTree.foldAll}
          unfoldAll={uTree.unfoldAll}
          options={options}
          getActions={getActions}
          onClick={onClick}
          firstId={uTree.tree.id}
          />
        </ul>
    </div>
  );
}
