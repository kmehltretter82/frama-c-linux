// --------------------------------------------------------------------------
// ---  Lab View Component
// --------------------------------------------------------------------------

/** @module frama-c/labviews */

import _ from 'lodash';
import React from 'react';
import * as Dome from 'dome';
import { Catch } from 'dome/errors';
import { DnD, DragSource } from 'dome/dnd';
import { SideBar, Section, Item } from 'dome/frame/sidebars';
import { Splitter } from 'dome/layout/splitters';
import * as Grids from 'dome/layout/grids';
import { Hbox, Hfill, Vfill } from 'dome/layout/boxes';
import { IconButton, Field } from 'dome/controls/buttons';
import { Label } from 'dome/controls/labels';
import { Icon } from 'dome/controls/icons';
import {
  Item as ItemToRender,
  Render as RenderItem,
} from 'dome/layout/dispatch';

import './style.css';

// --------------------------------------------------------------------------
// --- Library
// --------------------------------------------------------------------------

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
      Dome.emit('labview.library');
    }
  }

  useItem(
    id: string,
    gcontext: any,
    path: any[],
    props: { rank: undefined; group: any },
  ) {
    if (!this.modified) {
      this.modified = true;
      setImmediate(() => this.commit());
    }
    if (!id) return undefined;
    const order = props.rank === undefined
      ? path
      : path.slice(0, -1).concat([props.rank]);
    const group = props.group || gcontext;
    const collection: any = this.virtual;
    collection[id] = { id, order, group, ...props };
    return (): boolean => delete collection[id];
  }
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

const LibraryManager = React.createContext(undefined);

const useLibraryItem = (fd: string, { id, ...props }: any) => {
  const context = React.useContext(LibraryManager);
  React.useEffect(() => {
    if (context) {
      const { group, order, library }: any = context;
      const itemId = `${fd}.${id}`;
      return library.useItem(itemId, group, order, props);
    }
    return undefined;
  });
  return context;
};

const Rankify =
  ({ library, group, order, children }: any) => {
    let rank = 0;
    const rankify = (elt: any) => {
      rank += 1;
      const context: any = { group, order: [...order, rank], library };
      return (
        <LibraryManager.Provider value={context}>
          {elt}
        </LibraryManager.Provider>
      );
    };
    return (
      <>
        {React.Children.map(children, rankify)}
      </>
    );
  };

const HIDDEN = { display: 'none' };

const UseLibrary = ({ library, children }: any) => (
  <div style={HIDDEN}>
    <Rankify library={library} order={[]}>
      {children}
    </Rankify>
  </div>
);

/**
   @summary Ordered collection of LabView Components.
   @description
   Renderers its children in the specified order.
   Otherwise, elements are ordered by `rank` and `id`.
 */
export const Fragment = ({ group, children }: any) => {
  const context: any = React.useContext(LibraryManager);

  if (!context) return null;

  return (
    <Rankify
      group={group || context.group}
      order={context.order}
      library={context.library}
    >
      {children}
    </Rankify>
  );
};

/**
   @summary Group of LabView Components.
   @property {string} id - group identifier
   @property {string} label - displayed name
   @property {string} [title] - description tooltip
   @property {React.Children} [children] - group content
   @description
   Defines a group of components. The components rendered
   _inside_ its content are implicitely affected to this group,
   unless specified. The group content are also rendered
   in their specified order. For nested collections of components,
   use `<Fragment/>` instead of `<React.Fragment/>` to specify order.
 */
export const Group = ({ children, ...props }: any) => {
  const context: any = useLibraryItem('groups', props);
  return (
    <Rankify
      group={props.id}
      order={context.order}
      library={context.library}
    >
      {children}
    </Rankify>
  );
};

// --------------------------------------------------------------------------
// --- Views
// --------------------------------------------------------------------------

