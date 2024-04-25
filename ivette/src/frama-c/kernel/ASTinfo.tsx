/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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
import * as Ast from 'frama-c/kernel/api/ast';
import { Text, Modifier } from 'frama-c/richtext';
import { Icon } from 'dome/controls/icons';
import { Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import * as Boxes from 'dome/layout/boxes';
import { TitleBar } from 'ivette';

// --------------------------------------------------------------------------
// --- Marker Utility
// --------------------------------------------------------------------------

function addMarker(
  ms: Ast.marker[],
  m: Ast.marker | undefined
): Ast.marker[] {
  return m ? (ms.includes(m) ? ms : ms.concat(m)) : ms;
}

function toggleMarker(ms: Ast.marker[], m: Ast.marker): Ast.marker[] {
  return ms.includes(m) ? ms.filter((m0) => m0 !== m) : ms.concat(m);
}

function makeFilter(filter: string): string[] {
  return filter.split(':').filter((s) => s.length > 0).sort();
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
  onSelected: (m: Ast.marker, meta: Modifier) => void;
  onHovered: (m: Ast.marker | undefined) => void;
}

function FieldInfo(props: FieldInfoProps): JSX.Element {
  const onSelected = (m: string, meta: Modifier): void => {
    props.onSelected(Ast.jMarker(m), meta);
  };
  const onHovered = (m: string | undefined): void => {
    props.onHovered(m ? Ast.jMarker(m) : undefined);
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
  current: Ast.decl | undefined; // current selection
  marker: Ast.marker; // of the info-section
  scrolled: Ast.marker | undefined; // among info-sections
  selected: Ast.marker | undefined; // in current selection
  hovered: Ast.marker | undefined;  // in current selection
  marked: boolean;
  excluded: string[];
  setPinned: (m: Ast.marker) => void;
  togglePinned: (m: Ast.marker) => void;
}

function MarkInfos(props: InfoSectionProps): JSX.Element {
  const { current, marker, scrolled, selected, hovered, excluded } = props;
  const { labelKind, titleKind, scope, descr } = States.useMarker(marker);
  const { label } = States.useDeclaration(scope);
  const foreign = !!current && !!scope && current !== scope;
  const [unfold, setUnfold] = React.useState(true);
  const [expand, setExpand] = React.useState(false);
  const markerFields = States.useRequest(Ast.getInformation, marker) ?? [];
  const isScrolled = marker === scrolled;
  const isHovered = marker === hovered;
  const isSelected = marker === selected;
  const highlight = classes(
    isSelected && 'selected',
    isHovered && 'hovered',
  );
  const filtered = markerFields.filter((fd) => !excluded.includes(fd.id));
  const hasMore = filtered.length < markerFields.length;
  const displayed = expand ? markerFields : filtered;
  const onFoldUnfold = (evt: React.MouseEvent): void => {
    evt.stopPropagation();
    setUnfold(!unfold);
  };
  const onChildSelected = (m: Ast.marker, modifier: Modifier): void => {
    props.setPinned(marker);
    switch (modifier) {
      case 'NORMAL':
        States.setMarked(m);
        break;
      case 'META':
        States.setMarked(m, m !== marker);
        break;
      case 'DOUBLE':
        States.setSelected(m);
        break;
    }
  };
  const onChildHovered = (m: Ast.marker | undefined): void => {
    States.setHovered(m || marker);
  };
  return (
    <div
      ref={isScrolled ? props.scroll : undefined}
      className={`astinfo-section ${highlight}`}
      onMouseEnter={() => States.setHovered(marker)}
      onMouseLeave={() => States.setHovered(undefined)}
      onClick={() => onChildSelected(marker, 'NORMAL')}
      onDoubleClick={() => onChildSelected(marker, 'DOUBLE')}
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
          onClick={onFoldUnfold}
        />
        <Code key="NAME" className="astinfo-markercode">
          <span className="astinfo-markerkind" title={titleKind}>
            {labelKind}
          </span> {descr}
        </Code>
        <Code key="SCOPE" className="" display={foreign}>[in {label}]</Code>
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
          title={(props.marked ? "Unpin" : "Pin") + " marker information"}
          onClick={() => props.togglePinned(marker)}
        />
      </div>
      {unfold && displayed.map((field) => (
        <FieldInfo
          key={field.id}
          field={field}
          onSelected={onChildSelected}
          onHovered={onChildHovered}
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
  // Selection Hooks
  const [markers, setMarkers] = React.useState<Ast.marker[]>([]);
  const [setting, setSetting] = Dome.useStringSettings(filterSettings, '');
  const { scope: current, marker: selected } = States.useCurrentLocation();
  const hovered = States.useHovered();
  const allFields = States.useRequest(Ast.getInformation, null) ?? [];
  const excluded = React.useMemo(() => makeFilter(setting), [setting]);
  Dome.useEvent(States.MetaSelection, (loc: States.Location) => {
    setMarkers(addMarker(markers, loc.marker));
  });
  const clearMarkers = React.useCallback(() => setMarkers([]), []);
  Server.useShutdown(clearMarkers);
    // Scrolling Hooks
  const [inside, setInside] = React.useState(false);
  const scroll = React.useRef<HTMLDivElement>(null);
  const scrollDiv = scroll.current;
  React.useEffect(() => {
    scrollDiv?.scrollIntoView({ block: 'nearest' });
  }, [scrollDiv]);
  // Derived
  const allMarkers = addMarker(addMarker(markers, selected), hovered);
  const scrolled = inside ? selected : (hovered || selected);
  // Callbacks
  const setExcluded = (fs: string[]): void =>
    setSetting(fs.join(':'));
  const setPinned = (marker: Ast.marker): void =>
    setMarkers(addMarker(markers, marker));
  const togglePinned = (marker: Ast.marker): void =>
    setMarkers(toggleMarker(markers, marker));
  // Mark Rendering
  const renderMark = (marker: Ast.marker): JSX.Element | null => {
    return (
      <MarkInfos
        key={marker}
        current={current}
        scroll={scroll}
        marker={marker}
        scrolled={scrolled}
        hovered={hovered}
        selected={selected}
        excluded={excluded}
        marked={markers.includes(marker)}
        setPinned={setPinned}
        togglePinned={togglePinned}
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
      <Boxes.Scroll
        onMouseEnter={() => setInside(true)}
        onMouseLeave={() => setInside(false)}
      >
        {allMarkers.map(renderMark)}
        <div style={{ height: 20 }} />
      </Boxes.Scroll>
    </>
  );
}

// --------------------------------------------------------------------------
