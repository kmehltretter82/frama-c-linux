import React from 'react';
import { EditorState, Extension } from '@codemirror/state';
import { RangeSet } from '@codemirror/state';
import { Decoration, DecorationSet, drawSelection } from '@codemirror/view';
import { EditorView, ViewPlugin, ViewUpdate } from '@codemirror/view';

import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Ast from 'frama-c/kernel/api/ast';
import { text } from 'frama-c/kernel/api/data';

import { registerSandbox } from 'ivette';

import './dark-code.css';



async function loadAST(func?: string): Promise<text> {
  try { return await Server.send(Ast.printFunction, func); }
  catch (err) { return `Failed with ${err}`; }
}

function toString(text: text): string {
  if (Array.isArray(text)) return text.slice(1).map(toString).join('');
  else if (typeof text === 'string') return text;
  else return 'Failed to convert text to string';
}



type Tree = { id?: string, from: number, to: number, children: Tree[] };

function textToTree(t: text, from: number): Tree | undefined {
  if (Array.isArray(t)) {
    const children = Array<Tree>();
    let acc = from;
    t.slice(1).forEach((child) => {
      const node = textToTree(child, acc);
      if (!node) return;
      acc = node.to;
      children.push(node);
    });
    if (children.length === 0) return undefined;
    const to = children[children.length - 1].to;
    const finalFrom = children[0].from;
    const id = typeof t[0] === 'string' && t[0][0] === '#' ? t[0] : undefined;
    return { id, from: finalFrom, to, children };
  }
  else if (typeof t === 'string')
    return { from, to: from + t.length, children: [] };
  else return undefined;
}

function findCoveringNode(tree: Tree, position: number): Tree | undefined {
  if (position < tree.from || position > tree.to) return undefined;
  if (position === tree.from) return tree;
  if (tree.children.length === 0) return tree;
  for (const child of tree.children) {
    const res = findCoveringNode(child, position);
    if (res) return res.id ? res : tree;
  }
  return tree;
}



function CodeDecorations(tree: Tree, fct?: string): Extension {

  // The different kind of decorations used in this extension.
  const hoveredClass = Decoration.mark({ class: 'cm-hovered-code' });
  const selectedClass = Decoration.mark({ class: 'cm-selected-code' });

  // This class contains the internal state used by the code decoration
  // extension to provide the correct decorations depending on the mouse
  // position and the selected elements.
  class CodeClass {
    hovered: Tree | undefined = undefined;
    selected: Tree[] = [];
    decorations: DecorationSet = RangeSet.empty;
    
    // Internal function used to recompute the decorations only when needed.
    computeDecorations(): void {
      const ranges = this.selected.map(s => selectedClass.range(s.from, s.to));
      const h = this.hovered;
      const add = h && [ hoveredClass.range(h.from, h.to) ];
      this.decorations = RangeSet.of(ranges).update({ add, sort: true });
    }

    // Update the decorations when the selection is modified.
    update(update: ViewUpdate): void {
      if (!update.selectionSet) return;
      this.selected = [];
      const meta = update.state.selection.ranges.length > 1;
      for (const selection of update.state.selection.ranges) {
        const covering = findCoveringNode(tree, selection.from);
        if (!covering || !covering.id) continue;
        this.selected.push(covering);
        const marker = Ast.jMarker(covering.id);
        States.setSelection({ fct, marker }, meta);
      }
      this.computeDecorations();
    }
  }

  // Build the code decorations extension. We provide a handler for the
  // mouse mouvements that updates the hovered tree node when needed.
  return ViewPlugin.fromClass(CodeClass, {
    decorations: v => v.decorations,
    eventHandlers: {
      mousemove: function (this, event, view) {
        const coords = { x: event.clientX, y: event.clientY };
        const position = view.posAtCoords(coords);
        this.hovered = undefined;
        if (!position) return false;
        const covering = findCoveringNode(tree, position);
        if (!covering || !covering.id) return false;
        this.hovered = covering;
        this.computeDecorations();
        view.dispatch();
        const marker = Ast.jMarker(covering.id);
        States.setHovered(marker ? { fct, marker } : undefined);
        return true;
      }
    }
  }).extension;
}



function Editor(): JSX.Element {

  // Creating the codemirror vue and binding it to the editor div
  const parent = React.useRef(null);
  const editor = React.useRef<EditorView | null>(null);
  const [baseExtensions] = React.useState<Extension[]>(() => {
    const multipleSelections = EditorState.allowMultipleSelections.of(true);
    const drawSelectionExt = drawSelection();
    return [multipleSelections, drawSelectionExt];
  });
  React.useEffect(() => {
    if (!parent.current) return;
    const state = EditorState.create({ extensions: baseExtensions });
    editor.current = new EditorView({ state, parent: parent.current });
  }, [parent, baseExtensions]);

  // State infos used to decide which function to print
  const printed = React.useRef<string | undefined>();
  const [selection] = States.useSelection();
  const fct = selection?.current?.fct;

  // Callback function called when the focused function changes
  const focusCallback = React.useCallback(async () => {
    const view = editor.current; if (!view) return;
    const text = await loadAST(fct); if (!text) return;
    const tree = textToTree(text, 0); if (!tree) return;
    const code = CodeDecorations(tree, fct);
    const extensions = baseExtensions.concat(code ? [code] : []);
    const state = EditorState.create({ doc: toString(text), extensions });
    printed.current = fct;
    view.setState(state);
  }, [editor, fct, baseExtensions]);

  // Update the component when the focused function changes.
  React.useEffect(() => {
    if (printed.current !== fct) focusCallback();
    Server.onSignal(Ast.changed, focusCallback);
    return () => { Server.offSignal(Ast.changed, focusCallback); };
  });

  return <div className='cm-global-box' ref={parent} />;
}



registerSandbox({
  id: 'codemirror6',
  label: 'CodeMirror 6',
  children: <Editor />,
});