/**
   @summary Layout of LabView Components.
   @property {string} id - view identifier
   @property {string} label - displayed name
   @property {string} [title] - description tooltip
   @property {boolean} [defaultView] - use this view by default
   @property {GridContent} children - grid content of the view
   @description
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
export const View = (props: any) => {
  useLibraryItem('views', props);
  return null;
};

// --------------------------------------------------------------------------
// --- Components
// --------------------------------------------------------------------------

/**
   @summary LabView Component.
   @property {string} id - component identifier
   @property {string} label - displayed name
   @property {number} [rank] - ordering index
   @property {string} [group] - attachment group
   @property {string} [title] - description tooltip
   @property {React.Children} children - component rendering elements
   @description
   Defines a component and its content when incorporated inside a view.
   Unless specified, the component will be implicitely attached
   to the current enclosing group. The `rank` property can be used
   for adjusting component ordering (see also `<Fragment/>` and `<Group/>`).
 */
export const Component = (props: any) => {
  useLibraryItem('components', props);
  return null;
};

const TitleContext: any = React.createContext(undefined);

/**
   @summary LabView Component's title bar.
   @property {string} [icon] - displayed icon
   @property {string} [label] - displayed name
   @property {string} [title] - description tooltip
   @property {React.Children} children - additional components to render
   @description
   Defines an alternative component title bar.
   If specified, the icon, label and title properties are rendered in an
   `<Label/>` component.
   By default, the component title bar is labelled according to the component
   properties.
 */
export const TitleBar = ({ icon, label, title, children }: any) => {
  const context: any = React.useContext(TitleContext);
  return (
    <ItemToRender id={`labview.title.${context.id}`}>
      <Label
        className="labview-handle"
        icon={icon}
        label={label || context.label}
        title={title || context.title}
      />
      {children}
    </ItemToRender>
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
            <Catch title={id}>
              <RenderItem id={`labview.title.${id}`}>
                <Label className="labview-handle" label={label} title={title} />
              </RenderItem>
            </Catch>
          </Hfill>
          {CLOSING}
        </Hbox>
        <TitleContext.Provider value={{ id, label, title }}>
          <Catch title={id}>{children}</Catch>
        </TitleContext.Provider>
      </Vfill>
    </Grids.GridItem>
  );
};

// --------------------------------------------------------------------------
// --- Customization Views
// --------------------------------------------------------------------------

function CustomViews({ settings, shape, setShape, views: libViews }: any) {
  const [local, setLocal] = Dome.useState(settings, {});
  const [customs, setCustoms] = Dome.useGlobalSetting(settings, {});
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

  _.forEach(customs, (view) => {
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
          const custom = customs[id];
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
          onEnter={RENAMED}
        />
      );
      return (
        <Item key={id} id={id} icon="DISPLAY" title={title} label={FIELD} />
      );
    }
    const FLAGS = [];
    if (builtin) FLAGS.push('LOCK');
    return (
      <Item
        key={id}
        id={id}
        icon="DISPLAY"
        label={label}
        title={title}
        selected={id && current === id}
        onSelection={SELECT}
        onContextMenu={POPUP}
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
    <Section label="Views">
      {_.sortBy(theViews, ['order', 'id']).map(makeViewItem)}
    </Section>
  );
}

// --------------------------------------------------------------------------
// --- Customization Components
// --------------------------------------------------------------------------

const DRAGOVERLAY = { className: 'labview-stock' };

function CustomGroup(
  { dnd, shape, setDragging, id, title, label, components }: any,
) {
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
    <Section id={id} label={label} title={title}>
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
  Dome.useUpdate('labview.library');
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
    <SideBar settings={settingFolds}>
      <CustomViews
        key="views"
        settings={settingViews}
        shape={shape}
        setShape={setShape}
        views={views}
      />
      {groups.map((g) => (
        <CustomGroup
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
  Dome.useUpdate('labview.library', 'dome.defaults');
  const dnd = React.useMemo(() => new DnD(), []);
  const lib = React.useMemo(() => new Library(), []);
  const [shape, setShape] = Dome.useState(settingShape);
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
      <UseLibrary library={lib}>
        {children}
      </UseLibrary>
      <Splitter settings={settingSplit} unfold={customize} dir="RIGHT">
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
      </Splitter>
    </>
  );
}

// --------------------------------------------------------------------------
