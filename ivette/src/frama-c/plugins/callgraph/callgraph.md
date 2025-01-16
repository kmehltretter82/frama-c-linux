# Callgraph {#callgraph}

This module provides a graphical display of the callgraph and makes it easy to highlight certain data, such as :

* The location of unproven properties.
* Functions containing tainted properties.
* ...

Below is a list of shortcuts:

* In the graph:
  * Left-click: rotate the graph
  * Right-click: move in the graph
  * Mouse-wheel: zoom
* On nodes:
  * Left-Click: select node (in the graph)
  * Ctrl+click: add node to the selected nodes (multi-selection)
  * Alt+click: select function (in all Ivette components)

This component is divided into 4 parts, the [titlebar](#plugins-callgraph-titlebar), the [toolbar](#plugins-callgraph-toolbar), a [panel](#plugins-callgraph-panel) and a [graph](#plugins-callgraph-graph).

### Titlebar {#callgraph-titlebar}

The titlebar contains the name of the module on the left and the following buttons on the right:

* [icon-tunings] : Filter functions appearing in the graph. Ce filtre est synchronisé avec celui de la sidebar.
* [icon-target] : Move the camera to show each node after each render.
* [icon-pin] : Automatically select node of the function selected in AST.
* [icon-help] : show this help modal.

##Toolbar {#plugins-callgraph-toolbar}

The toolbar contains display and selection parameters on the left and graph management parameters on the right.
On the far right is the button for opening the side panel.

On the left, there is a group of buttons for selecting the nodes that will appear in the graph :

* The first group of buttons is used to select the nodes that will appear in the graph...
  *  Try yourself : [button-displaymode]
* [button-select] :This button allows you to select a list of predefined nodes (nodes with unproven properties, with tainted variables, etc.).

On the right:

* Horizontal and vertical distance management between graph nodes.
* [icon-sidebar] : Opens or closes the side panel.

## Panel {#callgraph-panel}

The panel displays additional information about the graph in general and about the properties of the selected nodes.
The filters above the list can be used to limit the amount of information, and are synchronised with the filters in the `Properties` component.

At the top right, 2 buttons allow you to change the side of the panel and close it.

## Graph {#callgraph-graph}

The graph is in 3D but is displayed as a tree. This type of display prevents cycles from appearing in the graph.

If a cycle is detected :

* In the case of a recursive function: The link is deleted and the [icon-redo-orange] icon is added to the node.
* In the case of a cycle on several functions: The cycles will be pre-selected and will appear in the selection button.

### Nodes

The nodes display the name of the function and the following elements:

* [led-warning] : The function contains unproven properties, a tooltip gives the quantity.
* [led-negative] : The function contains false properties, a tooltip gives the quantity.
* [icon-redo-orange] : The function is recursive.
* [icon-drop.filled-#882288][icon-drop.filled-#73BBBB]: The function contains tainted properties.

### Edges

The edges are oriented and can take on different colours depending on the nodes selected.

* Green: the edge connects 2 selected nodes.
* Red: the edge links a selected node and one of its parents.
* Blue: the edge links a selected node and one of its children.
