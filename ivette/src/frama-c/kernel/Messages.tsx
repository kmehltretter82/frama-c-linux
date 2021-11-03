/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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

import * as React from 'react';
import * as Dome from 'dome';
import { TitleBar } from 'ivette';

import { IconButton } from 'dome/controls/buttons';
import { Label, Cell } from 'dome/controls/labels';
import { Page } from 'dome/text/pages';
import { Icon } from 'dome/controls/icons';
import { Scroll, Vbox } from 'dome/layout/boxes';
import { RSplit, BSplit } from 'dome/layout/splitters';
import * as Forms from 'dome/layout/forms';
import * as Arrays from 'dome/table/arrays';
import { Table, Column, Renderer } from 'dome/table/views';
import * as Compare from 'dome/data/compare';

import * as States from 'frama-c/states';
import * as Ast from 'frama-c/api/kernel/ast';
import * as Kernel from 'frama-c/api/kernel/services';

type Message = Kernel.messageData;

// --------------------------------------------------------------------------
// --- Filters
// --------------------------------------------------------------------------

interface Search {
  category?: string;
  message?: string;
}

interface KindFilter {
  result?: boolean;
  feedback?: boolean;
  debug?: boolean;
  warning?: boolean;
  error?: boolean;
  failure?: boolean;
}

interface PluginFilter {
  kernel?: boolean;
  aorai?: boolean;
  dive?: boolean;
  eacsl?: boolean;
  eva?: boolean;
  from?: boolean;
  impact?: boolean;
  inout?: boolean;
  metrics?: boolean;
  nonterm?: boolean;
  pdg?: boolean;
  report?: boolean;
  rte?: boolean;
  scope?: boolean;
  server?: boolean;
  slicing?: boolean;
  variadic?: boolean;
  wp?: boolean;
  others?: boolean;
}

interface Filter {
  currentFct: boolean;
  search: Search;
  kind: KindFilter;
  plugin: PluginFilter;
}

const defaultFilter: Filter = {
  currentFct: false,
  search: {},
  kind: {
    result: false,
    feedback: false,
    debug: false,
  },
  plugin: {},
};

function filterKind(filter: KindFilter, msg: Message) {
  const hide =
    (filter.result === false && msg.kind === 'RESULT')
    || (filter.feedback === false && msg.kind === 'FEEDBACK')
    || (filter.debug === false && msg.kind === 'DEBUG')
    || (filter.warning === false && msg.kind === 'WARNING')
    || (filter.error === false && msg.kind === 'ERROR')
    || (filter.failure === false && msg.kind === 'FAILURE');
  return !hide;
}

function filterPlugin(filter: PluginFilter, msg: Message) {
  switch (msg.plugin) {
    case 'kernel': return !(filter.kernel === false);
    case 'aorai': return !(filter.aorai === false);
    case 'dive': return !(filter.dive === false);
    case 'e-acsl': return !(filter.eacsl === false);
    case 'eva': return !(filter.eva === false);
    case 'from': return !(filter.from === false);
    case 'impact': return !(filter.impact === false);
    case 'inout': return !(filter.inout === false);
    case 'metrics': return !(filter.metrics === false);
    case 'nonterm': return !(filter.nonterm === false);
    case 'pdg': return !(filter.pdg === false);
    case 'report': return !(filter.report === false);
    case 'rte': return !(filter.rte === false);
    case 'scope': return !(filter.scope === false);
    case 'server': return !(filter.server === false);
    case 'slicing': return !(filter.slicing === false);
    case 'variadic': return !(filter.variadic === false);
    case 'wp': return !(filter.wp === false);
    default: return !(filter.others === false);
  }
}

function searchCategory(search: string | undefined, msg: string | undefined) {
  if (!search || search.length < 2)
    return true;
  if (!msg)
    return false;
  const message = msg.toLowerCase();
  const array = search.toLowerCase().split(' ');
  let empty = true;
  let show = false;
  let hide = false;
  array.forEach((str: string) => {
    if (str.length > 1) {
      if (str.charAt(0) === '-') {
        if (message.includes(str.substring(1)))
          hide = true;
      }
      else if (message.includes(str))
        show = true;
      else
        empty = false;
    }
  });
  return (empty || show) && !hide;
}

function searchString(search: string | undefined, msg: string) {
  if (!search || search.length < 3)
    return true;
  if (search.charAt(0) === '"' && search.slice(-1) === '"') {
    const exact = search.slice(1, -1);
    return msg.includes(exact);
  }
  const message = msg.toLowerCase();
  const array = search.toLowerCase().split(' ');
  let show = true;
  array.forEach((str: string) => {
    if (str.length > 1 && !message.includes(str))
      show = false;
  });
  return show;
}

function filterSearched(search: Search, msg: Message) {
  return (searchString(search.message, msg.message) &&
          searchCategory(search.category, msg.category));
}

function filterFunction(filter: Filter, kf: string | undefined, msg: Message) {
  if (filter.currentFct)
    return (kf === msg.fct);
  return true;
}

