// --------------------------------------------------------------------------
// --- Managing Errors
// --------------------------------------------------------------------------

import React from 'react' ;
import { Label } from 'dome/controls/labels' ;
import { Button } from 'dome/controls/buttons' ;

/** @module dome/errors */

// --------------------------------------------------------------------------
// --- Error Boundaries
// --------------------------------------------------------------------------

/**
   @summary React Error Boundaries.
   @property {string} [label] - Default error box label
   @property {function} [onError] - Alternative renderer
   @description
   Install an error boundary. In case of error, the default
   rendering is a warning button that output on console the
   catched error.

   An alternative rendering can be supplied
   with `onError:(error,info) => React.Element`.

 */
export class Catch extends React.Component
{

  constructor(props) {
    super(props);
    this.state = { };
    this.logerr = this.logerr.bind(this);
    this.reload = this.reload.bind(this);
  }

  dumpError(error,info) {
  }

  componentDidCatch(error, info) {
    this.setState({ error, info });
  }

  logerr() {
    const { error, info } = this.state ;
    console.error('[dome] Catched error:',error,info);
  }

  reload() {
    this.setState({ error: undefined, info: undefined });
  }

  render() {
    const { error, info } = this.state ;
    if (error) {
      const { onError, label='Error' } = this.props ;
      if (typeof(onError)==='function')
        return onError(error,info,this.reload);
      else
        return (
          <div>
            <Button icon='WARNING' kind='warning'
                    title={error}
                    onClick={this.logerr} />
            <Button icon='RELOAD' onClick={this.reload} />
            <Label>{label}</Label>
          </div>
        );
    }
    return this.props.children || null ;
  }
}

// --------------------------------------------------------------------------
