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
import { Icon } from 'dome/controls/icons';
import { SideBar } from 'dome/frame/sidebars';
import { Catch } from 'dome/errors';
import { classes } from 'dome/misc/utils';
import { SidebarProps } from 'ivette';
import type {
  SidebarPanelControl,
  SidebarSelectionState,
} from './sidebarControl';

/* -------------------------------------------------------------------------- */
/* --- Sidebar Classic Selector                                           --- */
/* -------------------------------------------------------------------------- */

interface SelectorProps extends SidebarProps {
  selectorSelected: SidebarSelectionState['selectorSelected'];
  setSelectorSelected: SidebarSelectionState['setSelectorSelected'];
  panelVisible: SidebarPanelControl['visible'];
  setPanelVisible: SidebarPanelControl['setVisible'];
}

function Selector(props: SelectorProps): JSX.Element {
  const {
    id,
    icon,
    panelVisible,
    selectorSelected,
    setSelectorSelected,
    setPanelVisible,
    label
  } = props;
  const className = classes(
    'sidebar-selector',
    'dome-color-frame',
    selectorSelected === id && 'sidebar-selector-selected',
  );
  const onClick = React.useCallback(() => {
    if (selectorSelected === id) {
      setPanelVisible(!panelVisible);
    } else {
      setSelectorSelected(id);
      setPanelVisible(true);
    }
  },
    [
      id,
      panelVisible,
      selectorSelected,
      setPanelVisible,
      setSelectorSelected,
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
/* --- Sidebar Toggle Selector                                            --- */
/* -------------------------------------------------------------------------- */

interface ToggleSelectorProps {
  panelVisible: SidebarPanelControl['visible'];
  setPanelVisible: SidebarPanelControl['setVisible'];
}

/**
   Dedicated selector-like control used to collapse or expand the sidebar
   panel without changing the currently selected sidebar selector.
 */
function ToggleSelector(props: ToggleSelectorProps): JSX.Element {
  const { panelVisible, setPanelVisible } = props;
  const className = classes(
    'sidebar-selector',
    'sidebar-selector-toggle',
    'dome-color-frame',
    panelVisible && 'sidebar-selector-selected',
  );
  const title = `${panelVisible ? 'Collapse' : 'Expand'} sidebar`;
  return (
    <div
      className={className}
      title={title}
      onClick={() => setPanelVisible(!panelVisible)}
    >
      <Icon size={20} className="sidebar-selector-icon" id="SIDEBAR" />
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sidebar Main Components                                            --- */
/* -------------------------------------------------------------------------- */

interface SelectorsProps extends SidebarSelectionState {
  panelVisible: SidebarPanelControl['visible'];
  setPanelVisible: SidebarPanelControl['setVisible'];
}

export function Selectors(props: SelectorsProps): JSX.Element {
  const {
    selectorSelected,
    setSelectorSelected,
    registeredSidebars,
    panelVisible,
    setPanelVisible,
  } = props;
  const selectors = registeredSidebars.map((sb) => (
    <Selector
      key={sb.id}
      panelVisible={panelVisible}
      setPanelVisible={setPanelVisible}
      selectorSelected={selectorSelected}
      setSelectorSelected={setSelectorSelected}
      {...sb} />
  ));
  const selectorsClasses = classes(
    registeredSidebars.length <= 1 && 'dome-erased',
  );

  return (
    <div className="sidebar-items dome-color-frame">
      <div className={selectorsClasses}>{selectors}</div>
      <ToggleSelector
        panelVisible={panelVisible}
        setPanelVisible={setPanelVisible}
      />
    </div>
  );
}

interface PanelsProps {
  selectorSelected: SidebarSelectionState['selectorSelected'];
  registeredSidebars: SidebarSelectionState['registeredSidebars'];
}

export function Panels(props: PanelsProps): JSX.Element {
  const { selectorSelected, registeredSidebars } = props;
  const sidebars = registeredSidebars.map((sb) => (
    <SideBar
      key={sb.id}
      className={selectorSelected === sb.id ? '' : 'dome-erased'}
    >
      <div className="sidebar-ruler" />
      <Catch label={sb.id}>
        {sb.children}
      </Catch>
    </SideBar>
  ));

  return <div className="sidebar-view">{sidebars}</div>;
}

// --------------------------------------------------------------------------
