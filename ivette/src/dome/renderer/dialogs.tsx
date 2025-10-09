/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

/**
   Various kind of (modal) dialogs attached to the main application window.
   @packageDocumentation
   @module dome/dialogs
 */

import React from 'react';
import ReactDOM from "react-dom";
import * as filepath from 'path';
import { ipcRenderer } from 'electron';
import { modal } from 'dome';
import * as System from 'dome/system';
import { classes, styles } from 'dome/misc/utils';
import { Label } from './controls/labels';
import { IconButton } from './controls/buttons';
import { GlobalState, useGlobalState } from './data/states';
import { Icon } from './controls/icons';

// --------------------------------------------------------------------------
// --- Message Box
// --------------------------------------------------------------------------

export interface DialogButton<A> {
  label?: string;
  value?: A;
}

const defaultItems: DialogButton<boolean>[] = [
  { value: undefined },
  { value: true, label: 'Ok' },
];

const valueLabel = (v: unknown): string => {
  switch (v) {
    case undefined: return 'Cancel';
    case true: return 'Ok';
    case false: return 'No';
    default: return `${v}`;
  }
};

const itemLabel = ({ value, label }: DialogButton<unknown>): string => (
  (label || valueLabel(value))
);

const isDefault = ({ value, label }: DialogButton<unknown>): boolean => (
  (value === true || label === 'Ok' || label === 'Yes')
);

const isCancel = ({ value, label }: DialogButton<unknown>): boolean => (
  (!value || label === 'Cancel' || label === 'No')
);

export type MessageKind = 'none' | 'info' | 'error' | 'warning';

export interface MessageProps<A> {
  /** Block the interface until the message window is closed
      (default is false) */
  block?: boolean;
  /** Dialog window icon (default is `'none'`. */
  kind?: MessageKind;
  /** Message text (short sentence). */
  message: string;
  /** Message details (short sentence). */
  details?: string;
  /** Message buttons. */
  buttons?: DialogButton<A>[];
  /** Default button's value. */
  defaultValue?: A;
  /** Cancel value. */
  cancelValue?: A;
}

/**
   Show a configurable message box.

   The returned promise object is never rejected, and is resolved into:
   - the cancel value if the cancel key is pressed,
   - the default value if the enter key is pressed,
   - or the value of the clicked button otherwised.

   The promise is asynchronously resolved by default.
   For synchronous resolution, you need to use the `block` option.

   The default buttons are `"Ok"` and `"Cancel"` associated to values `true` and
   `undefined`, which are also associated to the enter and cancel keys.
   Unless specified, the default value is associated with the first button
   with 'true' value or 'Ok' or 'Yes' label,
   and the cancel value is the first button with a falsy value or 'Cancel'
   or 'No' label.
 */
export async function showMessageBox<A>(
  props: MessageProps<A>,
): Promise<A | boolean | undefined> {
  const {
    block,
    kind,
    message,
    details,
    defaultValue,
    cancelValue,
    buttons = (defaultItems as DialogButton<A | boolean>[]),
  } = props;

  const labels = buttons.map(itemLabel);
  const defaultId =
    defaultValue === undefined
      ? buttons.findIndex(isDefault)
      : buttons.findIndex((a) => a.value === defaultValue);
  let cancelId =
    cancelValue === undefined
      ? buttons.findIndex(isCancel)
      : buttons.findIndex((a) => a.value === cancelValue);

  if (cancelId === defaultId) cancelId = -1;
  const options = {
      type: kind,
      message,
      detail: details,
      defaultId,
      cancelId,
      buttons: labels,
    };

  if(block) return ipcRenderer.invoke('dome.dialog.showMessageBoxSync', options)
    .then((result) => result ? buttons[result].value : cancelValue);

  return ipcRenderer.invoke('dome.dialog.showMessageBox', options)
    .then((result) => {
      const itemIndex = result ? result.response : -1;
      return itemIndex ? buttons[itemIndex].value : cancelValue;
    });
}

// --------------------------------------------------------------------------
// --- File Dialogs
// --------------------------------------------------------------------------

const defaultPath =
  (path: string): string =>
    (filepath.extname(path) ? filepath.dirname(path) : path);

