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
  SidebarPanelVisibility,
  SidebarSelectionState,
} from './sidebarControl';

/* -------------------------------------------------------------------------- */
/* --- Sidebar Classic Selector                                           --- */
/* -------------------------------------------------------------------------- */

interface SelectorProps extends SidebarProps {
  selectorSelected: SidebarSelectionState['selectorSelected'];
  setSelectorSelected: SidebarSelectionState['setSelectorSelected'];
  sidebarPanel: SidebarPanelVisibility;
}

function Selector(props: SelectorProps): JSX.Element {
  const {
    id,
    icon,
    selectorSelected,
    setSelectorSelected,
    sidebarPanel,
    label
  } = props;
  const { visible, setVisible } = sidebarPanel;
  const className = classes(
    'sidebar-selector',
    'dome-color-frame',
    selectorSelected === id && 'sidebar-selector-selected',
  );
  const onClick = React.useCallback(() => {
    if (selectorSelected === id) {
      setVisible(!visible);
    } else {
      setSelectorSelected(id);
      setVisible(true);
    }
  },
    [
      id,
      selectorSelected,
      setVisible,
      setSelectorSelected,
      visible,
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

/**
   Dedicated selector-like control used to collapse or expand the sidebar
   panel without changing the currently selected sidebar selector.
 */
function ToggleSelector(props: SidebarPanelVisibility): JSX.Element {
  const { visible, setVisible } = props;
  const className = classes(
    'sidebar-selector',
    'sidebar-selector-toggle',
    'dome-color-frame',
    visible && 'sidebar-selector-selected',
  );
  const title = `${visible ? 'Collapse' : 'Expand'} sidebar`;
  return (
    <div
      className={className}
      title={title}
      onClick={() => setVisible(!visible)}
    >
      <Icon size={20} className="sidebar-selector-icon" id="SIDEBAR" />
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sidebar Main Components                                            --- */
/* -------------------------------------------------------------------------- */

interface SelectorsProps {
  sidebarSelection: SidebarSelectionState;
  sidebarPanel: SidebarPanelVisibility;
}

export function Selectors(props: SelectorsProps): JSX.Element {
  const { sidebarSelection, sidebarPanel } = props;
  const selectors = sidebarSelection.registeredSidebars.map((sb) => (
    <Selector
      key={sb.id}
      sidebarPanel={sidebarPanel}
      selectorSelected={sidebarSelection.selectorSelected}
      setSelectorSelected={sidebarSelection.setSelectorSelected}
      {...sb} />
  ));
  const selectorsClasses = classes(
    sidebarSelection.registeredSidebars.length <= 1 && 'dome-erased',
  );

  return (
    <div className="sidebar-items dome-color-frame">
      <div className={selectorsClasses}>{selectors}</div>
      <ToggleSelector
        visible={sidebarPanel.visible}
        setVisible={sidebarPanel.setVisible}
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
