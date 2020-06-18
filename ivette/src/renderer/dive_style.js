export default [
  {
    selector: 'node',
    style: {
      'shape': 'rectangle',
      'background-color': '#666',
      'label': 'data(id)',
      'color': 'white',
      'text-outline-width': 2,
      'text-outline-color': '#666',
      'text-valign' : 'center',
      'width': 'label',
      'padding' : '6px',
      'border-width': 1,
      'text-wrap' : 'wrap'
    }
  },
  {
    selector: 'node:selected',
    style: {
      'overlay-color': '#8bf',
      'overlay-padding': '10px',
      'overlay-opacity': 0.4
    }
  },
  {
    selector: 'edge:selected',
    style: {
      'color': '#48f',
      'overlay-color': '#8bf',
      'overlay-padding': '10px',
      'overlay-opacity': 0.4
    }
  },
  {
    selector: 'node[label]',
    style: {
      'label': 'data(label)'
    }
  },
  {
    selector: 'edge',
    style: {
      'width': 2,
      'line-color': '#888',
      'curve-style': 'bezier',
      'target-arrow-shape': 'vee',
      'target-arrow-color': '#888',
      'arrow-scale': 2.0
    }
  },
  {
    selector: '.function',
    style: {
      'shape': 'rectangle',
      'background-color': '#bbb',
      'background-opacity' : 0.4,
      'text-valign' : 'top',
      'text-halign' : 'center',
      'padding' : '10px',
      'border-width': 1
    }
  },
  {
    selector: '.file',
    style: {
      'shape': 'rectangle',
      'background-color': '#ddd',
      'background-opacity' : 0.4,
      'text-valign' : 'top',
      'text-halign' : 'center',
      'padding' : '10px',
      'border-width': 1
    }
  },
  {
    selector: 'node[float_range]',
    style: {
      'background-width-relative-to': 'include-padding',
      backgroundFill: 'linear-gradient',
      backgroundGradientDirection: 'to-left',
      backgroundGradientStopPositions: (ele) => {
        let r = ele.data('float_range') / 2;
        return `0% 0% ${r}% ${100-r}% 100% 100%`;
      }
    }
  },
  {
    selector: 'node[int_range]',
    style: {
      'background-width-relative-to': 'include-padding',
      backgroundFill: 'linear-gradient',
      backgroundGradientDirection: 'to-left',
      backgroundGradientStopPositions: (ele) => {
        let r = ele.data('int_range') / 2;
        return `0% ${r}% ${r}% ${100-r}% ${100-r}% 100%`;
      }
    }
  },
  {
    selector: 'node[grade="singleton"]',
    style: {
      'background-gradient-stop-colors': '#acf #acf #acf #acf #acf #acf',
      'background-color': '#acf',
      'border-color': '#8af'
    }
  },
  {
    selector: 'node[grade="normal"]',
    style: {
      'background-gradient-stop-colors': '#4c2 #4c2 #bea #bea #4c2 #4c2',
      'border-color': '#898'
    }
  },
  {
    selector: 'node[grade="wide"]',
    style: {
      'background-gradient-stop-colors': '#e44 #e44 #faa #faa #e44 #e44',
      'border-color': '#f88'
    }
  },
  {
    selector: 'node[kind="alarm"]',
    style: {
      'shape': 'octagon',
      'background-color': '#f00',
      'border-width': 0
    }
  },
  {
    selector: 'node[kind="scattered"]',
    style: {
      'shape': 'rhomboid'
    }
  },
  {
    selector: 'node[kind="composite"]',
    style: {
      'ghost': 'yes',
      'ghost-offset-x': '6px',
      'ghost-offset-y': '6px',
      'ghost-opacity': '0.7'
    }
  },
  {
    selector: 'node[kind][!explored]',
    style: {
      'opacity' : '0.3'
    }
  },
  {
    selector: '.callee',
    style: {
      'line-color': '#8f8',
      'target-arrow-color': '#8f8'
    }
  }
];
