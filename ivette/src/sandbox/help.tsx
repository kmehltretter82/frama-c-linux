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

/* -------------------------------------------------------------------------- */
/* --- Sandbox Testing for Force Graph component                          --- */
/* -------------------------------------------------------------------------- */

import React from 'react';
import { registerSandbox, TitleBar } from 'ivette';
import { HelpMarkdown, IconHelpModalMd } from 'dome/help';
import docSandbox from './sandbox.md?raw';

// --------------------------------------------------------------------------
// --- Main force graph component
// --------------------------------------------------------------------------

function SandboxHelp(): JSX.Element {
  return (
    <>
      <TitleBar>
        <IconHelpModalMd
          modal={{ label: 'docsandbox - Help' }}
          initialScrollTo={'help'}
        >{ docSandbox }</IconHelpModalMd>
      </TitleBar>
      <HelpMarkdown initialScrollTo={'help'}>{ docSandbox }</HelpMarkdown>
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.help',
  label: 'Help',
  preferredPosition: 'ABCD',
  children: <SandboxHelp />,
});

// --------------------------------------------------------------------------
