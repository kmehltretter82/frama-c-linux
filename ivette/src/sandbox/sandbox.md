# Sandbox

The sandbox part of Ivette is only available in development mode.
It allows you to test new modules and discover a simplified form of the basic modules before using them.

## Dot Diagram

Documentation is not yet available for this module.

## ForceGraph

Documentation is not yet available for this module.

## Icons

Documentation is not yet available for this module.

## Panel

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


## Qsplit

Documentation is not yet available for this module.

## Text

Documentation is not yet available for this module.

## UseDnd

Documentation is not yet available for this module.

## Help

the documentation is written in [Markdown](#markdown). It must be in a `*.md` file, the raw content of which will be retrieved via an import.

For example, for the documentation of a sandbox module
``` javascript
import docSandbox from './sandbox.md?raw';
```
Here, `?raw` is used to indicate that we want the raw content of the file.

Typically, the documentation will be displayed in the application's modal.

### help.tsx

This file contains components that make it easier to display documentation in your components.

#### HelpMarkdown

This component is used to display the markdown help, it is used by `IconodalMd` and you can see an example of it out of modal in the `help` sandbox.
It takes the following props:
``` javascript
interface DocMarkdownProps {
  /** classes for Doc component */
  className?: string;
  /** Tab of patterns */
  patterns?: Pattern[];
  /**
   * scroll to title h1 or h2 when component is render.
   * The value must be the id of the balise html.
   * Id is calculate by title.toLowerCase().replaceAll(' ','-')
   * where title is the content of h1 or h2 if it is a string
  */
  initialScrollTo?: string;
  /** Markdown content. */
  children?: string;
}
```

#### IconModalMd

Allows you to add a `HELP` icon ([icon-HELP]) which will open a modal window with the chosen document when clicked.

``` javascript
interface IconModalMdProps extends DocMarkdownProps {
  /** Icon props */
  kind?: IconButtonKind;
  title?: string;
  size?: number;
  /** Properties of Modal component */
  modal: Omit<ModalProps, 'children'>;
}
```


## Markdown

TO BE COMPLETED

### Pattern
You can used patterns to replace parts of the text by JSX Element.

#### Icons

There is one basic pattern to replace tags by an `Icon`, it name `iconTag`  in markdown component .

* [icon-TUNINGS] : [ex:][icon-TUNINGS]
* [icon-TARGET] : [ex:][icon-TARGET]
* [icon-PIN] : [ex:][icon-PIN]

or inline [icon-TUNINGS], [icon-TARGET], [icon-PIN]
