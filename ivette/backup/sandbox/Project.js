import React, { useState, useEffect } from 'react';
import { showOpenFiles } from 'dome/dialogs';
import { Button } from 'dome/controls/buttons';
import { Label } from 'dome/controls/labels';
import { Badge } from 'dome/controls/icons';
import { Hbox, Vbox } from 'dome/layout/boxes';
import Server from './server';
import { Set } from 'immutable';

class SelectList extends React.Component {
  render() {
    return (
      <select value={this.props.value} onChange={this.props.onChange}>
        {this.props.values.map(v => <option key={v.id}>{v.name}</option>)}
      </select>
    )
  }
}

function FileSelect(props) {
  const [files, setFiles] = useState(Set([]));
  const [addedFiles, setAddedFiles] = useState(Set([]));
  const [removedFiles, setRemovedFiles] = useState(Set([]));

  function updateFiles() {
    Server
      .sendGET("kernel.ast.getFiles", [], false)
      .then(
        (data) => {
          console.log("success: " + data + '\n');
          setFiles(Set(data));
          setAddedFiles(Set([]));
          setRemovedFiles(Set([]));
        },
        (_rid, data) => {
          console.log("err:" + data + '\n')
        });
  };

  //Done only once
  useEffect(updateFiles, []);

  function addFiles() {
    showOpenFiles({ message: "Add files" })
      .then(files => {
        setAddedFiles(() => {
          const sfiles = Set(files);
          const res = addedFiles.union(sfiles);
          return res
        })
      });
  };

  function generateItem(v) {
    const removed = removedFiles.has(v);
    const added = addedFiles.has(v);
    return (
      <Hbox key={v}>
        <Label
          style={(removed ? { color: 'red' } : (added ? { color: 'green' } : {}))}>
          {v}
        </Label>
        <Badge
          value={removed ? 'CIRC.PLUS' : 'CIRC.MINUS'}
          onClick={() =>
            setRemovedFiles(() =>
              removed ? removedFiles.remove(v) : removedFiles.add(v))
          } />
      </Hbox>
    )
  };

  function sendFiles() {
    const filesToSend = files.union(addedFiles).subtract(removedFiles);
    Server
      .sendSET("kernel.ast.setFiles", filesToSend.toArray(), false)
      .then(
        () => {
          console.log("setFiles: success");
          Server
            .sendEXEC("kernel.ast.execCompute", [], false)
            .then(
              () => {
                console.log("execComput: success");
                updateFiles();
              },
              (_rid, data) => {
                console.log("execCompute err:" + data + '\n')
              }
            );
        },
        (_rid, data) => {
          console.log("setFiles err:" + data + '\n')
        }
      );
  };

  return (
    <Vbox>
      {files.map(generateItem)}
      {addedFiles.map(generateItem)}
      <Hbox>
        <Button label='Add files' onClick={addFiles} />
        <Button label='Update' onClick={sendFiles} />
      </Hbox>
    </Vbox>
  )
}

function Projects(props) {
  const [projects, setProjects] = useState([]);
  const [current, setCurrent] = useState(undefined);
  const [newName, setNewName] = useState("project_name");


  function updateProjects() {
    Server
      .sendGET("kernel.project.getList", [], false)
      .then(
        (data) => {
          console.log("success: " + data.datadir + '\n');
          setProjects(data)
        },
        (_rid, data) => {
          console.log("err:" + data + '\n')
        });
  };

  //Done only once
  useEffect(updateProjects, []);

  function new_project() {
    Server
      .sendSET("kernel.project.setCreate", newName, false)
      .then(
        (data) => {
          console.log("success: " + data.datadir + '\n');
          updateProjects();
        },
        (_rid, data) => {
          console.log("err:" + data + '\n')
        });
  };


  console.log("projects:", projects);
  return (
    <Hbox>
      <form onSubmit={new_project}>
        <label>
          Name of new project :
          <input
            type="text"
            value={newName}
            onChange={event => setNewName(event.target.value)}
          />
        </label>
        <input type="submit" value="Create" />
      </form>
      <label>
        Current project:
        <SelectList
          values={projects}
          value={current}
          onChange={event => setCurrent(event.target.value)}
        />
      </label>
    </Hbox>
  )
}

function Kernel(props) {
  const [state, setState] = useState("undefined");

  function getCfg() {
    console.log("send request\n");
    Server
      .sendGET("kernel.getConfig", [], false)
      .then(
        (data) => {
          console.log("success: " + data.datadir + '\n');
          setState(data.datadir);
        },
        (_rid, data) => {
          console.log("err:" + data + '\n')
        });
  };

  return (
    <Hbox>
      <Button label='GetConfig' onClick={getCfg} />
      <Label label={state} />
    </Hbox>
  )
}

export default function Project(props) {

  return (
    <>
      <Kernel />
      <Projects />
      <FileSelect />
    </>
  )
}