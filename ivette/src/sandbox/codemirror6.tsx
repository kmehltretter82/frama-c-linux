import React from 'react';
import { EditorState, EditorStateConfig, StateField, StateEffect, RangeSet } from '@codemirror/state';
import { EditorView, Decoration, DecorationSet } from '@codemirror/view';

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
  if (Array.isArray(text)) return text.map(toString).join('');
  else if (typeof text === 'string') return text;
  else return 'Failed to convert text to string';
}



interface EditorProps {
  initialConfig?: EditorStateConfig,
  parent: React.MutableRefObject<Element | DocumentFragment | undefined | null>
}

function useEditor(props: EditorProps): React.MutableRefObject<EditorView | undefined> {
  const view = React.useRef<EditorView | undefined>();
  React.useEffect(() => {
    const state = EditorState.create(props.initialConfig);
    const parent = props.parent.current!;
    view.current = new EditorView({ state, parent });
    return () => { view.current?.destroy(); view.current = undefined; };
  }, []);
  return view;
}



type Tree = { tag?: string ; from: number ; to: number ; children: Tree[] }

function ranges(t: text, from: number): Tree {
  if (Array.isArray(t)) {
    const children = t.slice(1).map((from => line => {
      const result = ranges(line, from);
      from = result.to;
      return result;
    })(from));
    const to = children.length > 0 ? children[children.length - 1].to : from;
    const tag = typeof t[0] === 'string' && t[0].length > 0 ? t[0] : undefined;
    return { tag, from, to, children }
  }
  else if (typeof t === 'string')
    return { from, to: from + t.length, children: [] }
  else return { from, to: from, children: [] }
}

function byLevel(t: Tree): DecorationSet[] {
  const decoration = Decoration.mark({ class: 'cm-decoration-element' });
  const max = (a: number, b: number): number => Math.max(a, b);
  const depth = (t: Tree): number =>
    t.children.length > 0 ? t.children.map(depth).reduce(max) + 1 : 1;
  const res = Array<DecorationSet>(depth(t)).fill(RangeSet.of([]));
  function aux(t: Tree, depth: number): void {
    const add = [ decoration.range(t.from, t.to) ];
    if (t.tag) res[depth] = res[depth].update({ add });
    t.children.forEach((child) => aux(child, depth + 1));
  }
  aux(t, 0);
  return res;
}

function field(set: DecorationSet): StateField<DecorationSet> {
  return StateField.define<DecorationSet>({
    create() { return set; },
    update(set, tr) { return set.map(tr.changes); },
    provide: f => EditorView.decorations.from(f)
  });
}


function Editor() : JSX.Element {
  const initialConfig = {};
  const parent = React.useRef(null);
  const editor = useEditor({ initialConfig, parent });

  const printed = React.useRef<string | undefined>();
  const [selection] = States.useSelection();
  const fct = selection?.current?.fct;

  const focusFunction = React.useCallback(async () => {
    const view = editor.current;
    printed.current = fct;
    const text = await loadAST(fct);
    console.log(text);
    const insert = toString(text);
    view?.dispatch({ changes: { from: 0, to: view.state.doc.length, insert } });
    const hoverFields = text ? byLevel(ranges(text, 0)).map(field) : [];
    const effects = StateEffect.reconfigure.of(hoverFields);
    view?.dispatch({ effects });
  }, [fct, editor]);

  React.useEffect(() => { if (printed.current !== fct) focusFunction(); });
  React.useEffect(() => {
    Server.onSignal(Ast.changed, focusFunction);
    return () => { Server.offSignal(Ast.changed, focusFunction); };
  });

  return (
    <div
      className='cm-global-box'
      ref={parent}
    />
  );
}

registerSandbox({
  id: 'codemirror6',
  label: 'CodeMirror 6',
  children: <Editor />,
});
