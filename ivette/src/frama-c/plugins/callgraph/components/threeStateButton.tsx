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

import React from 'react';
import { Button, ButtonGroup } from 'dome/frame/toolbars';

/* -------------------------------------------------------------------------- */
/* --- ThreeStateButton component                                         --- */
/* -------------------------------------------------------------------------- */
export interface IThreeStateButton {
  active: boolean,
  max: boolean,
  value: number,
}

interface ThreeStateButtonProps {
  label?: string;
  icon?: string;
  title?: string;
  buttonState: [
    IThreeStateButton,
    (newValue: IThreeStateButton) => void
  ];
}

export function ThreeStateButton(
  props: ThreeStateButtonProps
): JSX.Element {
  const { label, icon, title, buttonState } = props;
  const [ button, setButton ] = buttonState;

  const onClickAll = (): void =>
    setButton({ ...button, active: !button.max, max: !button.max });
  const onClickVal = (): void => {
    const newVal = button.max ? true : !button.active;
    setButton({ ...button, active: newVal, max: false }
  ); };
  const onUpVal = (): void =>
    setButton({ ...button, value: button.value ? button.value + 1 : 1 });
  const onDownVal = (): void =>
    setButton({ ...button, value: button.value ? button.value - 1 : 0 });

  return (
    <div className='cg-three-states'>
      <ButtonGroup className='cg-number-button'>
        <Button
          className="three-button-label"
          label={label} icon={icon} title={title}
        />
        <Button label="All" selected={button.max} onClick={onClickAll} />
        <Button
          label={button.value.toString()}
          selected={button.active && !button.max}
          onClick={onClickVal}
        />
        <Button icon='MINUS' className='cg-plus-minus' onClick={onDownVal} />
        <Button icon='PLUS'  className='cg-plus-minus' onClick={onUpVal} />
      </ButtonGroup>
    </div>
  );
}
