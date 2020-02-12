// --------------------------------------------------------------------------
// --- A Ghost Component aware of its enclosing positionned container
// --------------------------------------------------------------------------

import React from 'react' ;
import Props from 'prop-types' ;

const SIZED = {
  display: 'block',
  position: 'absolute',
  top: 0,
  left: 0,
  height: '100%',
  width: '100%',
  overflow: 'hidden',
  pointerEvents: 'none',
  zIndex: -1
};

// --------------------------------------------------------------------------
// --- Components
// --------------------------------------------------------------------------

/*
   This component is a ghost element to be inserted inside a _positionned_
   container.  It makes the container aware of its bounding client rectangle
   _via_ the `onResize` property.

   The `onResize` callback is invoked whenever the parent container is
   positionned or resized. The callback is passed the
   `container.getBoundingClientRect()` rectangle.
*/
export class Layout extends React.Component {

  // Init the element
  componentDidMount() {
    this.element.data = 'about:blank';
    this.handleResize = this.handleResize.bind(this);
  }

  // Callback on Resize
  handleResize() {
    if (this.props.onResize) {
      const r = this.element.getBoundingClientRect();
      this.props.onResize(r);
    }
  }

  componentWillUnmount() {
    if (this.state.view)
      this.state.view.removeEventListener('resize', this.handleResize);
  }

  render() {
    return React.createElement('object', {
      type: 'text/html', style: SIZED,
      ref: elt => { this.element = elt; },
      onLoad: evt => {
        this.setState(
          { view: evt.target.contentDocument.defaultView },
          () => {
            this.state.view.addEventListener('resize', this.handleResize);
            this.handleResize();
          }
        );
      }
    });
  }

}

// --------------------------------------------------------------------------
// --- Props & Defaults
// --------------------------------------------------------------------------

Layout.propTypes = { onResize: Props.func };
Layout.defaultProps = { };

export default { Layout };

// --------------------------------------------------------------------------
