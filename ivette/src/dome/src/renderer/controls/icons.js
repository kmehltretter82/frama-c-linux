// --------------------------------------------------------------------------
// --- SVG Icons
// --------------------------------------------------------------------------

/**
   @module dome/controls/icons
   @description
   Consult the [Icon Gallery](gallery-icons.html) for default icons.
   You can [register](#.register) new icons or override existing ones
   and [iterate](#.forEach) over the icon base.
*/

import React from 'react' ;
import Icons from './icons.json' ;
import './icons.css' ;
import _ from 'lodash' ;

// --------------------------------------------------------------------------
// --- Raw SVG element
// --------------------------------------------------------------------------

/**
   @property {string} id - icon's identifier (mandatory)
   @property {string} [title] - icon's tool-tip (optional)
   @property {number} [size] - icon's dimension in pixels (default: `12`)
   @property {number} [offset] - vertical alignment offset (default: `- size * 0.125`)
   @summary Raw SVG element.
   @description
   Consult the [Icon Gallery](gallery-icons.html) for default icons.
*/
export function SVG( { id , title, size, offset } )
{
  if (!id) return null;
  const icon = Icons[id];
  if (!icon) return id;
  if (size===undefined) size = 12 ;
  if (offset===undefined) offset = _.floor( - size * 0.125 );
  return (
    <svg height={size}
         width={size}
         style={{bottom: offset }}
         viewBox={icon.viewBox || "0 0 24 24"} >
      { title && <title>{title}</title> }
      <path d={icon.path}/>
    </svg>
  );
}

// --------------------------------------------------------------------------
// --- Icon Component
// --------------------------------------------------------------------------

/**
   @summary Icon Component.
   @property {string} id - icon's identifier (mandatory)
   @property {string} [title] - icon's tool-tip (optional)
   @property {function} [onClick] - callback when icon is clicked (optional)
   @property {string} [fill] - icon's fill color (optional)
   @property {number} [size] - icon's dimension in pixels (default `12`)
   @property {number} [offset] - vertical alignment offset (default `-size * 0.125`)
   @property {string} [className] - additional class name
   @property {object} [style] - additional styles
   @description
   Consult the [Icon Gallery](gallery-icons.html) for default icons.
*/
export function Icon(props)
{
  const { id, title, onClick, fill, size, className='', offset, style } = props;
  const divClass = 'dome-xIcon ' + className  ;
  const divStyle = fill ? Object.assign({fill},style) : style ;
  return (
    <div className={divClass}
         style={divStyle}
         onClick={onClick}>
      <SVG id={id} size={size} title={title} offset={offset} />
    </div>
  );
}

// --------------------------------------------------------------------------
// ---  Badge Component
// --------------------------------------------------------------------------

/**
   @summary Rounded icon, number or letter.
   @property {icon|number|string} [value] - badge content
   @property {string} [title] - badge tool-tip (optional)
   @property {function} [onClick] - badge on-click callback (optional)
   @description
   Depending on the type of value, display either a number,
   a label, or the corresponding named icon.
   Consult the [Icon Gallery](gallery-icons.html) for default icons.
*/
export function Badge( { value, title, onClick } )
{
  var content ;
  if (Icons[value]) {
    content = <Icon id={value} size={10} /> ;
  } else {
    const style =
          ( typeof(value) === 'number' && value < 10 ) ||
          ( typeof(value) === 'string' && value.length == 1 ) ?
          { paddingLeft: 2 , paddingRight: 2 } : {} ;
    content = <label style={style} className='dome-text-label'>{value}</label>;
  }
  return (
    <div className="dome-xBadge"
         title={title} onClick={onClick}>
      {content}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Icon Database
// --------------------------------------------------------------------------

/**
   @summary Register a new icon.
   @param {Object} icon - Icon's data to register (see below)
   @description
   The icon specification is an object with the following properties:
   - `name`: icon's name
   - `path`: svg path to draw the icon
   - `title`: title for the icon (optional)
   - `section`: section of the Icons (optional)
   - `viewBox`: svg view-box property (optional, `"0 0 24 24"` by default)
*/
export function register(icon) {
  const { name , ...deficon } = icon ;
  if (!name) console.error(`[Dome] Icon has no name (skipped).`);
  if (!deficon.path) console.error(`[Dome] Icon '${name}' has no path (skipped).`);
  Icons[name] = deficon ;
}

/**
   @summary Iterate over registered icons.
   @param {func} job - function applied to each icon
   @description
   See [register](#.register) for properties of the icon objects.
*/
export function forEach(job) {
  for( var name in Icons ) {
    job( Object.assign( { name } , Icons[name] ));
  }
}

// --------------------------------------------------------------------------
