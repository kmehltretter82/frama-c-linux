/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Sidebar Panel Control
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import { SidebarProps, SIDEBAR } from 'ivette';
import * as State from 'ivette/state';

const DEFAULT_SIDEBAR_PANEL_WIDTH = 320;

/**
   Shared sidebar selection state used by selector and panel renderers.
 */
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

  return {
    selectorSelected,
    setSelectorSelected,
    registeredSidebars: sortedSidebars,
  };
}

/**
   Shared open/closed control for the sidebar panel.
 */
export interface SidebarPanelVisibilityControl {
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

/**
   Full control interface for the sidebar panel.

   It extends the visibility-only interface with splitter-specific state:
   - `position` is the effective width given to a splitter,`,
   - `setPosition` is called by the splitter while dragging.

   Together with `visible` and `setVisible`, this gives a single control object
   that can be shared between layout code and sidebar components.
 */
export interface SidebarPanelControl extends SidebarPanelVisibilityControl {
  position: number;
  setPosition: (width: number) => void;
}

/**
   Hook used by the application to control the sidebar panel.

   The width setting is given as the last open width: when the panel is
   collapsed we keep the width value unchanged, so reopening restores the
   previous size instead of falling back to a hard-coded width each time.
 */
export function useSidebarControl(): SidebarPanelControl {
  const [sidebarPanelVisible, setSidebarPanelVisible] =
    Dome.useBoolSettings('frama-c.sidebar.unfold', true);
  const [sidebarPanelWidth, setSidebarPanelWidth] =
    Dome.useNumberSettings(
      'frama-c.sidebar.panel.width',
      DEFAULT_SIDEBAR_PANEL_WIDTH,
    );
  const lastOpenWidth =
    sidebarPanelWidth > 0 ? sidebarPanelWidth : DEFAULT_SIDEBAR_PANEL_WIDTH;

  const setVisible = (visible: boolean): void => {
    if (visible) {
      // Restore the last open width before showing the panel again.
      setSidebarPanelWidth(lastOpenWidth);
      setSidebarPanelVisible(true);
    } else {
      setSidebarPanelVisible(false);
    }
  };

  const setPosition = (width: number): void => {
    if (width <= 0) {
      // Dragging to zero collapses the panel but keeps the saved open width.
      setSidebarPanelVisible(false);
      return;
    }
    setSidebarPanelWidth(width);
    setSidebarPanelVisible(true);
  };

  return {
    // A collapsed panel is represented as a zero-sized foldable pane.
    position: sidebarPanelVisible ? lastOpenWidth : 0,
    visible: sidebarPanelVisible,
    setPosition,
    setVisible,
  };
}

// --------------------------------------------------------------------------
