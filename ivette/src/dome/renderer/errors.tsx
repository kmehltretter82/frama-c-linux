// --------------------------------------------------------------------------
// --- Managing Errors
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/errors
*/

import React from 'react';
import { Label } from 'dome/controls/labels';
import { Button } from 'dome/controls/buttons';

// --------------------------------------------------------------------------
// --- Error Boundaries
// --------------------------------------------------------------------------

/**
   Alternative renderer in case of error.
   @param reload - callback for re-rendering the faulty component
 */
export interface ErrorRenderer {
  (error: any, info: any, reload: () => void): JSX.Element;
}

export interface CatchProps {
  /** Name of the error boundary. */
  label?: string;
  /** Alternative renderer callback in case of errors. */
  onError?: JSX.Element | ErrorRenderer;
}

interface CatchState {
  error?: any;
  info?: any;
}

/**
   React Error Boundaries.
 */
export class Catch extends React.Component<CatchProps, CatchState, {}> {

  constructor(props: CatchProps) {
    super(props);
    this.state = {};
    this.logerr = this.logerr.bind(this);
    this.reload = this.reload.bind(this);
  }

  componentDidCatch(error: any, info: any) {
    this.setState({ error, info });
  }

  logerr() {
    const { error, info } = this.state;
    console.error('[dome] Catched error:', error, info);
  }

  reload() {
    this.setState({ error: undefined, info: undefined });
  }

  render() {
    const { error, info } = this.state;
    if (error) {
      const { onError, label = 'Error' } = this.props;
      if (typeof (onError) === 'function')
        return onError(error, info, this.reload);
      return (
        <div>
          <Button
            icon="WARNING"
            kind="warning"
            title={error}
            onClick={this.logerr}
          />
          <Button icon="RELOAD" onClick={this.reload} />
          <Label>{label}</Label>
        </div>
      );
    }
    return this.props.children || null;
  }
}

// --------------------------------------------------------------------------
