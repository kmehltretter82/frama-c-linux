# Project Management

The Frama-C current project can be managed with the server requests provided below.

## Current Project

Initially, the current project is the one selected when the server starts.
Hence, from the Frama-C command line, `-then-on <P> -server-xxx`
would start the server with current project `<P>`.

When modifying the current project through request `Kernel.Project.SetCurrent`,
client shall wait for an acknowledgement before sending further `GET` requests.
Otherwise, the `GET` might be executed on a different project, due to the
asynchronous behavior of the server.

However, it is still possible to execute a request on a specific project with
`Kernel.Project.{Get|Set|Exec}On` requests.

## Project Informations {#project-info}

The JSON encoding for `project-info` is a record with the following fields:

| Field | Type | Description |
|:-----:|:----:|:------------|
| `"id"` | _string_ | Project unique name |
| `"name"` | _string_ | Project descriptive name |
| `"current"` | _boolean_ | Currently selected project |

When used as _input_ parameter of a request, the project unique name can be used instead of the full project info.

## Request Delegation {#request-info}

To send a request on a specific project, the requests `Kernel.Project.{Get|Set|Exec}On` takes a input parameter
a record `request-info` with the following fields:

| Field | Type | Description |
|:-----:|:----:|:------------|
| `"project"` | [project-info](#project-info) | Project to execute the request on |
| `"request"` | _string_ | The request name |
| `"data"` | _any_ | The request data |