export interface FileFilter {
  /** Filter name. */
  name: string;
  /**
     Allowed extensions, _without_ dot.
     Use `['*']` to accept all files.
   */
  extensions: string[];
}

export interface FileDialogProps {
  /** Prompt message. */
  title?: string;
  /** Open button label (default is « Open »). */
  label?: string;
  /** Initially selected path. */
  path?: string;
}

export interface SaveFileProps extends FileDialogProps {
  /** File filters (default to all). */
  filters?: FileFilter[];
}

export interface OpenFileProps extends SaveFileProps {
  /** Show hidden files (default is `false`). */
  hidden?: boolean;
}

export interface OpenDirProps extends FileDialogProps {
  /** Show hidden directories (default is `false`). */
  hidden?: boolean;
}

// --------------------------------------------------------------------------
// --- openFile dialog
// --------------------------------------------------------------------------

/**
   Show a dialog for opening file.
   A file filter with `extensions:["*"]` would accept any file extension.

   The returned promise object will be asynchronously:
   - either _resolved_ with `undefined` if no file has been selected,
   - or _resolved_ with the selected path

   The promise is never rejected.
 */
export async function showOpenFile(
  props: OpenFileProps,
): Promise<string | undefined> {
  const { title, label, path, hidden = false, filters } = props;
  return ipcRenderer.invoke('dome.dialog.showOpenDialog',
    {
      title,
      buttonLabel: label,
      defaultPath: path && defaultPath(path),
      properties: (hidden ? ['openFile', 'showHiddenFiles'] : ['openFile']),
      filters,
    },
  ).then((result) => {
    if (!result.canceled && result.filePaths && result.filePaths.length > 0)
      return result.filePaths[0];
    return undefined;
  });
}

/**
   Show a dialog for opening files multiple files.
*/
export async function showOpenFiles(
  props: OpenFileProps,
): Promise<string[] | undefined> {
  const { title, label, path, hidden, filters } = props;

  return ipcRenderer.invoke('dome.dialog.showOpenDialog',
    {
      title,
      buttonLabel: label,
      defaultPath: path && defaultPath(path),
      properties: (
        hidden
          ? ['openFile', 'multiSelections', 'showHiddenFiles']
          : ['openFile', 'multiSelections']
      ),
      filters,
    },
  ).then((result) => {
    if (!result.canceled && result.filePaths && result.filePaths.length > 0)
      return result.filePaths;
    return undefined;
  });
}

// --------------------------------------------------------------------------
// --- saveFile dialog
// --------------------------------------------------------------------------

/**
   Show a dialog for saving file.

   The returned promise object will be asynchronously:
   - either _resolved_ with `undefined` when canceled,
   - or _resolved_ with the selected (single) path.

   The promise is never rejected.
*/
export async function showSaveFile(
  props: SaveFileProps,
): Promise<string | undefined> {
  const { title, label, path, filters } = props;
  return ipcRenderer.invoke('dome.dialog.showSaveDialog',
    {
      title,
      buttonLabel: label,
      defaultPath: path,
      filters,
    },
  ).then(({ canceled, filePath }) => (canceled ? undefined : filePath));
}

// --------------------------------------------------------------------------
// --- openDir dialog
// --------------------------------------------------------------------------

type openDirProperty =
  'openDirectory' | 'showHiddenFiles' | 'createDirectory' | 'promptToCreate';

/**
   Show a dialog for selecting directories.
 */
export async function showOpenDir(
  props: OpenDirProps,
): Promise<string | undefined> {
  const { title, label, path, hidden } = props;
  const properties: openDirProperty[] = ['openDirectory'];
  if (hidden) properties.push('showHiddenFiles');

  switch (System.platform) {
    case 'macos': properties.push('createDirectory'); break;
    case 'windows': properties.push('promptToCreate'); break;
    default: break;
  }

  return ipcRenderer.invoke('dome.dialog.showOpenDialog',
    {
      title,
      buttonLabel: label,
      defaultPath: path,
      properties,
    },
  ).then((result) => {
    if (!result.canceled && result.filePaths && result.filePaths.length > 0)
      return result.filePaths[0];
    return undefined;
  });
}

// --------------------------------------------------------------------------
// --- Modal
// --------------------------------------------------------------------------

export const modalLoader = new GlobalState<boolean>(false);

