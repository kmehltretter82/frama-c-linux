/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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
import * as Server from 'frama-c/server';
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
// --- Marker Utility
// --------------------------------------------------------------------------

function addMarker(
  ms: AST.marker[],
  m: AST.marker | undefined
): AST.marker[] {
  return m ? (ms.includes(m) ? ms : ms.concat(m)) : ms;
}

function toggleMarker(ms: AST.marker[], m: AST.marker): AST.marker[] {
  return ms.includes(m) ? ms.filter((m0) => m0 !== m) : ms.concat(m);
}

function makeFilter(filter: string): string[] {
  return filter.split(':').filter((s) => s.length > 0).sort();
}

// --------------------------------------------------------------------------
// --- Marker Kinds
// --------------------------------------------------------------------------

import Kind = AST.markerKind;
import Var = AST.markerVar

function getMarkerKind(props: AST.markerInfoData): [string, string] {
  switch (props.kind) {
    case Kind.declaration:
      switch (props.var) {
        case Var.function: return ["Declaration", "Function declaration"];
        case Var.variable: return ["Declaration", "Variable declaration"];
        case Var.none: return ["Declaration", "Declaration"];
      }
      break;
    case Kind.global: return ["Global", "Global declaration or definition"];
    case Kind.lvalue:
      switch (props.var) {
        case Var.function: return ["Function", "Function"];
        case Var.variable: return ["Variable", "C variable"];
        case Var.none: return ["Lvalue", "C lvalue"];
      }
      break;
    case Kind.expression: return ["Expression", "C expression"];
    case Kind.statement: return ["Statement", "C statement"];
    case Kind.property: return ["Property", "ACSL property"];
    case Kind.term: return ["Term", "ACSL term"];
    case Kind.type: return ["Type", "C type"];
  }
}

function markerKind(props: AST.markerInfoData): JSX.Element {
  const [label, title] = getMarkerKind(props);
  return <span className="astinfo-markerkind" title={title}>{label}</span>;
}

// --------------------------------------------------------------------------
// --- Information Details
// --------------------------------------------------------------------------

interface FieldInfo {
  id: string;
  label: string; // short name
  title: string; // long titled name
  descr: string; // information value long description
  text: DATA.text;
}

interface FieldInfoProps {
  field: FieldInfo;
  onSelected: (m: AST.marker) => void;
  onHovered: (m: AST.marker | undefined) => void;
}

function FieldInfo(props: FieldInfoProps): JSX.Element {
  const onSelected = (m: string) => void props.onSelected(AST.jMarker(m));
  const onHovered = (m: string | undefined): void => {
    props.onHovered(m ? AST.jMarker(m) : undefined);
  };
  const { label, descr, title, text } = props.field;
  return (
    <div className="astinfo-infos" >
      <div className="dome-text-label astinfo-kind" title={title}>
        {label}
      </div>
      <div className="dome-text-cell astinfo-data" title={descr}>
        <Text onSelected={onSelected} onHovered={onHovered} text={text} />
      </div>
    </div >
  );
}

// --------------------------------------------------------------------------
// --- Mark Informations Buttons
// --------------------------------------------------------------------------

interface MarkButtonProps {
  icon: string;
  title: string;
  visible?: boolean;
  display?: boolean;
  selected?: boolean;
  onClick: () => void;
}

function MarkButton(props: MarkButtonProps): JSX.Element {
  return (
    <IconButton
      className="astinfo-markerbutton"
      size={10}
      offset={0}
      {...props}
    />
  );
}

// --------------------------------------------------------------------------
// --- Mark Informations Section
// --------------------------------------------------------------------------

interface InfoSectionProps {
  scroll: React.RefObject<HTMLDivElement> | undefined;
  marker: AST.marker;
  markerInfos: AST.markerInfoData;
  scrolled: AST.marker | undefined;
  selected: AST.marker | undefined;
  hovered: AST.marker | undefined;
  marked: boolean;
  excluded: string[];
  onHovered: (m: AST.marker | undefined) => void;
  onFocused: (m: AST.marker | undefined) => void; // internal hover
  onSelected: (m: AST.marker) => void;
  onPinned: (m: AST.marker) => void;
  onChildSelected: (m: AST.marker, e: AST.marker) => void;
}

