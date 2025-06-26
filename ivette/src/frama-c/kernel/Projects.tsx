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

import * as Dome from 'dome';
import { alpha } from 'dome/data/compare';
import { Item, SidebarTitle } from 'dome/frame/sidebars';
import { Button, IconButton } from 'dome/controls/buttons';
import { Hbox } from 'dome/layout/boxes';
import { useModel } from 'dome/table/models';
import * as Dialogs from 'dome/dialogs';
import { FieldState, TextField, useState } from 'dome/layout/forms';
import { Icon } from 'dome/controls/icons';

import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import { addProjectSubMenu } from 'frama-c/menu';
import * as Project from './api/project';


// --------------------------------------------------------------------------
// --- Projects
// --------------------------------------------------------------------------
interface ProjectFieldProps {
  project?: string,
  fieldName?: string,
  placeholder?: string,
  onValidate: (name: string) => void
}

function ProjectField(props: ProjectFieldProps): React.JSX.Element {
  const {
    project = '', fieldName, placeholder = 'New name', onValidate
  } = props;
  const state = useState(project);

  const onKeyDown = (e: React.KeyboardEvent<HTMLInputElement>): void => {
    if (e.key === 'Enter') {
      e.preventDefault();
      onValidate(state.value);
    }
  };

  return <div className='project-field' >
    <TextField
      label={fieldName || ''}
      placeholder={placeholder}
      state={state as FieldState<string | undefined>}
      latency={0}
      autoFocus={true}
      onKeyDown={onKeyDown}
    />
    <Button
      label='Ok'
      focusable={false}
      onClick={() => onValidate(state.value)}
    />
  </div>;
}

function showError(title: string, error: string): void {
  Dialogs.showModal(<Dialogs.Modal label={title}>
    <div className='project-error'>
      <Icon id='WARNING' kind='warning' size={18}/>
      {error}
    </div>
  </Dialogs.Modal>);
}

function showModalProject(
  title: string,
  onValidate: (v: string) => void,
  project?: string
): void {
  Dialogs.showModal(<Dialogs.Modal label={title}>
    <ProjectField project={project || ''} onValidate={onValidate} />
  </Dialogs.Modal>);
}

/** Create a new project */
export function newProject(): void {
  const onValidate = (name: string): void => {
    Server.send(Project.create, name).then(() => Dialogs.closeModal());
  };
  showModalProject('Create project', onValidate);
}

/** Rename a project */
export function renameProject(
  id: string, title: string, project?: string
): void {
  const onValidate = (name: string): void => {
    Server.send(Project.rename, [id, name]).then((error) => {
      if(!error) Dialogs.closeModal();
      else showError('Error while renaming project', error);
    });
  };
  showModalProject(title, onValidate, project);
}

/** Remove a project */
export async function removeProject(id: string): Promise<void> {
  const projects = States.getSyncArrayData(Project.list);
  if(projects.length === 1) {
    showError('Error while deleting project',
      'The last project cannot be removed');
    return;
  }

  const confirm = await Dialogs.showMessageBox({
    buttons: [
      { label: 'Cancel' },
      { label: 'Ok', value: true }
    ],
    details: 'Confirm to delete the project.',
    message: 'Delete project',
  });

  if(confirm === true) {
    const error = await Server.send(Project.remove, id);
    if(error) showError('Error while deleting project', error);
  }
}

/** Duplicate a project */
export function duplicateProject(
  id: string, title: string, project?: string
): void {
  const onValidate = (name: string): void => {
    Server.send(Project.copy, [id, name]).then((error) => {
      if(!error) Dialogs.closeModal();
      else showError('Error while duplicating project', error);
    });
    Dialogs.modalLoader.setValue(true);
  };
  showModalProject(title, onValidate, project);
}

/** Save a project */
export async function saveProject(id: string): Promise<void> {
  const file = await Dialogs.showSaveFile({});
  const error = await Server.send(Project.save, [id, file]);
  if(error) showError('Error while saving project', error);
}

/** Load a project */
export async function loadProject(): Promise<void> {
  const file = await Dialogs.showOpenFile({});
  const error = await Server.send(Project.load, file);
  if(error) showError('Error while loading project', error);
}

/** ************************************************************************ */

function getActions(id: string, name: string): React.JSX.Element {
  return (
    <>
      <IconButton
        icon='EDIT'
        size={14}
        title='Rename'
        onClick={() => renameProject(id, `Rename project: ${name}`, name)}
      />
      <IconButton
        icon='DUPLICATE'
        size={14}
        title='Duplicate'
        onClick={() =>
          duplicateProject(id, `Duplicate project: ${name}`, name)
        }
      />
      <IconButton
        icon='SAVE'
        size={14}
        title='Save'
        onClick={() => saveProject(id)}
      />
      <IconButton
        icon='TRASH'
        size={14}
        title='Delete'
        onClick={() => removeProject(id)}
      />
    </>
  );
}

export function Projects(): JSX.Element {
  const scrollableArea = React.useRef<HTMLDivElement>(null);
  const [ current, setCurrent ] = States.useSyncState(Project.current);
  const modelProjects = States.useSyncArrayModel(Project.list);
  const model = useModel(modelProjects);

  const projectsListSorted = React.useMemo(() => {
    return modelProjects.getArray().sort((a, b) => alpha(a.name, b.name));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [modelProjects, model]);

  /** Re-Build the project menu */
  React.useEffect(() => {
    /** The timeout is used for optimisation, * avoiding unnecessary
     * calculations when projects change very frequently. */
    const timeout = setTimeout(() => {
      Dome.delSubMenu('Project');
      const others: Dome.MenuItemProps[] = projectsListSorted.map(elt => {
        return {
          menu: 'Project',
          label: elt.name,
          id: `Project_${elt.uniqueName}`,
          kind: 'checkbox',
          checked: current === elt.uniqueName,
          enabled: current !== elt.uniqueName,
          onClick: () => setCurrent(elt.uniqueName)
        };
      });
      addProjectSubMenu(others);
    }, 100);
    return () => clearTimeout(timeout);
  }, [projectsListSorted, current, setCurrent]);

  /** Build item components for project sidebar */
  const projectsList = React.useMemo(() => {
    return projectsListSorted.map(elt => {
      return <Item
          key={elt.uniqueName}
          label={elt.name}
          title={`unique name: ${elt.uniqueName}`}
          selected={elt.uniqueName === current}
          onSelection={() => setCurrent(elt.uniqueName) }
        >{getActions(elt.uniqueName, elt.name)}</Item>;
    });
  }, [projectsListSorted, current, setCurrent]);

  return (<>
    <SidebarTitle
      className='projects'
      label='Projects'
    >
      <Hbox className='projects-title-actions'>
        <IconButton
          icon='DOWNLOAD'
          title='Load a project'
          size={18}
          onClick={loadProject}
        />
        <IconButton
          icon='CIRC.PLUS'
          title='Create a new empty project'
          size={18}
          onClick={newProject}
        />
      </Hbox>
    </SidebarTitle>
      <div ref={scrollableArea} className='globals-scrollable-area'>
        { projectsList }
      </div>
    </>
  );
}

// --------------------------------------------------------------------------
