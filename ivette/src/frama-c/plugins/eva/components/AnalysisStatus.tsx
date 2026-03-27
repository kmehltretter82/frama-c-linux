/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';

import { Icon } from 'dome/controls/icons';
import { GlobalState, useGlobalState } from 'dome/data/states';
import { Label } from 'dome/controls/labels';
import { classes } from 'dome/misc/utils';
import { Button } from 'dome/controls/buttons';
import { closeModal, Modal, showModal } from 'dome/dialogs';

import * as Eva from 'frama-c/plugins/eva/api/analysis';
import { evaBasicStatus } from 'frama-c/plugins/eva/EvaDefinitions';
import { useSyncValue } from 'frama-c/states';
import * as Server from 'frama-c/server';

interface EvaReadyProps {
  children: React.ReactNode;
  showChildrenForComputingStatus?: boolean;
}

interface EvaStatusProp {
  iconSize?: number; // default size for titlebar
  showStatus?: Eva.computationStateType[]; // all status shown by default
}

interface StatusIconProp {
  size: number;
  status?: Eva.computationStateType;
}

export function StatusIcon(props: StatusIconProp):JSX.Element {
  const { size, status } = props;
  const infosStatus = evaBasicStatus[status || "undefined"];

  return (
    <Icon
      id={infosStatus.icon}
      title={infosStatus.title}
      className={"eva-status-icon eva-"+status}
      size={size}
    />
  );
}

function EvaLaunchButton(): JSX.Element | null {
  return <Button
      icon="MEDIA.PLAY"
      label="Launch analysis"
      title="Click to launch Eva analysis with
        actual parameters or launch from Eva sidebar."
      onClick={() => Server.send(Eva.compute, null)}
    />;
}

export function EvaStatus(props: EvaStatusProp): JSX.Element | null {
  const { iconSize = 12, showStatus } = props;
  const status = useSyncValue(Eva.computationState);

  if(!showStatus || status && showStatus?.includes(status)) {
    return <StatusIcon size={iconSize} status={status} />;
  } else return null;
}

function timeToString(time: number): string {
  const totalSeconds = Math.floor(time / 1000);

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const strSeconds = seconds.toString().padStart(2, '0');
  const strMinutes = minutes.toString().padStart(2, '0');
  const strTime = `${strMinutes}:${strSeconds}`;

  return hours > 0 ? `${hours}:${strTime}` : strTime;
}

function Timer({ start }: {start: number}): React.JSX.Element {
  const [time, setTime] = React.useState(Date.now() - start);

  const className = classes(
    'eva-status-timer',
    time < 10000 && 'eva-status-timer-hide'
  );

  React.useEffect(() => {
    const interval = setInterval(() => setTime(Date.now() - start), 1000);
    return () => clearInterval(interval);
  }, [start]);

  return <Label className={className}>{timeToString(time)}</Label>;
}

function useTimer(): React.JSX.Element | null {
  const status = useSyncValue(Eva.computationState);
  const [start, setStart] = useGlobalState(startComputing);

  React.useEffect(() => {
    // If start ≠ 0, this means the counter has already started.
    // It does not restart during a hot reload, for example.
    if( status === "computing" && start === 0) setStart(Date.now());
    else if(status !== "computing") setStart(0);
  }, [status, start, setStart]);

  return start !== 0 ? <Timer start={start}/> : null;
}

const startComputing = new GlobalState<number>(0);

export function EvaReady(props: EvaReadyProps): JSX.Element {
  const { showChildrenForComputingStatus = false, children } = props;
  const timer = useTimer();
  const status = useSyncValue(Eva.computationState);
  const infosStatus = evaBasicStatus[status || "undefined"];
  const showChildren = Boolean(
    status === "aborted" || status === "computed" ||
    (showChildrenForComputingStatus && status === "computing")
  );

  if(showChildren) return <>{children}</>;
  else return (
    <div className={"eva-status eva-status-"+status}>
      <div className='eva-status-content'>
        <div className="eva-status-message">{infosStatus.message}</div>
        { status !== 'computing' && <EvaLaunchButton /> }
        <StatusIcon size={50} status={status} />
        { timer }
      </div>
    </div>
  );
}
/* -------------------------------------------------------------------------- */
/* --- Modal                                                              --- */
/* -------------------------------------------------------------------------- */

function EvaModal({ callback }: { callback: () => void })
: React.JSX.Element {
  const status = useSyncValue(Eva.computationState);
  const timer = useTimer();

  /**
   * The callback function is only called if the Eva modal window is still
   * open at the end of the analysis.
   * Closing the modal window is equivalent to abandoning the action.
  */
  React.useEffect(() => {
    if(status === 'computed') {
      callback();
      closeModal();
    }
  }, [status, callback]);

  return (
    <Modal className='modal-eva' label={`Eva: Analysis not completed`} >
      <div className={"eva-status eva-status-"+status}>
        <div className='eva-status-content'>
          <div className='eva-status-message'>
            The requested action requires an Eva analysis.
          </div>
          <div className='eva-status-message'>
            If you run the analysis here, once it is complete,
            the action will be executed and the modal window will be closed.
          </div>
          <div className='eva-status-message'>
            If the modal window is closed during the analysis,
            the action will be abandoned.
          </div>
          <EvaLaunchButton />
          <StatusIcon size={50} status={status} />
          { timer }
        </div>
      </div>
    </Modal>
  );
}

function showEvaModal(callback: () => void): void {
  showModal(<EvaModal callback={callback} />);
}

export async function evaNeeded(callback: () => void): Promise<void> {
  const status = await Server.send(Eva.getComputationState, []);
  if(status !== "computed")
    showEvaModal(callback);
  else callback();
}
