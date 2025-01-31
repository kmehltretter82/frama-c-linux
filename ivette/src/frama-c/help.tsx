/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2025                                                */
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
import { Modal } from 'dome/dialogs';
import { Hbox } from 'dome/layout/boxes';

import { shell } from 'electron';
import { Button } from 'dome/controls/buttons';
import * as Server from 'frama-c/server';
import * as Dialogs from 'dome/dialogs';
import { getConfig } from 'frama-c/kernel/api/services';

import './style.css';
import framacImage from './frama-c.png';

/* -------------------------------------------------------------------------- */
/* --- Frama-C infos                                                      --- */
/* -------------------------------------------------------------------------- */

const synopsis = 'Frama-C is a suite of tools dedicated to the analysis of the\
source code of software written in C.';
const description = '\
Frama-C gathers several analysis techniques in a single collaborative\
framework, based on analyzers (called "plug-ins") that can build upon the\
results computed by other analyzers in the framework.\
Thanks to this approach, Frama-C provides sophisticated tools, including:\
- an analyzer based on abstract interpretation (Eva plug-in);\
- a program proof framework based on weakest precondition calculus\
 (WP plug-in);\
- a program slicer (Slicing plug-in);\
- a tool for verification of automata-based properties (Aoraï plug-in);\
- a runtime verification tool (E-ACSL plug-in);\
- several tools for code base exploration and dependency analysis\
  (plug-ins From, Impact, Metrics, Occurrence, Scope, etc.).\
These plug-ins communicate between each other via the Frama-C API\
and via ACSL (ANSI/ISO C Specification Language) properties.\
';
const authors = [
    'Michele Alberti',
    'Thibaud Antignac',
    'Gergö Barany',
    'Patrick Baudin',
    'Nicolas Bellec',
    'Thibaut Benjamin',
    'Allan Blanchard',
    'Lionel Blatter',
    'François Bobot',
    'Richard Bonichon',
    'Vincent Botbol',
    'Quentin Bouillaguet',
    'David Bühler',
    'Zakaria Chihani',
    'Loïc Correnson',
    'Julien Crétin',
    'Pascal Cuoq',
    'Zaynah Dargaye',
    'Basile Desloges',
    'Jean-Christophe Filliâtre',
    'Philippe Herrmann',
    'Maxime Jacquemin',
    'Florent Kirchner',
    'Alexander Kogtenkov',
    'Remi Lazarini',
    'Tristan Le Gall',
    'Kilyan Le Gallic',
    'Jean-Christophe Léchenet',
    'Matthieu Lemerre',
    'Dara Ly',
    'David Maison',
    'Claude Marché',
    'André Maroneze',
    'Thibault Martin',
    'Fonenantsoa Maurica',
    'Melody Méaulle',
    'Benjamin Monate',
    'Yannick Moy',
    'Pierre Nigron',
    'Anne Pacalet',
    'Valentin Perrelle',
    'Guillaume Petiot',
    'Dario Pinto',
    'Virgile Prevosto',
    'Armand Puccetti',
    'Félix Ridoux',
    'Virgile Robles',
    'Jan Rochel',
    'Muriel Roger',
    'Cécile Ruet-Cros',
    'Julien Signoles',
    'Nicolas Stouls',
    'Kostyantyn Vorobyov',
    'Boris Yakobowski'
  ];
const homepage = 'https://frama-c.com/';
const devRepo = 'git+https://git.frama-c.com/pub/frama-c.git';
const doc = 'https://frama-c.com/download/user-manual-30.0-Zinc.pdf';
const bugReports = 'https://git.frama-c.com/pub/frama-c/issues';

const license = 'Licenses of the Frama-C kernel and plug-ins are either under \
LGPL v2.1, or BSD.\n\
See the particular header of each source file for details.';
const copyright = "© CEA and INRIA for the Frama-C kernel\n\
© CEA for the GUI and plug-ins constant propagation, from, inout, impact, \
metrics, occurrence pdg, scope, security_slicing, \
semantic callgraph, slicing, sparecode, syntactic callgraph, users and value.";

/* -------------------------------------------------------------------------- */
/* --- Frama-C About                                                      --- */
/* -------------------------------------------------------------------------- */

function FramaCLogo(): JSX.Element {
  return (
    <Hbox>
      <img src={framacImage} alt="Frama-C: Software analyzers"/>
    </Hbox>
  );
}

interface AboutProps {
  version: string;
}

function AboutModal(props: AboutProps): JSX.Element {
  return (
    <Modal className='modal-framac-infos' label='About Frama-C'>
      <>
        <FramaCLogo />
        <Hbox className='modal-framac-about'>
          <pre>version: {props.version}</pre>
          <pre>{synopsis}</pre>
          <Hbox>
            <Button
              onClick={() => shell.openExternal(homepage)}
              label='Questions and support' />
            <Button
              onClick={() => shell.openExternal(doc)}
              label='Documentation' />
            <Button
              onClick={() => shell.openExternal(bugReports)}
              label='Bug reports' />
            <Button
              onClick={() => shell.openExternal(devRepo)}
              label='Git repository' />
          </Hbox>
          <pre>{description}</pre>
          <pre>{copyright}</pre>
          <pre>{license}</pre>
        </Hbox>
      </>
    </Modal>
  );
}

export async function showAboutModal(): Promise<void> {
  const config = await Server.send(getConfig, {});
  const version = config.version_codename;
  const modal = <AboutModal version = {version}/>;
  Dialogs.showModal(modal);
}

function CreditsModal(): JSX.Element {
  return (
    <Modal className='modal-framac-infos' label='Credits'>
      <>
        <FramaCLogo />
        <Hbox>
          <pre style={{ fontSize: '1.2em' }}>Created by:</pre>
        </Hbox>
        <div className='modal-framac-credits'>
          {authors.map((author, i) => <div key={i} >{author}</div>)}
        </div>
      </>
    </Modal>
  );
}

export function showCreditsModal(): void {
  const modal = <CreditsModal/>;
  Dialogs.showModal(modal);
}
