/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Sidebar Selector
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import { Icon } from 'dome/controls/icons';
import { SideBar } from 'dome/frame/sidebars';
import { Catch } from 'dome/errors';
import { classes } from 'dome/misc/utils';
import { SidebarProps, SIDEBAR } from 'ivette';
import * as State from 'ivette/state';

/* -------------------------------------------------------------------------- */
/* --- SideBar Selector                                                   --- */
/* -------------------------------------------------------------------------- */

interface SelectorProps extends SidebarProps {
  selected: string;
  setSelected: (item: string) => void;
  sidebar: boolean;
  setSidebar: (sidebar: boolean) => void;
}

function Selector(props: SelectorProps): JSX.Element {
  const { id, icon, selected, setSelected, sidebar, setSidebar, label } = props;
  const className = classes(
    'sidebar-selector',
    'dome-color-frame',
    selected === id && 'sidebar-selector-selected',
  );
  const onClick = React.useCallback(() => {
    if (selected === id) {
      setSidebar(!sidebar);
    } else {
      setSelected(id);
      setSidebar(true);
    }
  }, [id, selected, setSelected, setSidebar, sidebar]);
  const title = props.title ?? `${label} Sidebar`;
  const component =
    icon
    ? <Icon size={20} className="sidebar-selector-icon" id={icon}/>
    : <label className="sidebar-selector-label">{label}</label>;
  return (
    <div className={className} title={title} onClick={onClick}>
      {component}
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* --- User Sidebar Wrapper                                               --- */
/* -------------------------------------------------------------------------- */

interface WrapperProps extends SidebarProps {
  selected: string;
}

function Wrapper(props: WrapperProps): JSX.Element {
  const className = props.selected === props.id ? '' : 'dome-erased';

  return (
    <SideBar className={className}>
      <div className="sidebar-ruler"/>
      <Catch label={props.id}>
        {props.children}
      </Catch>
    </SideBar>
  );
}

/* -------------------------------------------------------------------------- */
/* --- SideBar Main Component                                             --- */
/* -------------------------------------------------------------------------- */

interface Model {
  selected: string;
  setSelected: (item: string) => void;
  sidebars: SidebarProps[];
}

function useModel(): Model {
  const [selected, setSelected] =
    Dome.useStringSettings('ivette.sidebar.selected');

  const sidebars = State.useElements(SIDEBAR);
  const sortedSidebars = React.useMemo(() => {
      const newItems = [...sidebars].sort((a, b) => {
        const e1 = a.rank ?? 0;
        const e2 = b.rank ?? 0;
        return e1 - e2;
      });
      return newItems;
  }, [sidebars]);

  // Ensures there is one selected sidebar
  React.useEffect(() => {
    if (sortedSidebars.every((sb) => sb.id !== selected)) {
      const first = sortedSidebars[0];
      if (first) setSelected(first.id);
    }
  }, [sortedSidebars, selected, setSelected]);

  return { selected, setSelected, sidebars: sortedSidebars };
}

interface ButtonsProps {
  display?: boolean;
  sidebar: boolean;
  setSidebar: (sidebar: boolean) => void;
}

export function Buttons(props: ButtonsProps): JSX.Element {
  const { display = true, sidebar, setSidebar } = props;
  const { selected, setSelected, sidebars } = useModel();
  const items = sidebars.map((sb) => (
    <Selector
      key={sb.id}
      selected={selected}
      setSelected={setSelected}
      sidebar={sidebar}
      setSidebar={setSidebar}
      {...sb} />
  ));
  const selectorClasses = classes(
    'sidebar-items dome-color-frame',
    (sidebars.length <= 1 || !display) && 'dome-erased'
  );

  return <div className={selectorClasses}>{items}</div>;
}

export function Panel(): JSX.Element {
  const { selected, sidebars } = useModel();
  const wrappers = sidebars.map((sb) => (
    <Wrapper
      key={sb.id}
      selected={selected}
      {...sb}
    />
  ));

  return <div className="sidebar-view">{wrappers}</div>;
}

// --------------------------------------------------------------------------
