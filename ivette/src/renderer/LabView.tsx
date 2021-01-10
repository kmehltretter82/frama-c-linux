// --------------------------------------------------------------------------
// ---  Lab View Component
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module ivette
*/

import _ from 'lodash';
import React from 'react';
import * as Dome from 'dome';
import * as Json from 'dome/data/json';
import * as Settings from 'dome/data/settings';
import { Catch } from 'dome/errors';
import { DnD, DragSource } from 'dome/dnd';
import { SideBar, Section, Item } from 'dome/frame/sidebars';
import { RSplit } from 'dome/layout/splitters';
import * as Grids from 'dome/layout/grids';
import { Hbox, Hfill, Vfill } from 'dome/layout/boxes';
import { IconButton, Field } from 'dome/controls/buttons';
import { Label } from 'dome/controls/labels';
import { Icon } from 'dome/controls/icons';
import { DefineElement, RenderElement } from 'dome/layout/dispatch';

import './style-labview.css';

// --------------------------------------------------------------------------
// --- Library Class
// --------------------------------------------------------------------------

const UPDATE = new Dome.Event('labview.library');

class Library {
  modified: boolean;
  virtual: {};
  collection: {};
  items: any[];

  constructor() {
    this.modified = false;
    this.virtual = {};
    this.collection = {};
    this.items = [];
  }

  commit() {
    if (!_.isEqual(this.collection, this.virtual)) {
      this.collection = { ...this.virtual };
      this.items = _.sortBy(this.collection, ['order', 'id']);
      this.modified = false;
      UPDATE.emit();
    }
  }

  addItem(
    id: string,
    gcontext: any,
    path: any[],
    props: { rank: undefined; group: any },
  ) {
    if (!this.modified) {
      this.modified = true;
      setImmediate(() => this.commit());
    }
    const order = props.rank === undefined
      ? path
      : path.slice(0, -1).concat([props.rank]);
    const group = props.group || gcontext;
    const collection: any = this.virtual;
    collection[id] = { id, order, group, ...props };
  }

  removeItem(id?: string) {
    if (id) {
      const collection: any = this.virtual;
      delete collection[id];
    }
  }

  updateFrom(lib: Library) {
    if (lib === this) return false;
    this.virtual = { ...lib.virtual, ...this.virtual };
    if (!this.modified) {
      this.modified = true;
      setImmediate(() => this.commit());
    }
    return true;
  }

}

// --------------------------------------------------------------------------
// --- Global Consolidated Library
// --------------------------------------------------------------------------

const LIBRARY = new Library();

function useLibrary() {
  const libRef = React.useRef(LIBRARY);
  // Hot Reload detection
  if (LIBRARY.updateFrom(libRef.current)) {
    libRef.current = LIBRARY;
  }
  return LIBRARY;
}

// --------------------------------------------------------------------------
// --- Library Components
// --------------------------------------------------------------------------

const isItemId =
  (fd: string, id: string) => id.startsWith(fd) && id[fd.length] === '.';
const getItemId =
  (fd: string, id: string) => (
    isItemId(fd, id) ? id.substring(fd.length + 1) : undefined
  );
const getItems =
  (items: any[], fd: string) => items.filter((item) => isItemId(fd, item.id));

interface GroupContext {
  group?: string;
  order?: number[];
}

const GROUP = React.createContext<GroupContext>({});

function useLibraryItem(fd: string, { id, ...props }: any): GroupContext {
  const context = React.useContext(GROUP);
  React.useEffect(() => {
    const { group, order } = context;
    const itemId = `${fd}.${id}`;
    LIBRARY.addItem(itemId, group, order ?? [], props);
    return () => LIBRARY.removeItem(itemId);
  });
  return context;
}

/* --------------------------------------------------------------------------*/
/* --- Rankifyier                                                         ---*/
/* --------------------------------------------------------------------------*/

interface RankifyProps {
  group: string | undefined;
  order: number[] | undefined;
  children: React.ReactNode | undefined;
}

