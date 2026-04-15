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
  selectedSidebarId: string;
  setSelectedSidebarId: (item: string) => void;
  panelVisible: boolean;
  setPanelVisible: (visible: boolean) => void;
}

function Selector(props: SelectorProps): JSX.Element {
  const {
    id,
    icon,
    panelVisible,
    selectedSidebarId,
    setSelectedSidebarId,
    setPanelVisible,
    label
  } = props;
  const className = classes(
    'sidebar-selector',
    'dome-color-frame',
    selectedSidebarId === id && 'sidebar-selector-selected',
  );
  const onClick = React.useCallback(() => {
    if (selectedSidebarId === id) {
      setPanelVisible(!panelVisible);
    } else {
      setSelectedSidebarId(id);
      setPanelVisible(true);
    }
  },
    [
      id,
      panelVisible,
      selectedSidebarId,
      setPanelVisible,
      setSelectedSidebarId,
    ]);
  const title = props.title ?? `${label} Sidebar`;
  const component =
    icon
      ? <Icon size={20} className="sidebar-selector-icon" id={icon} />
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
      <div className="sidebar-ruler" />
      <Catch label={props.id}>
        {props.children}
      </Catch>
    </SideBar>
  );
}

/* -------------------------------------------------------------------------- */
/* --- SideBar Main Components                                            --- */
/* -------------------------------------------------------------------------- */

interface SidebarState {
  selectedSidebarId: string;
  setSelectedSidebarId: (id: string) => void;
  registeredSidebars: SidebarProps[];
}

function useSidebarState(): SidebarState {
  const [selectedSidebarId, setSelectedSidebarId] =
    Dome.useStringSettings('ivette.sidebar.selected');

  const registeredSidebars = State.useElements(SIDEBAR);
  const sortedSidebars = React.useMemo(() => {
    const newItems = [...registeredSidebars].sort((a, b) => {
      const e1 = a.rank ?? 0;
      const e2 = b.rank ?? 0;
      return e1 - e2;
    });
    return newItems;
  }, [registeredSidebars]);

  // Ensures there is one selected sidebar
  React.useEffect(() => {
    if (sortedSidebars.every((sb) => sb.id !== selectedSidebarId)) {
      const first = sortedSidebars[0];
      if (first) setSelectedSidebarId(first.id);
    }
  }, [sortedSidebars, selectedSidebarId, setSelectedSidebarId]);

  return {
    selectedSidebarId,
    setSelectedSidebarId,
    registeredSidebars: sortedSidebars,
  };
}

interface SelectorsProps {
  sidebarVisible?: boolean;
  panelVisible: boolean;
  setPanelVisible: (visible: boolean) => void;
}

export function Selectors(props: SelectorsProps): JSX.Element {
  const { sidebarVisible = true, panelVisible, setPanelVisible } = props;
  const {
    selectedSidebarId,
    setSelectedSidebarId,
    registeredSidebars,
  } = useSidebarState();
  const selectors = registeredSidebars.map((sb) => (
    <Selector
      key={sb.id}
      panelVisible={panelVisible}
      setPanelVisible={setPanelVisible}
      selectedSidebarId={selectedSidebarId}
      setSelectedSidebarId={setSelectedSidebarId}
      {...sb} />
  ));
  const selectorClasses = classes(
    'sidebar-items dome-color-frame',
    (registeredSidebars.length <= 1 || !sidebarVisible) && 'dome-erased',
  );

  return <div className={selectorClasses}>{selectors}</div>;
}

export function Panels(): JSX.Element {
  const { selectedSidebarId, registeredSidebars } = useSidebarState();
  const wrappers = registeredSidebars.map((sb) => (
    <Wrapper
      key={sb.id}
      selected={selectedSidebarId}
      {...sb}
    />
  ));

  return <div className="sidebar-view">{wrappers}</div>;
}

// --------------------------------------------------------------------------
