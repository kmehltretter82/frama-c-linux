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

import * as Eva from 'frama-c/plugins/eva/api/analysis';
import { evaBasicStatus } from 'frama-c/plugins/eva/EvaDefinitions';
import { useSyncValue } from 'frama-c/states';

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

const startComputing = new GlobalState<number>(0);

export function EvaReady(props: EvaReadyProps): JSX.Element {
  const { showChildrenForComputingStatus = false, children } = props;
  const [start, setStart] = useGlobalState(startComputing);
  const status = useSyncValue(Eva.computationState);
  const infosStatus = evaBasicStatus[status || "undefined"];
  const showChildren = Boolean(
    status === "aborted" || status === "computed" ||
    (showChildrenForComputingStatus && status === "computing")
  );

  React.useEffect(() => {
    // If start ≠ 0, this means the counter has already started.
    // It does not restart during a hot reload, for example.
    if( status === "computing" && start === 0) setStart(Date.now());
    else if(status !== "computing") setStart(0);
  }, [status, start, setStart]);

  if(showChildren) return <>{children}</>;
  else return (
    <div className={"eva-status eva-status-"+status}>
      <div className='eva-status-content'>
        <div className="eva-status-message">{infosStatus.message}</div>
        <StatusIcon size={50} status={status} />
        { status === "computing" && start !== 0 && <Timer start={start}/>}
      </div>
    </div>
  );
}