function Rankify(props: RankifyProps) {
  const { group, order = [], children } = props;
  let rank = 0;
  const rankify = (elt: any) => {
    rank += 1;
    return (
      <GROUP.Provider value={{ group, order: [...order, rank] }}>
        {elt}
      </GROUP.Provider>
    );
  };
  return (
    <>
      {React.Children.map(children, rankify)}
    </>
  );
}

function UseLibrary(props: { children?: React.ReactNode }) {
  return (
    <div className="dome-phantom">
      <Rankify group={undefined} order={[]}>
        {props.children}
      </Rankify>
    </div>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Fragments                                                          ---*/
/* --------------------------------------------------------------------------*/

export interface FragmentProps {
  group?: string;
  rank?: number;
  children?: React.ReactNode;
}

/**
   Ordered collection of LabView Components.
   Otherwise, elements are ordered by `rank` and `id`.
 */
export function Fragment(props: FragmentProps) {
  const { group, rank, children } = props;
  const context = React.useContext(GROUP);
  const base = context.order ?? [];
  return (
    <Rankify
      group={group ?? context.group}
      order={rank === undefined ? base : [...base, rank]}
    >
      {children}
    </Rankify>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Groups                                                             ---*/
/* --------------------------------------------------------------------------*/

export interface ItemProps {
  /** Identifier. */
  id: string;
  /** Displayed name. */
  label: string;
  /** Tooltip description. */
  title?: string;
  /** Contents. */
  children?: React.ReactNode;
}

/**
   Defines a group of components. The components rendered
   _inside_ its content are implicitely affected to this group,
   unless specified. The group content are also rendered
   in their specified order. For nested collections of components,
   use `<Fragment/>` instead of `<React.Fragment/>` to specify order.
 */
export function Group(props: ItemProps) {
  const { children, ...group } = props;
  const context = useLibraryItem('groups', group);
  return (
    <Rankify
      group={props.id}
      order={context.order ?? []}
    >
      {children}
    </Rankify>
  );
}

// --------------------------------------------------------------------------
// --- Views
// --------------------------------------------------------------------------

export interface ViewProps extends ItemProps {
  /** Use this view by default. */
  defaultView?: boolean;
}

/**
   Layout of LabView Components.
   Defines a predefined layout of components. The view is organized
   into a GridContent, which must _only_ consists of:
   - `<GridHbox>…</GridHbox>` an horizontal grid of `GridContent` elements;
   - `<GridVbox>…</GridVbox>` a vertical grid of `GridContent` elements;
   - `<GridItem id=…>` a single component.

   These grid content components must be imported from the `dome/layout/grids`
   module:
   ```
   import { GridItem, GridHbox, GridVbox } from 'dome/layout/grids';
   ```
 */
export function View(props: ViewProps) {
  useLibraryItem('views', props);
  return null;
}

// --------------------------------------------------------------------------
// --- Components
// --------------------------------------------------------------------------

export interface ComponentProps extends ItemProps {
  /** Group attachment (defaults to group context) */
  group?: string;
  /** Ordering index (defaults to fragment context). */
  rank?: number;
}

/**
   LabView Component.
   Defines a component and its content when incorporated inside a view.
   Unless specified, the component will be implicitely attached
   to the current enclosing group. The `rank` property can be used
   for adjusting component ordering (see also `<Fragment/>` and `<Group/>`).
 */
export function Component(props: ComponentProps) {
  useLibraryItem('components', props);
  return null;
}

interface TitleContext {
  id?: string;
  label?: string;
  title?: string;
}
const TITLE = React.createContext<TitleContext>({});

export interface TitleBarProps {
  /*
     @property {string} [icon] - displayed icon
     @property {string} [label] - displayed name
     @property {string} [title] - description tooltip
     @property {React.Children} children - additional components to render
   */
  /** Displayed icon. */
  icon?: string;
  /** Displayed name (when mounted). */
  label?: string;
  /** Tooltip description (when mounted). */
  title?: string;
  /** TitleBar additional components (stacked to right). */
  children?: React.ReactNode;
}

/**
   LabView Component's title bar.
   Defines an alternative component title bar in current context.
   Default values are taken from the associated component.
 */
export const TitleBar = ({ icon, label, title, children }: any) => {
  const context = React.useContext(TITLE);
  const { id } = context;
  if (!id) return null;
  return (
    <DefineElement id={`labview.title.${id}`}>
      <Label
        className="labview-handle"
        icon={icon}
        label={label || context.label}
        title={title || context.title}
      />
      {children}
    </DefineElement>
  );
};

// --------------------------------------------------------------------------
// --- Grid Item
// --------------------------------------------------------------------------

const GRIDITEM = {
  className: 'dome-container dome-xBoxes-vbox dome-xBoxes-box',
  handle: '.labview-handle',
  resize: 'both',
  fill: 'none',
  shrink: 'none',
  minWidth: 40,
  minHeight: 40,
  width: 120,
  height: 120,
};

const GRIDITEM_PLAIN = { fill: 'both' };
const GRIDITEM_HPANE = { fill: 'horizontal' };
const GRIDITEM_VPANE = { fill: 'vertical' };

const makeGridItem = (customize: any, onClose: any) => (comp: any) => {
  const { id: libId, label, title, layout = 'PLAIN', children } = comp;
  const id = getItemId('components', libId);
  let properties: any = { ...GRIDITEM };
  switch (layout) {
    case 'PLAIN':
      properties = { ...properties, ...GRIDITEM_PLAIN };
      break;
    case 'HPANE':
      properties = { ...properties, GRIDITEM_HPANE };
      break;
    case 'VPANE':
      properties = { ...properties, GRIDITEM_VPANE };
      break;
    default:
      console.warn(`[labviews] unexpected layout for ${id} component`, layout);
      break;
  }
  Object.keys(properties).forEach((key) => {
    const prop = comp[key];
    if (prop) properties[key] = prop;
  });
  let CLOSING;
  if (customize) {
    CLOSING = (
      <IconButton
        className="labview-close"
        offset={-1}
        icon="CROSS"
        onClick={() => onClose(id)}
      />
    );
  }
  return (
    <Grids.GridItem
      id={id}
      className={properties.className}
      handle={properties.handle}
      resize={properties.resize}
      fill={properties.fill}
      shrink={properties.shrink}
      minWidth={properties.minWidth}
      minHeight={properties.minHeight}
      width={properties.width}
      height={properties.height}
    >
      <Vfill className="labview-content">
        <Hbox className="labview-titlebar">
          <Hfill>
            <Catch label={id}>
              <RenderElement id={`labview.title.${id}`}>
                <Label className="labview-handle" label={label} title={title} />
              </RenderElement>
            </Catch>
          </Hfill>
          {CLOSING}
        </Hbox>
        <TITLE.Provider value={{ id, label, title }}>
          <Catch label={id}>{children}</Catch>
        </TITLE.Provider>
      </Vfill>
    </Grids.GridItem>
  );
};

// --------------------------------------------------------------------------
// --- Customization Views
// --------------------------------------------------------------------------

function CustomViews({ settings, shape, setShape, views: libViews }: any) {
  const [local, setLocal] = Settings.useWindowSettings(
    settings, Json.jObj, {},
  ) as any;
  const [customs, setCustoms] = Settings.useLocalStorage(
    'frama-c.labview', Json.jObj, {},
  );
  const [edited, setEdited]: any = React.useState();
  const triggerDefault = React.useRef();
  const { current, shapes = {} } = local;
  const theViews: any = {};

  _.forEach(libViews, (view) => {
    const {
      id: origin,
      order,
      label = '(Stock View)',
      title, defaultView,
    } = view;
    const id = `builtin.${origin}`;

    theViews[id] =
      { id, order, label, title, builtin: true, defaultView, origin };
  });

  _.forEach(customs as any, (view) => {
    const { id, order, label = '(Custom View)', title, origin } = view;
    if (id && !theViews[id]) {
      theViews[id] = { id, order, label, title, builtin: false, origin };
    }
  });

  const getStock = (origin: any) => (
    (origin
      && _.find(libViews, (v) => v.id === origin))
    || _.find(libViews, (v) => v.defaultView)
    || libViews[0]
  );

  const getDefaultShape = (view: any) => {
    const stock = getStock(view && view.origin);
    return stock && Grids.makeChildrenShape(stock.children);
  };

  const SELECT = (id: string) => {
    if (id && current !== id) {
      if (current) shapes[current] = shape;
      setLocal({ current: id, shapes });
      setShape(shapes[id] || getDefaultShape(theViews[id]));
    }
  };

  const POPUP = (id: string) => {
    const view = theViews[id];
    if (!view) return;
    const isCurrent = current === id;
    const isCustom = !view.builtin;

    const DEFAULT = () => {
      shapes[id] = undefined;
      setLocal({ current: id, shapes });
      setShape(getDefaultShape(view));
    };

    const RENAME = () => setEdited(id);

    const DUPLICATE = () => {
      const base = `custom.${view.origin}`;
      const stock = getStock(view.origin);
      let k = 1;
      let newId = base;
      while (theViews[newId]) {
        k += 1;
        newId = `${base}~${k}`;
      }
      let newOrder = view.order;
      if (newOrder && newOrder.concat) newOrder = newOrder.concat([k]);
      let newLabel = `Custom ${stock.label}`;
      if (k > 1) newLabel += `~${k}`;
      customs[newId] = {
        id: newId,
        label: newLabel,
        order: newOrder,
        title: `Derived from ${stock.label}`,
        origin: view.origin,
        builtin: false,
      };
      setCustoms(customs);
      if (current) shapes[current] = shape;
      setLocal({ current: newId, shapes });
      setEdited(newId);
    };

    const REMOVE = () => {
      delete customs[id];
      delete shapes[id];
      setCustoms(customs);
      const newCurrent = current === id ? undefined : current;
      setLocal({ current: newCurrent, shapes });
    };

    Dome.popupMenu([
      { label: 'Rename View', display: (!edited && isCustom), onClick: RENAME },
      { label: 'Restore Default', display: isCurrent, onClick: DEFAULT },
      { label: 'Duplicate View', onClick: DUPLICATE },
      'separator',
      { label: 'Remove View', display: isCustom, onClick: REMOVE },
    ]);
  };

  const makeViewItem = ({ id, label, title, builtin }: any) => {
    if (edited === id) {
      const RENAMED = (newLabel: string) => {
        if (newLabel) {
          const custom = Json.jObj(customs[id]) || {};
          if (custom) custom.label = newLabel;
          setCustoms(customs);
        }
        setEdited(undefined);
      };
      const FIELD = (
        <Field
          className="labview-field"
          placeholder="View Name"
          autoFocus
          value={label}
          title={title}
          onChange={RENAMED}
        />
      );
      return (
        <Item key={id} icon="DISPLAY">
          {FIELD}
        </Item>
      );
    }
    const FLAGS = [];
    if (builtin) FLAGS.push('LOCK');
    return (
      <Item
        key={id}
        icon="DISPLAY"
        label={label}
        title={title}
        selected={id && current === id}
        onSelection={() => SELECT(id)}
        onContextMenu={() => POPUP(id)}
      >
        {FLAGS.map((icn) => (
          <Icon
            key={icn}
            className="labview-icon"
            size={9}
            offset={1}
            id={icn}
          />
        ))}
      </Item>
    );
  };

  if (!current && !triggerDefault.current) {
    const theDefault = _.find(theViews, (item) => item.defaultView);
    triggerDefault.current = theDefault;
    if (theDefault) setTimeout(() => { SELECT(theDefault.id); });
  }

  return (
    <Section label="Views" defaultUnfold>
      {_.sortBy(theViews, ['order', 'id']).map(makeViewItem)}
    </Section>
  );
}

// --------------------------------------------------------------------------
// --- Customization Components
// --------------------------------------------------------------------------

const DRAGOVERLAY = { className: 'labview-stock' };

function CustomGroup({
  settings,
  dnd, shape, setDragging,
  id: sectionId,
  title: sectionTitle,
  label: sectionLabel,
  components,
}: any) {
  const makeComponent = ({ id, label, title }: any) => {
    const itemId = getItemId('components', id);
    const disabled = Grids.getShapeItem(shape, itemId) !== undefined;
    return (
      <DragSource
        key={id}
        dnd={dnd}
        disabled={disabled}
        overlay={disabled ? undefined : DRAGOVERLAY}
        onStart={() => setDragging(itemId)}
      >
        <Item
          icon="COMPONENT"
          disabled={disabled}
          label={label}
          title={title}
        />
      </DragSource>
    );
  };
  return (
    <Section
      key={sectionId}
      settings={settings && `${settings}.${sectionId}`}
      label={sectionLabel}
      title={sectionTitle}
      defaultUnfold={sectionId === 'groups.frama-c'}
    >
      {components.map(makeComponent)}
    </Section>
  );
}

// --------------------------------------------------------------------------
// --- Customization Panel
// --------------------------------------------------------------------------

function CustomizePanel(
  { dnd, settings, library, shape, setShape, setDragging }: any,
) {
  Dome.useUpdate(UPDATE);
  const { items } = library;
  const views = getItems(items, 'views');
  const groups = getItems(items, 'groups');
  const components = getItems(items, 'components');
  const settingFolds = settings && `${settings}.folds`;
  const settingViews = settings && `${settings}.views`;
  const contents: any = {};

  groups.unshift({ id: 'nogroup', label: 'Components' });
  groups.forEach((g) => (contents[g.id] = []));

  components.forEach((c) => {
    const gid = c.group ? `groups.${c.group}` : 'nogroup';
    let content = contents[gid];
    if (content === undefined) content = contents.nogroup;
    content.push(c);
  });

  return (
    <SideBar>
      <CustomViews
        key="views"
        settings={settingViews}
        shape={shape}
        setShape={setShape}
        views={views}
      />
      {groups.map((g) => (
        <CustomGroup
          settings={settingFolds}
          key={g.id}
          id={g.id}
          label={g.label}
          title={g.title}
          dnd={dnd}
          setDragging={setDragging}
          shape={shape}
          components={contents[g.id]}
        />
      ))}
    </SideBar>
  );
}

// --------------------------------------------------------------------------
// --- LabView Container
// --------------------------------------------------------------------------

/**
   @summary Reconfigurable Container (React Component).
   @property {boolean} [customize] - show components panel (false by default)
   @property {string} [settings] - window settings to make views persistent
   @property {React.Children} children - the labview content
   @description
   This container displays its content into a reconfigurable view.

   The entire content is rendered, but elements must be packed into
   `<Component/>` containers, otherwise, they would remain invisible.
   Content may also contains `<View/>` and `<Group/>` definitions, and the
   content can be defined through any kind of React components.
 */
export function LabView(props: any) {
  // Parameters
  const { settings, customize = false, children } = props;
  const settingSplit = settings && `${settings}.split`;
  const settingShape = settings && `${settings}.shape`;
  const settingPanel = settings && `${settings}.panel`;
  // Hooks & State
  Dome.useUpdate(
    UPDATE,
    Dome.windowSettings,
    Dome.globalSettings,
  );
  const dnd = React.useMemo(() => new DnD(), []);
  const lib = useLibrary();
  const [shape, setShape] =
    Settings.useWindowSettings(settingShape, Json.jAny, undefined);
  const [dragging, setDragging] = React.useState();
  // Preparation
  const onClose =
    (id: string) => setShape(Grids.removeShapeItem(shape, id));
  const components =
    _.filter(lib.collection, (item: any) => isItemId('components', item.id));
  const gridItems =
    components.map(makeGridItem(customize, onClose));
  const holding =
    dragging ? gridItems.find((elt) => elt.props.id === dragging) : undefined;
  // Make view
  return (
    <>
      <UseLibrary>
        {children}
      </UseLibrary>
      <RSplit margin={120} settings={settingSplit} unfold={customize}>
        <Grids.GridLayout
          dnd={dnd}
          padding={2}
          className="labview-container"
          items={gridItems}
          shape={shape}
          onReshape={setShape}
          holding={holding}
        />
        <CustomizePanel
          dnd={dnd}
          settings={settingPanel}
          shape={shape}
          setShape={setShape}
          setDragging={setDragging}
          library={lib}
        />
      </RSplit>
    </>
  );
}

// --------------------------------------------------------------------------
