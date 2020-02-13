import React, { useState, useEffect } from 'react';
import { Buffer } from 'dome/text/buffers'
import { Text } from 'dome/text/editors';
import Server from './server';
import System from 'dome/system';
import 'codemirror/mode/clike/clike.js';

export default function SourceFiles() {

  const [filenames, setFilenames] = useState([]);
  const buffer = new Buffer({ mode: 'text/x-csrc' });

  function getSourceFilenames() {
    console.log('SourceFiles::getFiles');

    Server
      .sendGET("kernel.ast.getFiles", [], false)
      .then(
        (fnames) => {
          console.log('Got source filenames:' + fnames);
          setFilenames(fnames);
        });
  }

  useEffect(getSourceFilenames, []);

  useEffect(() => {
    if (filenames.length > 0) {
      console.log('Displaying ' + filenames[0] + '!');
      System
        .readFile(filenames[0])
        .then(
          (fcontent) => {
            console.log('Got file content: ' + fcontent);
            buffer.clear();
            buffer.append(fcontent);
          });
    }
  }, [filenames])

  return (
    <Text buffer={buffer} readOnly='true' lineNumbers='true' />
  )
}