/**
 * ShowModal defines the content of the modal.
 * If the current modal has an onClose() function,
 * it will be called before the update.
 * The return value of onClose() can prevents the update from happening.
 */
export async function showModal(
  content: React.ReactNode,
  onClose?: () => boolean | Promise<boolean>
): Promise<void> {
  const setModal = (): void => {
    modalLoader.setValue(false);
    modal.setValue({ content, onClose });
  };

  const current = modal.getValue();
  if(current !== undefined && current.onClose) {
    const closeModal = await current.onClose();
    if(closeModal) setModal();
  } else setModal();
}
export function closeModal(): void { showModal(undefined); }

export interface ModalProps {
  /** Text of the label. Prepend to other children elements. */
  label: string;
  /** Icon identifier. Displayed on the left side of the label. */
  icon?: string;
  /** Tool-tip description. */
  title?: string;
  /** custom Classes name */
  className?: string;
  /** Actions */
  actions?: React.JSX.Element;
  /** Function onClose */
  onClose?: () => void
  /** More style */
  style?: React.CSSProperties;
  /** Modal content */
  children: JSX.Element;
}

export function Modal(
  props: ModalProps
): JSX.Element {
  const { label, title, icon, className,
    onClose, style, actions, children } = props;
  const [ isLoader, ] = useGlobalState(modalLoader);

  const contentClasses = classes('dome-xModal-content', className);
  const onCloseModal = React.useCallback((): void => {
    closeModal();
    if(onClose) onClose();
  }, [onClose]);

  React.useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      if (event.key === "Escape") onCloseModal();
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [onCloseModal]);

  return (
    <div className={contentClasses} style={style}>
      <div className='dome-xModal-header'>
        <Label className='dome-xModal-title'
          label={label} icon={icon} title={title}
        />
        <div className='dome-xModal-actions'>
          { actions }
          <IconButton icon='CROSS' size={18} onClick={onCloseModal} />
        </div>
      </div>
      <div className='dome-xModal-body dome-xBoxes-vbox dome-xBoxes-box'>
        { isLoader &&
          <div className='dome-xModal-loader'>
            <Icon id='SPINNER' size={30}/>
          </div>
        }
        {children}
      </div>
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Popup
// --------------------------------------------------------------------------

interface PopupProps {
  position: { top: number, left:number } | null;
  popupRef: React.RefObject<HTMLDivElement>;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}

// The popup is rendered in the body via the createportal function.
function Popup(props: PopupProps): JSX.Element | null {
  const { position, popupRef, style, children } = props;

  const stylePopup = styles(
    { top: position?.top, left: position?.left },
    style && { ...style }
  );

  if(children === undefined) return null;
  return ReactDOM.createPortal(
    <div
      ref={popupRef}
      className="dome-xPopup"
      style={stylePopup}
    >{children}</div>,
    document.body
  );
}

// --------------------------------------------------------------------------
// --- Dropdown
// --------------------------------------------------------------------------

/**
 *  Hook to track the position of the element targeted by targetRef
 */
function useElementRect(
  targetRef: React.RefObject<HTMLElement>
): DOMRect | undefined {
  const [position, setPosition] = React.useState<DOMRect>();

  React.useEffect(() => {
    if (!targetRef.current) {
      setPosition(undefined);
      return;
    }
    const trigger = targetRef.current;

    const update = (): void => {
      const rect = trigger.getBoundingClientRect();
      setPosition(rect);
    };
    update();

    window.addEventListener("scroll", update, true);
    window.addEventListener("resize", update);

    const resizeObserver = new ResizeObserver(update);
    resizeObserver.observe(trigger);

    let node: HTMLElement | null = trigger.parentElement;
    while (node) {
      resizeObserver.observe(node);
      node = node.parentElement;
    }

    return () => {
      window.removeEventListener("scroll", update, true);
      window.removeEventListener("resize", update);
      resizeObserver.disconnect();
    };
  }, [targetRef]);

  return position;
}

function useWindowSize(): {width: number, height: number} {
  const [size, setSize] = React.useState({
    width: window.innerWidth,
    height: window.innerHeight
  });

  React.useEffect(() => {
    const handleResize = (): void => {
      setSize({
        width: window.innerWidth,
        height: window.innerHeight
      });
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return size;
}

type Position = { top: number; left: number };
const defaultPos = { top: 0, left: 0 };
/**
 *  Hook to calc the position of the dropdown top-left corner
 */
function useDropdownPosition(
  popupRef: React.RefObject<HTMLElement>,
  controlRef: React.RefObject<HTMLElement>,
  askToOpen: boolean
): Position {
  const controlRect = useElementRect(controlRef);
  const windowSize = useWindowSize();
  const [position, setPosition] = React.useState<Position>(defaultPos);

  React.useEffect(() => {
    const controlElt = controlRef.current;
    const popupElt = popupRef.current;
    const rect = controlElt?.getBoundingClientRect();

    if(!askToOpen || !rect || !controlElt) setPosition(defaultPos);
    else {
      const topElement = document.elementFromPoint(
        rect.left + rect.width / 2,
        rect.top + rect.height / 2
      );
      const isCovered = Boolean(
        controlElt && !controlElt.contains(topElement) &&
        popupElt && !popupElt.contains(topElement)
      );
      const visible = !(
        rect.bottom <= 0
        || rect.top >= windowSize.height
        || rect.right <= 0
        || rect.left >= windowSize.width
      );
      if(!visible || isCovered) setPosition(defaultPos);
      else {
        /** The offset is used to prevent the dropdown from extending beyond
          * the right edge of the screen. */
        let offset = 0;
        if(popupElt) {
          const popupRect = popupElt.getBoundingClientRect();
          if(rect.left + popupRect.width > windowSize.width) {
            offset = rect.left + popupRect.width - windowSize.width;
          }
        }
        setPosition({ top: rect.bottom, left: rect.left-offset });
      }
    }
  }, [controlRect, controlRef, popupRef, windowSize, askToOpen]);

  return position;
}

export function useClickOutsideDropdown(
  refPopup: React.RefObject<HTMLElement>,
  refControl: React.RefObject<HTMLElement>,
  handler: (event: MouseEvent | TouchEvent) => void
): void {
  React.useEffect(() => {
    function handleClickOutside(event: MouseEvent | TouchEvent): void {
      if ( refPopup.current
        && !refPopup.current.contains(event.target as Node)
        && refControl.current
        && !refControl.current.contains(event.target as Node)
      ) handler(event);
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [refPopup, refControl, handler]);
}

interface DropdownProps {
  /** Control button */
  control: React.JSX.Element;
  /** Dropdown content */
  children: React.ReactNode;
}

/**
 * After requesting to open the drop-down menu,
 * it is opened in the background, the position is calculated,
 * and then the drop-down menu is brought to the foreground.
 */
export function Dropdown(props: DropdownProps): React.ReactNode {
  const { control, children } = props;
  const controlRef = React.useRef<HTMLDivElement>(null);
  const popupRef = React.useRef<HTMLDivElement>(null);

  /** Request to open the dropdown menu */
  const [ askToOpen, setAskToOpen] = React.useState(false);

  /**
   * Top-left corner position of the popup
   * return {top: 0, left: 0} if the popup must be hidden
   */
  const position = useDropdownPosition(popupRef, controlRef, askToOpen);

  const isDropdownOpen = React.useMemo(() => {
    return askToOpen && (position.left !== 0 || position.top !== 0);
  }, [askToOpen, position]);

  /**
   * The drop-down menu is hidden between the request and opening
   * because we need to see its dimensions.
   */
  const styleDropdown = styles(
    askToOpen && !isDropdownOpen && { zIndex: '-1' });

  /** Update the opening request if the position = {top: 0, left: 0} */
  React.useEffect(() => {
    if(position.left === 0 && position.top === 0) setAskToOpen(false);
  }, [position]);

  /** Close when clicked outside the dropdown */
  useClickOutsideDropdown(popupRef, controlRef, () => setAskToOpen(false));

  if(!children) return null;
  return <>
    <div ref={controlRef} style={{ display: 'flex', alignItems: 'center' }}>
      { React.cloneElement(control, {
        onClick: () => setAskToOpen((v) => !v),
        selected: askToOpen
        }) }
    </div>
    { askToOpen &&
      <Popup style={styleDropdown} popupRef={popupRef} position={position}
      >{ children }</Popup> }
  </>;
}

// --------------------------------------------------------------------------
