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

import React from 'react';

import { Modal, showModal } from 'dome/dialogs';
import { alpha } from 'dome/data/compare';
import { LSplit } from 'dome/layout/splitters';
import { Hbox } from 'dome/layout/boxes';
import * as Toolbar from 'dome/frame/toolbars';

import * as Server from 'frama-c/server';
import * as Params from 'frama-c/kernel/api/parameters';

import { OptionsForms, SectionParams, useRemotes } from './forms';
import { OptionsSidebar } from './sidebar';
import './style.css';

// --------------------------------------------------------------------------
// --------------------------------------------------------------------------

export type SelectedPlugins = [string, string];
export type IsSetElement = Record<string, boolean>;

interface PContext {
  params: Record<string, SectionParams[]>;
  isSetElement: IsSetElement;
  addPluginsSet: (value: IsSetElement) => void;
}

interface PContextById extends Omit<PContext, 'params'> {
  params: SectionParams[];
}

const PLUGINSCONTEXT =
  React.createContext<PContext | undefined>(undefined);

export function usePluginsContextById(id: string): PContextById {
  const context = React.useContext(PLUGINSCONTEXT);
  if (!context) {
    throw new Error("usePluginsContext must be used in <Provider>");
  }
  const { params, isSetElement, addPluginsSet } = context;
  return { params: params[id], isSetElement, addPluginsSet };
}


// --------------------------------------------------------------------------
// --- Options
// --------------------------------------------------------------------------

export function OptionsHelp(): React.JSX.Element {
  return <Hbox className='framac-options-help'>
    <p>The form on the left is highlighted in red in the sidebar,
       and the one on the right is highlighted in blue.</p>
    <ul>
      <li>Ctrl + click to change the form on the right.</li>
      <li>Click to change the form on the left.</li>
    </ul>
  </Hbox>;
}

const defaultSelected: SelectedPlugins = ['kernel', 'Eva'];

export default function Options(): React.JSX.Element {
  /** Remotes */
  const remotesState = useRemotes();
  const [remotes,] = remotesState;

  /** Selected plugins */
  const selectedState = React.useState<SelectedPlugins>(defaultSelected);

  /** List of plugins */
  const [plugins, setPlugins] = React.useState<Params.plugin[]>([]);
  React.useEffect(() => {
    const fetchPlugins = async (): Promise<void> => {
      const plugins = await Server.send(Params.getPlugins, {});
      setPlugins(plugins.sort((a, b) => alpha(a.name, b.name)));
    };
    if(Server.isRunning()) fetchPlugins();
    else Server.onReady(fetchPlugins);
  }, []);

  /** List of plugins set, true if plugin contain field set by the user */
  const [isSetElement, setIsSetElement] = React.useState<IsSetElement>({});
  const addPluginsSet = React.useCallback((value: IsSetElement) => {
    setIsSetElement(prev => ({ ...prev, ...value })); }, [setIsSetElement]);

  /** Plugins parameters */
  const [params, setParams] =
    React.useState<Record<string, SectionParams[]>>({});
  React.useEffect(() => {
    const fetchParams = async (id: string): Promise<void> => {
      try {
        const params = await Server.send(Params.getPluginParameters, id);
        /** Initial check if field 'isSet' for sidebar items */
        if(params.find(plugin => plugin[1].find(param => param.isSet)))
          addPluginsSet({ [id]: true });
        const sortedParams = params.sort((a, b) => alpha(a[0], b[0]));
        setParams(v => ({ ...v, [id]: sortedParams }));
      } catch (err) {
        // eslint-disable-next-line no-console
        console.warn("Error :", id, err);
      }
    };
    plugins.map(p => fetchParams(p.name));
  }, [plugins, addPluginsSet]);

  return (<>
  { Object.keys(params).length === plugins.length
    && Object.keys(params).length > 0
    && <PLUGINSCONTEXT.Provider value={{ params, isSetElement, addPluginsSet }}>
      <div className='framac-options'>
        <LSplit settings="frama-c.options" unfold={true}>
          <OptionsSidebar
            selectedState={selectedState}
            plugins={plugins}
            remotes={remotes}
            isSetElement={isSetElement}
          />
          <OptionsForms
            plugins={plugins}
            selectedState={selectedState}
            remotesState={remotesState}
            />
        </LSplit>
      </div>
    </PLUGINSCONTEXT.Provider>
  }
  </>);
}

/* -------------------------------------------------------------------------- */
/* --- Frama-C Options Modal                                              --- */
/* -------------------------------------------------------------------------- */

export function showOptionsModal(): void {
  showModal(
    <Modal className='modal-framac-options' label='Frama-C options'>
      <Options/>
    </Modal>
  );
}

export function ButtonOptions(): React.JSX.Element {
  return <Toolbar.Button
    icon='SETTINGS'
    onClick={showOptionsModal}
    title='Open parameters'
  />
}
