/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import * as Ivette from 'ivette';

import { useFlipSettings } from 'dome';
import { Button, ButtonGroup, ToolBar } from 'dome/frame/toolbars';
import { useModel } from 'dome/table/models';
import { Label } from 'dome/controls/labels';
import { classes } from 'dome/misc/utils';
import { Icon, IconKind } from 'dome/controls/icons';

import * as States from 'frama-c/states';

import { EvaReady, EvaStatus } from './components/AnalysisStatus';
import { mtSummary, mtSummaryData } from './api/mthread';

type Thread = [number, string];
interface MtContext {
  selectedThread?: [string, (v: string) => void];
  selectedMutex?: [string, (v: string) => void];
  selectedMessage?: [string, (v: string) => void];
  selectedVar?: [string, (v: string) => void];
}

const MTCONTEXT = React.createContext<MtContext>({});

interface MtButtonProps {
  label: string;
  id: number | string;
  selectedState?: [string, (v: string) => void];
}

function MtButton(props: MtButtonProps): React.JSX.Element {
  const { label, id, selectedState } = props;
  const strId = typeof id === 'number' ? id.toString() : id;

  const selected = selectedState &&
    selectedState[0].replace(/\[.*\]$/, "") === strId.replace(/\[.*\]$/, "");
  const onClick = (): void => selectedState && selectedState[1](strId);

  return <Button
    key={strId}
    label={label}
    selected={selected}
    onClick={onClick}
  />;
}

// --------------------------------------------------------------------------
// --- subElement read, write, taken, released ...
// --------------------------------------------------------------------------

interface subElementProps {
  label: string;
  children?: React.ReactNode;
}

function SubElement(props: subElementProps): React.JSX.Element {
  const { label, children } = props;

  return (
    <div className={'thumb-subcontent'}>
      <Label label={label} className='thumb-subcontent-title' />
      <div className={'thumb-subcontent-infos'} >
        { children }
      </div>
    </div>
  );
}

// --------------------------------------------------------------------------
// --- first element level error | mutex | message | variable
// --------------------------------------------------------------------------

interface ElementProps {
  label: string;
  icon?: string;
  iconKind?: IconKind;
  mode?: 'row' | 'column';
  className?: string;
  children: React.ReactNode;
}