function MarkInfos(props: InfoSectionProps): JSX.Element {
  const { marker, markerInfos } = props;
  const { scrolled, selected, hovered, excluded } = props;
  const [unfold, setUnfold] = React.useState(true);
  const [expand, setExpand] = React.useState(false);
  const req = React.useMemo(() => Server.send(AST.getInformation, marker), [marker]);
  const { result: markerFields = [] } = Dome.usePromise(req);
  const isScrolled = marker === scrolled;
  const isHovered = marker === hovered;
  const isSelected = marker === selected;
  const highlight = classes(
    isSelected && 'selected',
    isHovered && 'hovered',
  );
  const kind = markerKind(markerInfos);
  const name = markerInfos.name;
  const descr = markerInfos.descr ?? `${kind} ${name}`;
  const filtered = markerFields.filter((fd) => !excluded.includes(fd.id));
  const hasMore = filtered.length < markerFields.length;
  const displayed = expand ? markerFields : filtered;
  const onSelected = (m: AST.marker): void => props.onChildSelected(marker, m);
  const onFocused = (m: AST.marker | undefined): void => {
    if (m) {
      props.onHovered(m);
      props.onFocused(m);
    } else {
      props.onHovered(marker);
      props.onFocused(undefined);
    }
  };
  return (
    <div
      ref={isScrolled ? props.scroll : undefined}
      className={`astinfo-section ${highlight}`}
      onMouseEnter={() => props.onHovered(marker)}
      onMouseLeave={() => props.onHovered(undefined)}
      onDoubleClick={() => props.onSelected(marker)}
    >
      <div
        key="MARKER"
        className={`astinfo-markerbar ${highlight}`}
        title={descr}
      >
        <Icon
          key="FOLDER"
          className="astinfo-folderbutton"
          visible={displayed.length > 0}
          size={10}
          offset={-2}
          id={unfold ? 'TRIANGLE.DOWN' : 'TRIANGLE.RIGHT'}
          onClick={() => setUnfold(!unfold)}
        />
        <Code key="NAME" className="astinfo-markercode">
          {kind} {name}
        </Code>
        <MarkButton
          key="MORE"
          icon="CIRC.PLUS"
          display={hasMore}
          title="Show all available information"
          selected={expand}
          onClick={() => setExpand(!expand)}
        />
        <MarkButton
          key="PIN"
          icon="PIN"
          selected={props.marked}
          display={props.marked || isSelected || !isHovered}
          title="Remove Information"
          onClick={() => props.onPinned(marker)}
        />
      </div>
      {unfold && displayed.map((field) => (
        <FieldInfo
          key={field.id}
          field={field}
          onHovered={onFocused}
          onSelected={onSelected}
        />
      ))}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Context Menu Filter
// --------------------------------------------------------------------------

function openFilter(
  fields: FieldInfo[],
  excluded: string[],
  onChange: (filter: string[]) => void,
): void {
  const menuItem = (fd: FieldInfo): Dome.PopupMenuItem => {
    const checked = !excluded.includes(fd.id);
    const onClick = (): void => {
      const newFilter =
        checked
          ? excluded.concat(fd.id)
          : excluded.filter((m) => m !== fd.id);
      onChange(newFilter);
    };
    return {
      id: fd.id,
      label: `${fd.title} (${fd.label})`,
      checked,
      onClick,
    };
  };
  Dome.popupMenu(fields.map(menuItem));
}

// --------------------------------------------------------------------------
// --- Information Panel
// --------------------------------------------------------------------------

const filterSettings = 'frama-c.sidebar.astinfo.filter';

export default function ASTinfo(): JSX.Element {
  // Hooks
  const [markers, setMarkers] = React.useState<AST.marker[]>([]);
  const [setting, setSetting] = Dome.useStringSettings(filterSettings, '');
  const [selection, setSelection] = States.useSelection();
  const [hovering] = States.useHovered();
  const [focused, setFocused] = React.useState<AST.marker | undefined>();
  const allInfos = States.useSyncArray(AST.markerInfo);
  const allFields = States.useRequest(AST.getInformation, null) ?? [];
  const scroll = React.useRef<HTMLDivElement>(null);
  const excluded = React.useMemo(() => makeFilter(setting), [setting]);
  React.useEffect(() => {
    scroll.current?.scrollIntoView({ block: 'nearest' });
  });
  // Derived
  const fct = selection?.current?.fct;
  const selected = selection?.current?.marker;
  const hovered = hovering?.marker;
  const allMarkers = addMarker(addMarker(markers, selected), hovered);
  const scrolled = focused === hovered ? undefined : (hovered || selected);
  // Callbacks
  const setExcluded = (fs: string[]): void =>
    setSetting(fs.join(':'));
  const setSelected = (marker: AST.marker): void =>
    setSelection({ location: { fct, marker } });
  const setHovered = (marker: AST.marker | undefined): void => {
    States.setHovered(marker ? { fct, marker } : undefined);
  };
  const setPinned = (m: AST.marker): void =>
    setMarkers(toggleMarker(markers, m));
  const setChildSelected = (m: AST.marker, e: AST.marker): void => {
    setMarkers(addMarker(markers, m));
    setFocused(undefined);
    setSelected(e);
  };
  // Mark Rendering
  const renderMark = (marker: AST.marker): JSX.Element | null => {
    const markerInfos = allInfos.getData(marker);
    if (!markerInfos) return null;
    return (
      <MarkInfos
        key={marker}
        scroll={scroll}
        marker={marker}
        markerInfos={markerInfos}
        scrolled={scrolled}
        hovered={hovered}
        selected={selected}
        excluded={excluded}
        marked={markers.includes(marker)}
        onSelected={setSelected}
        onHovered={setHovered}
        onFocused={setFocused}
        onPinned={setPinned}
        onChildSelected={setChildSelected}
      />
    );
  };
  // Information Panel Rendering
  return (
    <>
      <TitleBar>
        <IconButton
          key="CLEAR"
          icon="CIRC.CLOSE"
          title="Clear Information Panel"
          display={markers.length > 0}
          onClick={() => setMarkers([])}
        />
        <IconButton
          key="RESET"
          icon="CIRC.PLUS"
          title="Reset Information Filter"
          display={excluded.length > 0}
          onClick={() => setSetting('')}
        />
        <IconButton
          key="FILTER"
          icon="CLIPBOARD"
          title="Information Filters"
          onClick={() => openFilter(allFields, excluded, setExcluded)}
        />
      </TitleBar>
      <Boxes.Scroll>
        {allMarkers.map(renderMark)}
      </Boxes.Scroll>
    </>
  );
}

// --------------------------------------------------------------------------
