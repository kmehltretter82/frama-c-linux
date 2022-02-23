/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2022                                                */
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
import * as DATA from 'frama-c/kernel/api/data';
import * as AST from 'frama-c/kernel/api/ast';
import { Text } from 'frama-c/richtext';
import { Icon } from 'dome/controls/icons';
import { Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import * as Boxes from 'dome/layout/boxes';
import { TitleBar } from 'ivette';

// --------------------------------------------------------------------------
// --- Marker Kinds
// --------------------------------------------------------------------------

interface MarkerKindProps { label: string; title: string }

function MarkerKind(props: MarkerKindProps): JSX.Element {
  const { label, title } = props;
  return <span className="astinfo-markerkind" title={title}>{label}</span>;
}

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

// --------------------------------------------------------------------------
// --- Information Details
// --------------------------------------------------------------------------

interface InfoItemProps {
  label: string;
  title: string;
  descr: DATA.text;
}

function InfoItem(props: InfoItemProps): JSX.Element {
  return (
    <div className="astinfo-infos">
      <div
        className="dome-text-label astinfo-kind"
        title={props.title}
      >
        {props.label}
      </div>
      <div className="dome-text-cell astinfo-data">
        <Text text={props.descr} />
      </div>
    </div>
  );
}

interface ASTinfos {
  id: string;
  label: string;
  title: string;
  descr: DATA.text;
}

interface InfoSectionProps {
  marker: AST.marker;
  markerInfo: AST.markerInfoData;
  filter: string;
  selected: boolean;
  hovered: boolean;
  pinned: boolean;
  onPin: () => void;
  onHover: (hover: boolean) => void;
  onSelect: () => void;
  onRemove: () => void;
}

function MarkInfos(props: InfoSectionProps): JSX.Element {
  const [unfold, setUnfold] = React.useState(true);
  const [more, setMore] = React.useState(false);
  const { marker, markerInfo } = props;
  const allInfos: ASTinfos[] =
    States.useRequest(AST.getInformations, marker) ?? [];
  const highlight = classes(
    props.selected && !props.pinned && 'transient',
    props.hovered && 'hovered',
  );
  const descr = markerInfo.descr ?? markerInfo.name;
  const kind = MARKERS.get(markerInfo.kind) ?? GMARKER;
  const fs = props.filter.split(':');
  const filtered = allInfos.filter((info) => !fs.some((m) => m === info.id));
  const infos = more ? allInfos : filtered;
  const hasMore = filtered.length < allInfos.length;
  return (
    <div
      className={`astinfo-section ${highlight}`}
      onMouseEnter={() => props.onHover(true)}
      onMouseLeave={() => props.onHover(false)}
      onDoubleClick={props.onSelect}
    >
      <div
        key="MARKER"
        className={`astinfo-markerbar ${highlight}`}
        title={descr}
      >
        <Icon
          className="astinfo-folderbutton"
          style={{ visibility: infos.length ? 'visible' : 'hidden' }}
          size={9}
          offset={-2}
          id={unfold ? 'TRIANGLE.DOWN' : 'TRIANGLE.RIGHT'}
          onClick={() => setUnfold(!unfold)}
        />
        <Code className="astinfo-markercode">
          {kind}{descr}
        </Code>
        <IconButton
          className="astinfo-markerbutton"
          title="Pin/unpin information in sidebar"
          size={9}
          offset={0}
          icon="PIN"
          selected={props.pinned}
          onClick={props.onPin}
        />
        <IconButton
          style={{ display: hasMore ? undefined : 'none' }}
          className="astinfo-markerbutton"
          title="Show all available informations"
          size={9}
          offset={0}
          icon="CIRC.PLUS"
          selected={more}
          onClick={() => setMore(!more)}
        />
        <IconButton
          className="astinfo-markerbutton"
          title="Remove informations"
          size={9}
          offset={0}
          icon="CIRC.CLOSE"
          onClick={props.onRemove}
        />
      </div>
      {unfold && infos.map((info) => <InfoItem key={info.id} {...info} />)}
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

  setSelected(location?: States.Location, pinned = false): void {
    const fct = location?.fct;
    const marker = location?.marker;
    const keep =
      (m: Mark): boolean => m.marker === marker || this.isPinned(m.marker);
    const self =
      (m: Mark): boolean => m.marker === marker;
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

  setPinned(marker: AST.marker, pinned: boolean): void {
    this.pinned.set(marker, pinned);
    reload.emit();
  }

  removeMarker(marker: AST.marker): void {
    this.selection = this.selection.filter((m) => m.marker !== marker);
    this.pinned.delete(marker);
    reload.emit();
  }

  getSelected(): Mark[] { return this.selection; }

}

// --------------------------------------------------------------------------
// --- Context Menu Filter
// --------------------------------------------------------------------------

function openFilter(
  infos: ASTinfos[],
  filter: string,
  onChange: (f: string) => void,
): void {
  const menuItems = infos.map((info) => {
    const fs = filter.split(':');
    const checked = !fs.some((m) => m === info.id);
    const onClick = (): void => {
      const newFs =
        checked
          ? fs.concat(info.id)
          : fs.filter((m) => m !== info.id);
      onChange(newFs.join(':'));
    };
    return {
      id: info.id,
      label: `${info.title} (${info.label})`,
      checked,
      onClick,
    };
  });
  Dome.popupMenu(menuItems);
  return;
}

// --------------------------------------------------------------------------
// --- Information Panel
// --------------------------------------------------------------------------

export default function ASTinfo(): JSX.Element {
  // Hooks
  Dome.useUpdate(reload);
  const markers = React.useMemo(() => new InfoMarkers(), []);
  const markerInfos = States.useSyncArray(AST.markerInfo, false);
  const [selection] = States.useSelection();
  const [hoveredLoc] = States.useHovered();
  const informations = States.useRequest(AST.getInformations, null) ?? [];
  const [filter, setFilter] =
    Dome.useStringSettings('frama-c.sidebar.astinfo.filter', '');
  const location = selection?.current;
  const selected = location?.marker;
  const hovered = hoveredLoc?.marker;
  React.useEffect(() => markers.setSelected(location), [markers, location]);
  Dome.useEvent(States.MetaSelection, (loc) => {
    if (selected) markers.setPinned(selected, true);
    markers.setSelected(loc, true);
  });
  // Rendering
  const renderMark = (mark: Mark): JSX.Element | null => {
    const { marker } = mark;
    const markerInfo = markerInfos.getData(marker);
    if (!markerInfo) return null;
    const pinned = markers.isPinned(marker);
    const isSelected = selected === marker;
    const isHovered = hovered === marker;
    const onPin = () => void markers.setPinned(marker, !pinned);
    const onRemove = () => void markers.removeMarker(marker);
    const onSelect = () => void States.setSelection(mark);
    const onHover =
      (h: boolean): void => States.setHovered(h ? mark : undefined);
    return (
      <MarkInfos
        key={marker}
        marker={marker}
        markerInfo={markerInfo}
        pinned={pinned}
        selected={isSelected}
        filter={filter}
        hovered={isHovered}
        onPin={onPin}
        onRemove={onRemove}
        onHover={onHover}
        onSelect={onSelect}
      />
    );
  };
  return (
    <>
      <TitleBar>
        <IconButton
          icon="CLIPBOARD"
          onClick={() => openFilter(informations, filter, setFilter)}
          title="Information Filters"
        />
      </TitleBar>
      <Boxes.Vfill>
        {markers.getSelected().map(renderMark)}
      </Boxes.Vfill>
    </>
  );
}

// --------------------------------------------------------------------------
