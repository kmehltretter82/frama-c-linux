/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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

import React from 'react';
import { Icon } from 'dome/controls/icons';
import * as Eva from 'frama-c/plugins/eva/api/general';
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

function StatusIcon(props: StatusIconProp):JSX.Element {
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

export function EvaReady(props: EvaReadyProps): JSX.Element {
  const { showChildrenForComputingStatus = false, children } = props;
  const status = useSyncValue(Eva.computationState);
  const infosStatus = evaBasicStatus[status || "undefined"];
  const showChildren = Boolean(
    status === "aborted" || status === "computed" ||
    (showChildrenForComputingStatus && status === "computing")
  );

  if(showChildren) return <>{children}</>;
  else return (
    <div className={"eva-status eva-status-"+status}>
      <span>{infosStatus.message}</span>
      <StatusIcon size={130} status={status} />
    </div>
  );
}
