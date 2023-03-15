/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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
import * as States from 'frama-c/states';
import * as Eva from 'frama-c/plugins/eva/api/general';
import Gallery from 'dome/controls/gallery.json';

import gearsIcon from '../images/gears.svg';
import './style.css';

const EvaReady: React.FC = ({children}) => {
  const state = States.useSyncValue(Eva.computationState);

  switch (state) {
    case undefined:
    case 'not_computed': {
      const icon = Gallery['CROSS'];
      return (
        <div className="eva-status eva-status-not-computed">
          <span>No Eva analysis has been run yet.</span>
          <svg viewBox={icon.viewBox} className="eva-status-icon">
            <path d={icon.path} fill='#e0e0e0' />
          </svg>
        </div>
      );
    }

    case 'computing':
      return (
        <div className="eva-status eva-status-computing">
          <span>Eva analysis in progress…</span>
          <img src={gearsIcon} className="eva-status-icon" />
        </div>
      );
    
    case 'computed':
      return <>{children}</>;
  }
};

export default EvaReady;