function filterMessage(filter: Filter, kf: string | undefined, msg: Message) {
  return (filterFunction(filter, kf, msg) &&
          filterSearched(filter.search, msg) &&
          filterKind(filter.kind, msg) &&
          filterPlugin(filter.plugin, msg));
}

// --------------------------------------------------------------------------
// --- Filters panel and ratio
// --------------------------------------------------------------------------

function MessageFilter(props: {filter: Forms.FieldState<Filter>}) {
  const state = props.filter;
  const search = Forms.useProperty(state, 'search');
  const categoryState = Forms.useProperty(search, 'category');
  const messageState = Forms.useProperty(search, 'message');

  const kind = Forms.useProperty(state, 'kind');
  function kindState(path: keyof KindFilter) {
    return Forms.useDefault(Forms.useProperty(kind, path), true);
  }

  const plugin = Forms.useProperty(state, 'plugin');
  function pluginState(path: keyof PluginFilter) {
    return Forms.useDefault(Forms.useProperty(plugin, path), true);
  }

  return (
    <Scroll>
      <Forms.Page className="message-search">
        <Forms.CheckboxField
          label="Current function"
          title="Only show messages emitted at the current function"
          state={Forms.useProperty(state, 'currentFct')}
        />
        <Forms.Section
          label="Search"
          unfold
          settings="ivette.messages.search"
        >
          <Forms.TextField
            label="Category"
            state={categoryState}
            placeholder="Category"
            title={'Search in message category.\n'
                 + 'Use -<name> to hide some categories.'}
          />
          <Forms.TextField
            label="Message"
            state={messageState}
            placeholder="Message"
            title={'Search in message text.\n'
                 + 'Case-insensitive by default.\n'
                 + 'Use "text" for an exact case-sensitive search.'}
          />
        </Forms.Section>
        <Forms.Section
          label="Kind"
          unfold
          settings="ivette.messages.filterKind"
        >
          <Forms.CheckboxField label="Result" state={kindState('result')} />
          <Forms.CheckboxField label="Feedback" state={kindState('feedback')} />
          <Forms.CheckboxField label="Debug" state={kindState('debug')} />
          <Forms.CheckboxField label="Warning" state={kindState('warning')} />
          <Forms.CheckboxField label="Error" state={kindState('error')} />
          <Forms.CheckboxField label="Failure" state={kindState('failure')} />
        </Forms.Section>
        <Forms.Section
          label="Emitter"
          unfold
          settings="ivette.messages.filterEmitter"
        >
          <div className="message-emitter-category">
            <Forms.CheckboxField label="Kernel" state={pluginState('kernel')} />
          </div>
          <div className="message-emitter-category">
            <Forms.CheckboxField label="Aoraï" state={pluginState('aorai')} />
            <Forms.CheckboxField label="Dive" state={pluginState('dive')} />
            <Forms.CheckboxField label="E-ACSL" state={pluginState('eacsl')} />
            <Forms.CheckboxField label="Eva" state={pluginState('eva')} />
            <Forms.CheckboxField label="From" state={pluginState('from')} />
            <Forms.CheckboxField label="Impact" state={pluginState('impact')} />
            <Forms.CheckboxField label="InOut" state={pluginState('inout')} />
            <Forms.CheckboxField
              label="Metrics"
              state={pluginState('metrics')}
            />
            <Forms.CheckboxField
              label="NonTerm"
              state={pluginState('nonterm')}
            />
            <Forms.CheckboxField label="Pdg" state={pluginState('pdg')} />
            <Forms.CheckboxField label="Report" state={pluginState('report')} />
            <Forms.CheckboxField label="RTE" state={pluginState('rte')} />
            <Forms.CheckboxField label="Scope" state={pluginState('scope')} />
            <Forms.CheckboxField label="Server" state={pluginState('server')} />
            <Forms.CheckboxField
              label="Slicing"
              state={pluginState('slicing')}
            />
            <Forms.CheckboxField
              label="Variadic"
              state={pluginState('variadic')}
            />
            <Forms.CheckboxField label="WP" state={pluginState('wp')} />
          </div>
          <div className="message-emitter-category">
            <Forms.CheckboxField label="Others" state={pluginState('others')} />
          </div>
        </Forms.Section>
      </Forms.Page>
    </Scroll>
  );
}

function FilterRatio({ model }: { model: Arrays.ArrayModel<any, any> }) {
  const [filtered, total] = [model.getRowCount(), model.getTotalRowCount()];
  const title = `${filtered} displayed messages / ${total} total messages`;
  return (
    <Label className="component-info" title={title}>
      {filtered} / {total}
    </Label>
  );
}

// --------------------------------------------------------------------------
// --- Messages Columns
// --------------------------------------------------------------------------

