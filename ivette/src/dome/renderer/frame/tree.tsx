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
  This package provide components to displayed a tree

  @packageDocumentation
  @module dome/frame/Tree
*/

import React from 'react';
import { classes, styles } from 'dome/misc/utils';
import { Label } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Actions } from 'dome/layout/forms';

/* --------------------------------------------------------------------------*/
/* --- Tree                                                                  */
/* --------------------------------------------------------------------------*/

export type FoldIconPosition = 'left' | 'right';

type TreeContext = { depth: number; } & Omit<TreeProps, "children">;

const CONTEXT_DEFAULT: TreeContext = {
  foldButtonPosition: 'left',
  depth: 0,
};
const CONTEXT = React.createContext<TreeContext>(CONTEXT_DEFAULT);

function useContext(props: Partial<TreeContext>): TreeContext {
  const Parent = React.useContext(CONTEXT);
  return {
    unfoldAll: props.unfoldAll,
    setUnfoldAll: props.setUnfoldAll,
    foldButtonPosition: props.foldButtonPosition || Parent.foldButtonPosition,
    selected: props.selected || Parent.selected,
    depth: props.depth || Parent.depth,
    onClick: props.onClick,
  };
}

interface TreeProps {
  unfoldAll?: boolean ; /* default false */
  setUnfoldAll?: (v: boolean|undefined) => void;
  foldButtonPosition?: FoldIconPosition;
  selected?: string;
  onClick?: (id: string) => void;
  children?: React.ReactNode ; /* only nodes */
}

export function Tree(props: TreeProps): JSX.Element {
  const {
      unfoldAll, setUnfoldAll, foldButtonPosition,
      selected, onClick
    } = props;

  const context = useContext({
    unfoldAll: unfoldAll,
    setUnfoldAll: setUnfoldAll,
    onClick: onClick,
    foldButtonPosition: foldButtonPosition,
    selected,
  });

  return (
    <CONTEXT.Provider value={context}>
      <div className={'dome-xTree'}>
        <div className='dome-xTree-nodes'>
          { props.children }
        </div>
      </div>
    </CONTEXT.Provider>
  );
}

export interface NodeProps {
  id: string;
  icon?: string;
  label?: string;
  title?: string;
  actions?: React.ReactNode;
  children?: React.ReactNode;
}

export function Node(props: NodeProps): JSX.Element {
  const { id, icon, label, title, actions, children } = props;

  const context = React.useContext(CONTEXT);
  const countChildren = React.Children.count(children);

  const [ unfold, setUnfold ] = React.useState(
    context.unfoldAll !== undefined ? context.unfoldAll : false);
  const flipUnfold = (): void => {
    setUnfold(v => !v);
    if (context.setUnfoldAll !== undefined) context.setUnfoldAll(undefined);
  };

  React.useEffect(() => {
    if(context.unfoldAll !== undefined) setUnfold(context.unfoldAll);
  }, [context.unfoldAll]);

  const className = classes(
    'dome-xTree-node',
    countChildren > 0 ? "dome-xTree-has-subtree" : "",
    unfold ? 'dome-xTree-show-children' : 'dome-xTree-hide-children',
    context.selected === id && 'dome-xTree-selected'
  );
  const classSubtree = classes(
    'dome-xTree-subtree',
    unfold ? 'dome-xTree-subtree-visible' : 'dome-xTree-subtree-hidden'
  );
  const style = styles(context.depth > 0 && { marginLeft: `10px` });

  /** ************************************************************ */

  const foldIconPosition = context?.foldButtonPosition || 'left';
  const foldIcon = <IconButton
      className='dome-xTree-folding-button'
      style={{ visibility: countChildren > 0 ? 'visible' : 'hidden' }}
      icon={ "ANGLE.DOWN" }
      onClick={() => flipUnfold()}
    />;

  return (
    <CONTEXT.Provider value={{ ...context, depth: context.depth+1 }}>
      <div className={className} style={style}
        onClick={() => context.onClick && context.onClick(id) }
      >
          <div>
            { foldIconPosition === 'left' && foldIcon }
            <Label icon={icon} title={title}
              label={label}
            ></Label>
          </div>
          { (actions || foldIconPosition === 'right') &&
            <Actions>
              { actions && actions }
              { foldIconPosition === 'right' && foldIcon }
            </Actions>
          }
      </div>
      { countChildren > 0 &&
        <div className={classSubtree} style={style}>
          { children }
        </div>
      }
    </CONTEXT.Provider>
  );
}
