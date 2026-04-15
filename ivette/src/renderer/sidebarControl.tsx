/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';
import * as Dome from 'dome';
import { SidebarProps, SIDEBAR } from 'ivette';
import * as State from 'ivette/state';

export const DEFAULT_SIDEBAR_PANEL_WIDTH = 320;

/* -------------------------------------------------------------------------- */
/* --- Sidebar Selection State                                            --- */
/* -------------------------------------------------------------------------- */

export interface SidebarSelectionState {
  selectorSelected: string;
  setSelectorSelected: (selector: string) => void;
  registeredSidebars: SidebarProps[];
}

/**
   Hook responsible for the currently selected sidebar and the list
   of registered sidebars, sorted by rank.
 */
export function useSidebarSelectionState(): SidebarSelectionState {
  const [selectorSelected, setSelectorSelected] =
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

  // Ensure the selected sidebar always refers to a currently registered one.
  React.useEffect(() => {
    if (sortedSidebars.every((sb) => sb.id !== selectorSelected)) {
      const first = sortedSidebars[0];
      if (first) setSelectorSelected(first.id);
    }
  }, [sortedSidebars, selectorSelected, setSelectorSelected]);

  return React.useMemo(
    () => ({
      selectorSelected,
      setSelectorSelected,
      registeredSidebars: sortedSidebars,
    }),
    [selectorSelected, setSelectorSelected, sortedSidebars],);
}

/* -------------------------------------------------------------------------- */
/* --- Sidebar Panel Control                                              --- */
/* -------------------------------------------------------------------------- */

export interface SidebarPanelVisibility {
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

/**
   Hook to control whether the sidebar panel is visible.
 */
export function useSidebarControl(): SidebarPanelVisibility {
  const [sidebarVisible, setSidebarVisible] =
    Dome.useBoolSettings('frama-c.sidebar.unfold', true);

  return React.useMemo(
    () => ({
      visible: sidebarVisible,
      setVisible: setSidebarVisible,
    }),
    [sidebarVisible, setSidebarVisible],
  );
}

// --------------------------------------------------------------------------