const renderKind: Renderer<Kernel.logkind> = (kind: Kernel.logkind) => {
  const label = kind.toLocaleLowerCase();
  let icon = '';
  let color = 'black';
  switch (kind) {
    case 'RESULT': icon = 'ANGLE.RIGHT'; break;
    case 'FEEDBACK': icon = 'CIRC.INFO'; break;
    case 'DEBUG': icon = 'HELP'; break;
    case 'WARNING': icon = 'ATTENTION'; color = '#C00000'; break;
    case 'ERROR': case 'FAILURE': icon = 'WARNING'; color = '#C00000'; break;
  }
  return <Icon title={label} id={icon} fill={color} />;
};

const renderCell: Renderer<string> =
  (text: string) => (<Cell title={text}>{text}</Cell>);

const renderMessage: Renderer<string> =
  (text: string) => (<div title={text} className="message-cell"> {text} </div>);

const renderDir: Renderer<Ast.source> =
  (loc: Ast.source) => (<Cell label={loc.dir} title={loc.file} />);

const renderFile: Renderer<Ast.source> =
  (loc: Ast.source) => (
    <Cell label={`${loc.base}:${loc.line}`} title={loc.file} />
  );

const MessageColumns = () => (
  <>
    <Column
      id="kind"
      title="Message kind"
      label="Kind"
      width={42}
      align="center"
      render={renderKind}
    />
    <Column
      id="plugin"
      label="Emitter"
      title="Frama-C kernel or plugin"
      width={75}
      render={renderCell}
    />
    <Column
      id="category"
      label="Category"
      title="Only for warning and debug messages"
      width={150}
      render={renderCell}
    />
    <Column
      id="message"
      label="Message"
      fill
      render={renderMessage}
    />
    <Column
      id="fct"
      label="Function"
      width={150}
      render={renderCell}
    />
    <Column
      id="dir"
      label="Directory"
      width={240}
      visible={false}
      getter={(msg: Message) => msg?.source}
      render={renderDir}
    />
    <Column
      id="file"
      label="File"
      width={150}
      getter={(msg: Message) => msg?.source}
      render={renderFile}
    />
    <Column
      id="key"
      label="Id"
      title="Message emission order"
      width={42}
      visible={false}
    />
  </>
);

// -------------------------------------------------------------------------
// --- Mesages Table
// -------------------------------------------------------------------------

const bySource =
  Compare.byFields<Ast.source>({ file: Compare.alpha, line: Compare.number });

const byMessage: Compare.ByFields<Message> = {
  key: Compare.lift(parseInt, Compare.bignum),
  kind: Compare.structural,
  plugin: Compare.string,
  category: Compare.defined(Compare.string),
  fct: Compare.defined(Compare.alpha),
  source: Compare.defined(bySource),
};

export default function RenderMessages() {

  const [model] = React.useState(() => {
    const f = (msg: Message) => msg.key;
    const model = new Arrays.CompactModel<string, Message>(f);
    model.setOrderingByFields(byMessage);
    return model;
  });

  const data = States.useSyncArray(Kernel.message).getArray();

  React.useEffect(() => {
    model.removeAllData();
    model.updateData(data);
    model.reload();
  }, [model, data]);

  const filterState = Forms.useState<Filter>(defaultFilter);
  const [filter] = filterState;
  const [selection, updateSelection] = States.useSelection();
  const selectedFct = selection?.current?.fct;
  const [message, setMessage] = React.useState('');

  React.useEffect(() => {
    model.setFilter((msg: Message) => filterMessage(filter, selectedFct, msg));
  }, [model, filter, selectedFct]);

  const onMessageSelection = React.useCallback(
    ({ fct, marker, message: msg }: Message) => {
      setMessage(msg);
      if (fct && marker) {
        const location = { fct, marker };
        updateSelection({ location });
      }
    }, [updateSelection],
  );

  const [showFilter, flipFilter] =
    Dome.useFlipSettings('ivette.messages.showFilter', true);

  const MessagePanel = (
    <Vbox style={{ height: '100%' }}>
      <IconButton
        icon="CROSS"
        title="Close"
        onClick={() => setMessage('')}
        style={{ margin: '0 auto' }}
      />
      <Scroll>
        <Page className="message-page"> {message} </Page>
      </Scroll>
    </Vbox>
  );

  return (
    <>
      <TitleBar>
        <FilterRatio model={model} />
        <IconButton
          icon="CLIPBOARD"
          selected={showFilter}
          onClick={flipFilter}
          title="Toggle filters panel"
        />
      </TitleBar>
      <RSplit
        settings="ivette.messages.filterSplit"
        defaultPosition={225}
        unfold={showFilter}
      >
        <BSplit
          settings="ivette.messages.messageSplit"
          defaultPosition={90}
          unfold={message !== ''}
        >
          <Table<string, Message>
            model={model}
            sorting={model}
            onSelection={onMessageSelection}
            settings="ivette.messages.table"
          >
            <MessageColumns />
          </Table>
          {MessagePanel}
        </BSplit>
        <MessageFilter filter={filterState} />
      </RSplit>
    </>
  );
}
