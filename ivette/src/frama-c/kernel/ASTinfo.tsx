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
import { CompactModel } from 'dome/table/arrays';
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

export function register(infos: Informations) {
  registry.set(infos.id, infos);
  reloadASTinfo.emit();
}

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

interface InfoItemProps {
  label: string;
  title: string;
  children?: React.ReactNode;
}

const InfoItem = (props: InfoItemProps) => (
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

function MarkerInfoSection(props: InfoSectionProps) {
  Dome.useUpdate(reloadASTinfo);
  const [unfold, setUnfold] = React.useState(true);
  const { marker, markerInfo } = props;
  const contents: React.ReactNode[] = [];
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
type MarkerInfoModel = CompactModel<string, AST.markerInfoData>;

class InfoMarkers {

  private model: MarkerInfoModel = new CompactModel('key');
  private selection: Mark[] = [];
  private pinned = new Map<string, boolean>();
  private selected: undefined | AST.marker;
  private hovered: undefined | AST.marker;

  setModel(model: MarkerInfoModel) {
    this.model = model;
    reloadASTinfo.emit();
  }

  setHovered(marker?: AST.marker) {
    this.hovered = marker;
    reloadASTinfo.emit();
  }

  setSelected(location?: States.Location, extend?: boolean) {
    if (extend) {
      const m = this.selected;
      if (m) this.pinned.set(m, true);
    }
    const fct = location?.fct;
    const marker = location?.marker;
    this.selected = marker;
    const keep = (m: Mark) => m.marker === marker || this.isPinned(m.marker);
    const self = (m: Mark) => m.marker === marker;
    this.selection = this.selection.filter(keep);
    if (fct && marker && !this.selection.some(self)) {
      this.selection.push({ fct, marker });
      if (extend) this.pinned.set(marker, true);
    }
    reloadASTinfo.emit();
  }

  isPinned(marker: AST.marker | undefined): boolean {
    return (marker !== undefined) && (this.pinned.get(marker) ?? false);
  }

  setPinned(marker: AST.marker, pinned: boolean) {
    this.pinned.set(marker, pinned);
    reloadASTinfo.emit();
  }

  removeMarker(marker: AST.marker) {
    this.selection = this.selection.filter((m) => m.marker !== marker);
    this.pinned.delete(marker);
    reloadASTinfo.emit();
  }

  renderSection(mark: Mark) {
    const { marker } = mark;
    const info = this.model.getData(marker);
    if (!info) return null;
    const pinned = this.isPinned(marker);
    const selected = this.selected === marker;
    const hovered = this.hovered === marker;
    const onPin = () => this.setPinned(marker, !pinned);
    const onRemove = () => this.removeMarker(marker);
    const onHover = (h: boolean) => States.setHovered(h ? mark : undefined);
    const onSelect = () => States.setSelection(mark);
    return (
      <MarkerInfoSection
        key={marker}
        marker={marker}
        markerInfo={info}
        pinned={pinned}
        selected={selected}
        hovered={hovered}
        onPin={onPin}
        onRemove={onRemove}
        onHover={onHover}
        onSelect={onSelect}
      />
    );
  }

  renderSections(): React.ReactNode {
    return this.selection.map((m) => this.renderSection(m));
  }

}

// --------------------------------------------------------------------------
// --- Information Panel
// --------------------------------------------------------------------------

export default function ASTinfo() {
  Dome.useUpdate(reloadASTinfo);
  const markers = React.useMemo(() => new InfoMarkers(), []);
  const model = States.useSyncArray(AST.markerInfo, false);
  React.useEffect(() => markers.setModel(model), [markers, model]);
  const [selection] = States.useSelection();
  const [hoveredLoc] = States.useHovered();
  const location = selection?.current;
  const hovered = hoveredLoc?.marker;
  React.useEffect(() => markers.setSelected(location), [markers, location]);
  React.useEffect(() => markers.setHovered(hovered), [markers, hovered]);
  Dome.useEvent(States.MetaSelection, (loc) => markers.setSelected(loc, true));
  return (
    <Section
      settings="frama-c.astinfo.informations"
      label="Informations"
      title="Contextual informations on current selection"
    >
      {markers.renderSections()}
    </Section>
  );
}

// --------------------------------------------------------------------------
