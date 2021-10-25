/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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

// --------------------------------------------------------------------------
// --- AST Information
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import * as States from 'frama-c/states';
import * as AST from 'frama-c/api/kernel/ast';
import { Section } from 'dome/frame/sidebars';
import { Icon } from 'dome/controls/icons';
import { Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';

// --------------------------------------------------------------------------
// --- Information Callback
// --------------------------------------------------------------------------
export interface Informations {
  id: string;
  label: string;
  title: string;
  getInfo: (m: AST.marker) => React.ReactNode;
}

const reloadASTinfo = new Dome.Event('frama-c.astinfo');
const registry = new Map<string, Informations>();

export function register(infos: Informations)
{
  registry.set(infos.id, infos);
  reloadASTinfo.emit();
}

// --------------------------------------------------------------------------
// --- Information Section
// --------------------------------------------------------------------------

interface InfoItemProps {
  label: string;
  title: string;
  children?: React.ReactNode;
}

function InfoItem(props: InfoItemProps)
{
  return (
    <>
      <div
        className="dome-text-label kernel-astinfo-kind"
        title={props.title}
      >
        {props.label}
      </div>
      <div className="dome-text-cell kernel-astinfo-data">
        {props.children}
      </div>
    </>
  );
}

interface InfoSectionProps {
  marker: AST.marker;
  markerInfo: AST.markerInfoData;
}

function markerKind(kind: AST.markerKind): string
{
  switch (kind) {
    case AST.markerKind.declaration: return 'D';
    case AST.markerKind.global: return 'G';
    case AST.markerKind.lvalue: return 'L';
    case AST.markerKind.expression: return 'E';
    case AST.markerKind.statement: return 'S';
    case AST.markerKind.property: return 'P';
    default: return '?';
  }
}

function InfoSection(props: InfoSectionProps) {
  Dome.useUpdate(reloadASTinfo);
  const [unfold, setUnfold] = React.useState(true);
  const { marker, markerInfo } = props;
  const contents: React.ReactNode[] = [];
  if (unfold) {
    registry.forEach((info: Informations) => {
      const data = info.getInfo(marker);
      if (data) {
        contents.push(
          <InfoItem key={info.id} label={info.label} title={info.title}>
            {info.getInfo(marker)}
          </InfoItem>,
        );
      }
    });
  }
  const descr = markerInfo.descr ?? markerInfo.name;
  const kind = markerKind(markerInfo.kind);
  return (
    <div className="astinfo-section">
      <div className="astinfo-markerbar" title={descr}>
        <Icon
          className="astinfo-folderbutton"
          size={9}
          offset={-2}
          id={unfold ? 'TRIANGLE.DOWN' : 'TRIANGLE.RIGHT'}
          onClick={() => setUnfold(!unfold)}
        />
        <Code className="astinfo-markercode">
          <span className="astinfo-markerkind">{kind}</span>
          {descr}
        </Code>
        <IconButton
          className="astinfo-markerbutton"
          size={9}
          offset={0}
          icon="PIN"
          // onClick={() => console.log('PIN', marker)}
        />
        <IconButton
          className="astinfo-markerbutton"
          size={9}
          offset={0}
          icon="CIRC.CLOSE"
          // onClick={() => console.log('CLOSE', marker)}
        />
      </div>
      <div className="astinfo-infos">
        {contents}
      </div>
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Information Panel
// --------------------------------------------------------------------------

export default function ASTinfo() {
  const markersInfo = States.useSyncArray(AST.markerInfo);
  const [selection/* , updateSelection */] = States.useSelection();
  const marker = selection?.current?.marker;

  // render null when no selection
  if (!marker) return null;
  const markerInfo = markersInfo.getData(marker);
  if (!markerInfo) return null;

  // const data = States.useRequest(AST.getInfo, marker);
  return (
    <Section
      settings="frama-c.astinfo.informations"
      label="Informations"
      title="Contextual informations on current selection"
    >
      <InfoSection marker={marker} markerInfo={markerInfo} />
    </Section>
  );
}

// --------------------------------------------------------------------------
