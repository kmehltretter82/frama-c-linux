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
import { classes } from 'dome/misc/utils';
import * as States from 'frama-c/states';
import * as AST from 'frama-c/api/kernel/ast';
import { Section } from 'dome/frame/sidebars';
import { Icon } from 'dome/controls/icons';
import { Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';

// --------------------------------------------------------------------------
// --- Information Details
// --------------------------------------------------------------------------

interface MarkerKindProps { label: string; title: string }

const MarkerKind = (props: MarkerKindProps) => {
  const { label, title } = props;
  return <span className="astinfo-markerkind" title={title}>{label}</span>;
};

const GMARKER =
  <MarkerKind label="M" title="Generic Marker" />;

const MARKERS = new Map<AST.markerKind, JSX.Element>();
[
  {
    kind: AST.markerKind.declaration,
    elt: <MarkerKind label="D" title="Declaration" />,
  },
  {
    kind: AST.markerKind.global,
    elt: <MarkerKind label="G" title="Global" />,
  },
  {
    kind: AST.markerKind.lvalue,
    elt: <MarkerKind label="L" title="L-value" />,
  },
  {
    kind: AST.markerKind.expression,
    elt: <MarkerKind label="E" title="Expression" />,
  },
  {
    kind: AST.markerKind.statement,
    elt: <MarkerKind label="S" title="Statement" />,
  },
  {
    kind: AST.markerKind.property,
    elt: <MarkerKind label="P" title="Property" />,
  },
  {
    kind: AST.markerKind.term,
    elt: <MarkerKind label="T" title="Term" />,
  },
].forEach(({ kind, elt }) => MARKERS.set(kind, elt));

/* interface InfoItemProps {
 *   label: string;
 *   title: string;
 *   children?: React.ReactNode;
 * }
 *
 * const InfoItem = (props: InfoItemProps) => (
 *   <>
 *     <div
 *       className="dome-text-label kernel-astinfo-kind"
 *       title={props.title}
 *     >
 *       {props.label}
 *     </div>
 *     <div className="dome-text-cell kernel-astinfo-data">
 *       {props.children}
 *     </div>
 *   </>
 * );
 *  */

interface InfoSectionProps {
  marker: AST.marker;
  markerInfo: AST.markerInfoData;
  selected: boolean;
  hovered: boolean;
  pinned: boolean;
  onPin: () => void;
  onHover: (hover: boolean) => void;
  onSelect: () => void;
  onRemove: () => void;
}

function MarkInfos(props: InfoSectionProps) {
  const [unfold, setUnfold] = React.useState(true);
  const { marker, markerInfo } = props;
  const contents: React.ReactNode[] = [];
  if (marker !== markerInfo.key) return null;
  /*
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
  */
  const barClassName = classes(
    'astinfo-markerbar',
    props.selected && 'selected',
    !props.selected && props.hovered && 'hovered',
  );
  const descr = markerInfo.descr ?? markerInfo.name;
  const kind = MARKERS.get(markerInfo.kind) ?? GMARKER;
  const foldUnfold = () => setUnfold(!unfold);
  return (
    <div className="astinfo-section">
      <div
        key="MARKER"
        className={barClassName}
        title={descr}
        onMouseEnter={() => props.onHover(true)}
        onMouseLeave={() => props.onHover(false)}
      >
        <Icon
          className="astinfo-folderbutton"
          style={{ visibility: contents.length ? 'visible' : 'hidden' }}
          size={9}
          offset={-2}
          id={unfold ? 'TRIANGLE.DOWN' : 'TRIANGLE.RIGHT'}
          onClick={foldUnfold}
        />
        <Code
          className="astinfo-markercode"
          onClick={props.onSelect}
        >
          {kind}{descr}
        </Code>
        <IconButton
          className="astinfo-markerbutton"
          size={9}
          offset={0}
          icon="PIN"
          selected={props.pinned}
          onClick={props.onPin}
        />
        <IconButton
          className="astinfo-markerbutton"
          size={9}
          offset={0}
          icon="CIRC.CLOSE"
          onClick={props.onRemove}
        />
      </div>
      <div
        key="INFOS"
        className="astinfo-infos"
        style={{ display: unfold && contents.length ? 'grid' : 'none' }}
      >
        {contents}
      </div>
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Information Selection State
// --------------------------------------------------------------------------

type Mark = { fct: string; marker: AST.marker };

const reload = new Dome.Event('frama-c.astinfo');

class InfoMarkers {

  private selection: Mark[] = [];
  private pinned = new Map<string, boolean>();

  setSelected(location?: States.Location, pinned = false) {
    const fct = location?.fct;
    const marker = location?.marker;
    const keep = (m: Mark) => m.marker === marker || this.isPinned(m.marker);
    const self = (m: Mark) => m.marker === marker;
    this.selection = this.selection.filter(keep);
    if (fct && marker && !this.selection.some(self)) {
      this.selection.push({ fct, marker });
      this.pinned.set(marker, pinned);
    }
    reload.emit();
  }

  isPinned(marker: AST.marker | undefined): boolean {
    return (marker !== undefined) && (this.pinned.get(marker) ?? false);
  }

  setPinned(marker: AST.marker, pinned: boolean) {
    this.pinned.set(marker, pinned);
    reload.emit();
  }

  removeMarker(marker: AST.marker) {
    this.selection = this.selection.filter((m) => m.marker !== marker);
    this.pinned.delete(marker);
    reload.emit();
  }

  getSelected(): Mark[] { return this.selection; }

}

// --------------------------------------------------------------------------
// --- Information Panel
// --------------------------------------------------------------------------

export default function ASTinfo() {
  Dome.useUpdate(reload);
  const markers = React.useMemo(() => new InfoMarkers(), []);
  const markerInfos = States.useSyncArray(AST.markerInfo, false);
  const [selection] = States.useSelection();
  const [hoveredLoc] = States.useHovered();
  const location = selection?.current;
  const selected = location?.marker;
  const hovered = hoveredLoc?.marker;
  React.useEffect(() => markers.setSelected(location), [markers, location]);
  Dome.useEvent(States.MetaSelection, (loc) => {
    if (selected) markers.setPinned(selected, true);
    markers.setSelected(loc, true);
  });
  const renderMark = (mark: Mark) => {
    const { marker } = mark;
    const markerInfo = markerInfos.getData(marker);
    if (!markerInfo) return null;
    const pinned = markers.isPinned(marker);
    const isSelected = selected === marker;
    const isHovered = hovered === marker;
    const onPin = () => markers.setPinned(marker, !pinned);
    const onRemove = () => markers.removeMarker(marker);
    const onHover = (h: boolean) => States.setHovered(h ? mark : undefined);
    const onSelect = () => States.setSelection(mark);
    return (
      <MarkInfos
        key={marker}
        marker={marker}
        markerInfo={markerInfo}
        pinned={pinned}
        selected={isSelected}
        hovered={isHovered}
        onPin={onPin}
        onRemove={onRemove}
        onHover={onHover}
        onSelect={onSelect}
      />
    );
  };
  return (
    <Section
      defaultUnfold
      settings="frama-c.sidebar.astinfo"
      label="Informations"
      title="Contextual informations on current selection"
    >
      {markers.getSelected().map(renderMark)}
    </Section>
  );
}

// --------------------------------------------------------------------------
