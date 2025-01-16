# Sandbox {#help-sandbox}

The sandbox part of Ivette is only available in development mode.
It allows you to test new modules and discover a simplified form of the basic modules before using them.

## Dot Diagram {#sandbox-dot-diagram}

Documentation is not yet available for this module.

## ForceGraph {#sandbox-forcegraph}

Documentation is not yet available for this module.

## Icons {#sandbox-icons}

Documentation is not yet available for this module.

## Panel {#sandbox-panel}

The Panel component allows the addition of a retractable panel to a positioned block.

The panel can be displayed on any side of the block using the position prop, which defaults to the right. The visible prop allows hiding or showing the panel.

### Props
 ``` javascript
 export type PanelPosition = 'top' | 'bottom' | 'left' | 'right';

 interface PanelProps {
  /** Additional class. */
  className?: string;
  /** Position to displayed the panel. Default 'tr' */
  position?: PanelPosition;
  /** Defaults to `true`. */
  visible?: boolean;
  /** Defaults to `true`. */
  display?: boolean;
  /** Panel children. */
  children: JSX.Element[];
}
```


## Qsplit {#sandbox-qsplit}

Documentation is not yet available for this module.

## Text {#sandbox-text}

Documentation is not yet available for this module.

## UseDnd {#sandbox-usednd}

Documentation is not yet available for this module.

## Help {#sandbox-help}
the documentation is written in [Markdown](#sandbox-markdown). It must be in a `*.md` file, the raw content of which will be retrieved via an import.

For example, for the documentation of a sandbox module
``` javascript
import docSandbox from './sandbox.md?raw';
```
Here, `?raw` is used to indicate that we want the raw content of the file.

Typically, the documentation will be displayed in the application's modal.

### help.tsx

This file contains components that make it easier to display documentation in your components.

#### HelpIcon

Allows you to add a `HELP` icon ([icon-HELP]) which will open a modal window with the chosen document when clicked.

``` javascript
interface HelpIconProps {
  /** icon size */
  size?: number;
  /** Tab of patterns */
  patterns?: Pattern[];
  /** Initial scroll to the chosen id */
  scrollTo?: string;
  /** Text of the label. Prepend to other children elements. */
  label: string;
  /** Function onClose */
  onClose?: () => void
  /** children */
  children: string;
}
```


## Markdown {#sandbox-markdown}

TO BE COMPLETED

### Pattern
You can used patterns to replace parts of the text by JSX Element.

#### Icons

There is one basic pattern to replace tags by an `Icon`, it name `iconTag`  in markdown component .

* [icon-tunings] : `[icon-tunings]`
* [icon-tunings-#ff0000] : `[icon-tunings-#ff0000]`
* [icon-target] : `[icon-target]`
* [icon-pin] : `[icon-pin]`

or inline [icon-tunings], [icon-target], [icon-pin]