function Element(props: ElementProps): React.JSX.Element | null {
  const { label, icon, iconKind, mode = 'row', className, children } = props;
  const classInfos = classes(
    'thumb-content-infos', `thumb-content-${mode}`
  );
  const classContent = classes(
    'thumb-content', className
  );

  return (
    <div className={classContent}>
      <Label label={label} className='thumb-content-title'>
        { icon && <Icon id={icon} kind={iconKind} /> }
      </Label>
      { children &&
        <div className={classInfos} >
          { children }
        </div>
      }
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Elements Error, Mutex, Message, variable
// --------------------------------------------------------------------------

function getSubElement(
  label: string,
  data: [number, string][] | string[],
  selectedState?: [string, (v: string) => void]
): React.JSX.Element {
  return (
    <SubElement label={label}>
      {
        data.map(val => {
          const isArray = Array.isArray(val);
          const id = isArray ? val[0] : val;
          const label = isArray ? val[1] : val;
          return <MtButton
            key={id}
            id={id}
            label={label}
            selectedState={selectedState} />;
          }
        )
      }
    </SubElement>
  );
}

interface ContentProps {
  data:  mtSummaryData;
  showEmpty: boolean;
}

function ErrorContent(props: ContentProps): React.JSX.Element | null {
  const errors: string[] = [];
  if(isErrorInMutex(props.data))
    errors.push(
      "Mutex: the mutexes taken and released are not the same "
    );
  const label = errors.length > 0 ?
    'Error':
    `No errors in ${props.data.thread[1]}`;
  const icon = errors.length > 0 ? "WARNING" : undefined;
  const iconKind = errors.length > 0 ? "negative" : undefined;

  if(!props.showEmpty && errors.length === 0) return null;
  return (
    <Element label={label} icon={icon} iconKind={iconKind} >
      { errors.map((error, i) => <SubElement key={i} label={error} />)}
    </Element>
  );
}

function MutexContent(props: ContentProps): React.JSX.Element | null {
  const { data: { locksTaken, locksReleased }, showEmpty } = props;
  const { selectedMutex } = React.useContext(MTCONTEXT);
  const isTaken = locksTaken.length > 0;
  const isReleased = locksReleased.length > 0;
  const emptyContent = Boolean(!isTaken && !isReleased);
  const label = !emptyContent ? 'Mutex': 'Mutex: no mutex taken or released';

  if(!showEmpty && emptyContent) return null;
  return (
    <Element label={label} className='mthread-thumb-mutex'>
      { isTaken && getSubElement('Taken', locksTaken, selectedMutex) }
      { isReleased && getSubElement('Released', locksReleased, selectedMutex) }
    </Element>
  );
}

function MessageContent(props: ContentProps): React.JSX.Element | null {
  const { data, showEmpty } = props;
  const { mqueuesCreated, mqueuesReceivers, mqueuesSenders } = data;
  const isCreate = mqueuesCreated.length > 0;
  const isReceived = mqueuesReceivers.length > 0;
  const isSend = mqueuesSenders.length > 0;
  const emptyContent = Boolean(!isCreate && !isReceived && !isSend);
  const label = !emptyContent ? 'Message': 'Message: no message';

  if(!showEmpty && emptyContent) return null;
  return (
    <Element label={label} mode='column' className='mthread-thumb-message'>
      { isCreate && getSubElement('Create', mqueuesCreated)}
      { isReceived && getSubElement('Receive', mqueuesReceivers)}
      { isSend && getSubElement('Send', mqueuesSenders)}
    </Element>
  );
}

function VariableContent(props: ContentProps): React.JSX.Element | null {
  const { data: { sharedVarsRead, sharedVarsWritten }, showEmpty } = props;
  const { selectedVar } = React.useContext(MTCONTEXT);
  const isVarRead = sharedVarsRead.length > 0;
  const isVarWrite = sharedVarsWritten.length > 0;
  const emptyContent = Boolean(!isVarRead && !isVarWrite);
  const label = !emptyContent ?
    'Variable':
    'Variable: no variable read or write';

  if(!showEmpty && emptyContent) return null;
  return (
    <Element label={label}  className='mthread-thumb-variable'>
      { isVarRead && getSubElement('Read', sharedVarsRead, selectedVar) }
      { isVarWrite && getSubElement('Write', sharedVarsWritten, selectedVar) }
    </Element>
  );
}

interface VarContentProps {
  data: [string, {read: Thread[], write: Thread[]}];
  showEmpty: boolean;
}

function ThreadContent(props: VarContentProps): React.JSX.Element | null {
  const { selectedThread } = React.useContext(MTCONTEXT);
  const [ , { read, write }] = props.data;
  const isThreadRead = read.length > 0;
  const isThreadWrite = write.length > 0;
  const emptyContent = Boolean(!isThreadRead && !isThreadWrite);
  const label = !emptyContent ?
    'Threads':
    'Threads: thread doesn\'t read or write';

  if(!props.showEmpty && emptyContent) return null;
  return (
    <Element label={label}  className='mthread-thumb-thread'>
      { isThreadRead && getSubElement('Read', read, selectedThread) }
      { isThreadWrite && getSubElement('Write', write, selectedThread) }
    </Element>
  );
}

function MThreadComponent(): JSX.Element {
  const [ displayMode, setDisplayMode] =
    React.useState<'thread' | 'variable'>('thread');
  const [ hideEmpty, setHideEmpty ] =
    useFlipSettings('ivette.mthread.display.show-empty', true);
  const [ errors, setErrors ] =
    useFlipSettings('ivette.mthread.display.errors', true);
  const [ mutex, setMutex ] =
    useFlipSettings('ivette.mthread.display.mutex', true);
  const [ message, setMessage ] =
    useFlipSettings('ivette.mthread.display.message', true);
  const [ variable, setVariable ] =
    useFlipSettings('ivette.mthread.display.variable', true);
  const [ filterErrorMutex, setFilterErrorMutex ] =
    useFlipSettings('ivette.mthread.display.filterErrorMutex', false);
  const [ filterNoMutex, setFilterNoMutex ] =
    useFlipSettings('ivette.mthread.display.filterNoMutex', false);

  const context = React.useContext(MTCONTEXT);
  context.selectedThread = React.useState("");
  context.selectedMutex = React.useState("");
  context.selectedMessage = React.useState("");
  context.selectedVar = React.useState("");

  const model = States.useSyncArrayModel(mtSummary);
  const syncModel = useModel(model);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const threads = React.useMemo(() => model.getArray(), [syncModel, model]);

  const threadsFiltering = React.useMemo(() => {
    syncModel;
    let news = !filterErrorMutex ? threads : filteringErrorMutex(threads);
    if(filterNoMutex) news = filteringNoMutex(news);
    return news;
  }, [syncModel, threads, filterErrorMutex, filterNoMutex]);

  const vars = React.useMemo(() => {
    const newVars: {[key: string]: {read: Thread[], write: Thread[]}} = {};

    threads.forEach((thread) => {
      thread.sharedVarsRead.forEach((v) => {
        if(!(v in newVars)) newVars[v] = { read: [], write: [] };
        newVars[v].read.push(thread.thread);
      });
      thread.sharedVarsWritten.forEach((v) => {
        if(!(v in newVars)) newVars[v] = { read: [], write: [] };
        newVars[v].write.push(thread.thread);
      });
    });

    return Object.entries(newVars);
  }, [threads]);

  return (
    <div className='eva-mthread'>
      <Ivette.TitleBar><EvaStatus /></Ivette.TitleBar>
        <ToolBar className={'eva-mthread-toolbar'}>
        <div>
          <Button
            label={'Hide empty'}
            title='show Errors'
            selected={hideEmpty}
            onClick={() => setHideEmpty()}
            />
          <ButtonGroup>
            <Button
              label='Errors'
              title='show Errors'
              selected={errors}
              onClick={() => setErrors()}
              />
            <Button
              label='Mutex'
              title='show mutex table'
              selected={mutex}
              onClick={() => setMutex()}
              />
            <Button
              label='Message'
              title='show message table'
              selected={message}
              onClick={() => setMessage()}
              />
            <Button
              label='Variable'
              title='show variable table'
              selected={variable}
              onClick={() => setVariable()}
              />
          </ButtonGroup>
        </div>
        <ButtonGroup>
          <Button
            label='Thread'
            title='Thread mode'
            selected={displayMode === 'thread'}
            onClick={() => setDisplayMode('thread')}
            />
          <Button
            label='Variable'
            title='variable mode'
            selected={displayMode === 'variable'}
            onClick={() => setDisplayMode('variable')}
            />
        </ButtonGroup>
        <div>
          <Button
            label='Filter Error Mutex'
            title='filter error mutex'
            disabled={displayMode === 'variable'}
            selected={filterErrorMutex}
            onClick={() => setFilterErrorMutex()}
            />
          <Button
            label='Filter No Mutex'
            title='filter no mutex'
            disabled={displayMode === 'variable'}
            selected={filterNoMutex}
            onClick={() => setFilterNoMutex()}
            />
        </div>
      </ToolBar>
      <EvaReady>
        <motion.div layout style={{ height: '100%' }}><AnimatePresence>
          <MTCONTEXT.Provider value={context}>
            <div className='eva-mthread-thumbs'>
              {
                displayMode === 'thread' &&
                  threadsFiltering.map((t) => {
                    const data = { data: t, showEmpty: !hideEmpty };
                    const [ , name ] = t.thread;
                    return (
                      <AnimatedElement key={t.key} className='mthread-thumb'>
                        <div className='mthread-thumb-title'>{ name }</div>
                        {errors && <ErrorContent {...data} />}
                        {mutex && <MutexContent {...data} />}
                        {message && <MessageContent {...data} />}
                        {variable && <VariableContent {...data} />}
                      </AnimatedElement>
                    );
                })
              }
              {
                displayMode === 'variable' &&
                  vars.map((v) => {
                    const data = { data: v, showEmpty: !hideEmpty };
                    return (
                      <AnimatedElement key={v[0]} className='mthread-thumb'>
                        <div className='mthread-thumb-title'>{v[0]}</div>
                        <ThreadContent {...data} />
                      </AnimatedElement>
                    );
                })
              }
            </div>
          </MTCONTEXT.Provider>
        </AnimatePresence></motion.div>
      </EvaReady>
    </div>
  );
}

Ivette.registerComponent({
  id: 'fc.eva.mthread',
  label: 'Eva MThread',
  title: 'Eva MThread analysis',
  children: <MThreadComponent />,
});

// --------------------------------------------------------------------------
// --- MThread Animated Element
// --------------------------------------------------------------------------

interface AnimatedElementProps {
  className?: string;
  children?: React.ReactNode;
}

function AnimatedElement(props: AnimatedElementProps): React.JSX.Element  {
  const { className, children } = props;

  return <motion.div
    layout
    initial={{ opacity: 0, scale: 0.8 }}
    animate={{ opacity: 1, scale: 1 }}
    exit={{ opacity: 1, scale: 0.8 }}
    transition={{ duration: .3 }}
    className={className}
  >{ children }</motion.div>;
}

// --------------------------------------------------------------------------
// --- Filtering function
// --------------------------------------------------------------------------
function isErrorInMutex(thread: mtSummaryData): boolean {
  const taken = thread.locksTaken;
  const released = thread.locksReleased;
  return !taken.every(
    (lock) => released.find(e => e[0] === lock[0])
  ) || released.length !== taken.length;
}

function filteringErrorMutex(datas: mtSummaryData[]): mtSummaryData[] {
  return datas.filter((mt) => isErrorInMutex(mt));
}

function filteringNoMutex(datas: mtSummaryData[]): mtSummaryData[] {
  return datas.filter((mt) => {
    return mt.locksReleased.length !== 0 || mt.locksTaken.length !== 0;
  });
}

// --------------------------------------------------------------------------
