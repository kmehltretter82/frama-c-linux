#!/bin/node

const fs = require('fs');
const name = process.argv[2];
const INFOS = [
  'name',
  'version',
  'description',
  'homepage',
  'bugs',
  'keywords',
  'author',
  'contributors',
  'repository',
  'license'
];

const dst = {
  name,
  version: '0.1',
  license: 'UNLICENSED',
  main: 'bundle.js'
};

let src = './src/plugins/' + name + '/package.json' ;
let tgt = './dist/plugins/' + name + '/package.json' ;
let pkg = JSON.parse( fs.readFileSync( src , 'UTF-8' ) );
INFOS.forEach((fd) => { let d = pkg[fd] ; if (!d) dst[fd] = d });
fs.writeFileSync( tgt , JSON.stringify(dst) , 'UTF-8' );

// End.
