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

/* --- Generated Frama-C Server API --- */

/**
   All Frama-C parameters
   @packageDocumentation
   @module frama-c/kernel/api/parameters
*/

//@ts-ignore
import * as Json from 'dome/data/json';
//@ts-ignore
import * as Compare from 'dome/data/compare';
//@ts-ignore
import * as Server from 'frama-c/server';
//@ts-ignore
import * as State from 'frama-c/states';


/** Signal for state [`session`](#session)  */
export const signalSession: Server.Signal = {
  name: 'kernel.parameters.signalSession',
};

const getSession_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getSession',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`session`](#session)  */
export const getSession: Server.GetRequest<null,string>= getSession_internal;

const setSession_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setSession',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`session`](#session)  */
export const setSession: Server.SetRequest<string,null>= setSession_internal;

const session_internal: State.State<string> = {
  name: 'kernel.parameters.session',
  signal: signalSession,
  getter: getSession,
  setter: setSession,
};
/** State of parameter -session */
export const session: State.State<string> = session_internal;

/** Signal for state [`astDiff`](#astdiff)  */
export const signalAstDiff: Server.Signal = {
  name: 'kernel.parameters.signalAstDiff',
};

const getAstDiff_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAstDiff',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`astDiff`](#astdiff)  */
export const getAstDiff: Server.GetRequest<null,boolean>= getAstDiff_internal;

const setAstDiff_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAstDiff',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`astDiff`](#astdiff)  */
export const setAstDiff: Server.SetRequest<boolean,null>= setAstDiff_internal;

const astDiff_internal: State.State<boolean> = {
  name: 'kernel.parameters.astDiff',
  signal: signalAstDiff,
  getter: getAstDiff,
  setter: setAstDiff,
};
/** State of parameter -ast-diff */
export const astDiff: State.State<boolean> = astDiff_internal;

/** Signal for state [`eagerLoadSources`](#eagerloadsources)  */
export const signalEagerLoadSources: Server.Signal = {
  name: 'kernel.parameters.signalEagerLoadSources',
};

const getEagerLoadSources_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEagerLoadSources',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`eagerLoadSources`](#eagerloadsources)  */
export const getEagerLoadSources: Server.GetRequest<null,boolean>= getEagerLoadSources_internal;

const setEagerLoadSources_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEagerLoadSources',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`eagerLoadSources`](#eagerloadsources)  */
export const setEagerLoadSources: Server.SetRequest<boolean,null>= setEagerLoadSources_internal;

const eagerLoadSources_internal: State.State<boolean> = {
  name: 'kernel.parameters.eagerLoadSources',
  signal: signalEagerLoadSources,
  getter: getEagerLoadSources,
  setter: setEagerLoadSources,
};
/** State of parameter -eager-load-sources */
export const eagerLoadSources: State.State<boolean> = eagerLoadSources_internal;

/** Signal for state [`bigIntsHex`](#bigintshex)  */
export const signalBigIntsHex: Server.Signal = {
  name: 'kernel.parameters.signalBigIntsHex',
};

const getBigIntsHex_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getBigIntsHex',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`bigIntsHex`](#bigintshex)  */
export const getBigIntsHex: Server.GetRequest<null,number>= getBigIntsHex_internal;

const setBigIntsHex_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setBigIntsHex',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`bigIntsHex`](#bigintshex)  */
export const setBigIntsHex: Server.SetRequest<number,null>= setBigIntsHex_internal;

const bigIntsHex_internal: State.State<number> = {
  name: 'kernel.parameters.bigIntsHex',
  signal: signalBigIntsHex,
  getter: getBigIntsHex,
  setter: setBigIntsHex,
};
/** State of parameter -big-ints-hex */
export const bigIntsHex: State.State<number> = bigIntsHex_internal;

/** Signal for state [`floatHex`](#floathex)  */
export const signalFloatHex: Server.Signal = {
  name: 'kernel.parameters.signalFloatHex',
};

const getFloatHex_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getFloatHex',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`floatHex`](#floathex)  */
export const getFloatHex: Server.GetRequest<null,boolean>= getFloatHex_internal;

const setFloatHex_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setFloatHex',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`floatHex`](#floathex)  */
export const setFloatHex: Server.SetRequest<boolean,null>= setFloatHex_internal;

const floatHex_internal: State.State<boolean> = {
  name: 'kernel.parameters.floatHex',
  signal: signalFloatHex,
  getter: getFloatHex,
  setter: setFloatHex,
};
/** State of parameter -float-hex */
export const floatHex: State.State<boolean> = floatHex_internal;

/** Signal for state [`floatRelative`](#floatrelative)  */
export const signalFloatRelative: Server.Signal = {
  name: 'kernel.parameters.signalFloatRelative',
};

const getFloatRelative_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getFloatRelative',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`floatRelative`](#floatrelative)  */
export const getFloatRelative: Server.GetRequest<null,boolean>= getFloatRelative_internal;

const setFloatRelative_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setFloatRelative',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`floatRelative`](#floatrelative)  */
export const setFloatRelative: Server.SetRequest<boolean,null>= setFloatRelative_internal;

const floatRelative_internal: State.State<boolean> = {
  name: 'kernel.parameters.floatRelative',
  signal: signalFloatRelative,
  getter: getFloatRelative,
  setter: setFloatRelative,
};
/** State of parameter -float-relative */
export const floatRelative: State.State<boolean> = floatRelative_internal;

/** Signal for state [`floatNormal`](#floatnormal)  */
export const signalFloatNormal: Server.Signal = {
  name: 'kernel.parameters.signalFloatNormal',
};

const getFloatNormal_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getFloatNormal',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`floatNormal`](#floatnormal)  */
export const getFloatNormal: Server.GetRequest<null,boolean>= getFloatNormal_internal;

const setFloatNormal_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setFloatNormal',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`floatNormal`](#floatnormal)  */
export const setFloatNormal: Server.SetRequest<boolean,null>= setFloatNormal_internal;

const floatNormal_internal: State.State<boolean> = {
  name: 'kernel.parameters.floatNormal',
  signal: signalFloatNormal,
  getter: getFloatNormal,
  setter: setFloatNormal,
};
/** State of parameter -float-normal */
export const floatNormal: State.State<boolean> = floatNormal_internal;

/** Signal for state [`ocode`](#ocode)  */
export const signalOcode: Server.Signal = {
  name: 'kernel.parameters.signalOcode',
};

const getOcode_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getOcode',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`ocode`](#ocode)  */
export const getOcode: Server.GetRequest<null,string>= getOcode_internal;

const setOcode_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setOcode',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`ocode`](#ocode)  */
export const setOcode: Server.SetRequest<string,null>= setOcode_internal;

const ocode_internal: State.State<string> = {
  name: 'kernel.parameters.ocode',
  signal: signalOcode,
  getter: getOcode,
  setter: setOcode,
};
/** State of parameter -ocode */
export const ocode: State.State<string> = ocode_internal;

/** Signal for state [`printReturn`](#printreturn)  */
export const signalPrintReturn: Server.Signal = {
  name: 'kernel.parameters.signalPrintReturn',
};

const getPrintReturn_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getPrintReturn',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`printReturn`](#printreturn)  */
export const getPrintReturn: Server.GetRequest<null,boolean>= getPrintReturn_internal;

const setPrintReturn_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setPrintReturn',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`printReturn`](#printreturn)  */
export const setPrintReturn: Server.SetRequest<boolean,null>= setPrintReturn_internal;

const printReturn_internal: State.State<boolean> = {
  name: 'kernel.parameters.printReturn',
  signal: signalPrintReturn,
  getter: getPrintReturn,
  setter: setPrintReturn,
};
/** State of parameter -print-return */
export const printReturn: State.State<boolean> = printReturn_internal;

/** Signal for state [`printLibc`](#printlibc)  */
export const signalPrintLibc: Server.Signal = {
  name: 'kernel.parameters.signalPrintLibc',
};

const getPrintLibc_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getPrintLibc',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`printLibc`](#printlibc)  */
export const getPrintLibc: Server.GetRequest<null,boolean>= getPrintLibc_internal;

const setPrintLibc_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setPrintLibc',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`printLibc`](#printlibc)  */
export const setPrintLibc: Server.SetRequest<boolean,null>= setPrintLibc_internal;

const printLibc_internal: State.State<boolean> = {
  name: 'kernel.parameters.printLibc',
  signal: signalPrintLibc,
  getter: getPrintLibc,
  setter: setPrintLibc,
};
/** State of parameter -print-libc */
export const printLibc: State.State<boolean> = printLibc_internal;

/** Signal for state [`keepComments`](#keepcomments)  */
export const signalKeepComments: Server.Signal = {
  name: 'kernel.parameters.signalKeepComments',
};

const getKeepComments_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getKeepComments',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`keepComments`](#keepcomments)  */
export const getKeepComments: Server.GetRequest<null,boolean>= getKeepComments_internal;

const setKeepComments_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setKeepComments',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`keepComments`](#keepcomments)  */
export const setKeepComments: Server.SetRequest<boolean,null>= setKeepComments_internal;

const keepComments_internal: State.State<boolean> = {
  name: 'kernel.parameters.keepComments',
  signal: signalKeepComments,
  getter: getKeepComments,
  setter: setKeepComments,
};
/** State of parameter -keep-comments */
export const keepComments: State.State<boolean> = keepComments_internal;

/** Signal for state [`printAsIs`](#printasis)  */
export const signalPrintAsIs: Server.Signal = {
  name: 'kernel.parameters.signalPrintAsIs',
};

const getPrintAsIs_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getPrintAsIs',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`printAsIs`](#printasis)  */
export const getPrintAsIs: Server.GetRequest<null,boolean>= getPrintAsIs_internal;

const setPrintAsIs_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setPrintAsIs',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`printAsIs`](#printasis)  */
export const setPrintAsIs: Server.SetRequest<boolean,null>= setPrintAsIs_internal;

const printAsIs_internal: State.State<boolean> = {
  name: 'kernel.parameters.printAsIs',
  signal: signalPrintAsIs,
  getter: getPrintAsIs,
  setter: setPrintAsIs,
};
/** State of parameter -print-as-is */
export const printAsIs: State.State<boolean> = printAsIs_internal;

/** Signal for state [`print`](#print)  */
export const signalPrint: Server.Signal = {
  name: 'kernel.parameters.signalPrint',
};

const getPrint_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getPrint',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`print`](#print)  */
export const getPrint: Server.GetRequest<null,boolean>= getPrint_internal;

const setPrint_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setPrint',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`print`](#print)  */
export const setPrint: Server.SetRequest<boolean,null>= setPrint_internal;

const print_internal: State.State<boolean> = {
  name: 'kernel.parameters.print',
  signal: signalPrint,
  getter: getPrint,
  setter: setPrint,
};
/** State of parameter -print */
export const print: State.State<boolean> = print_internal;

/** Signal for state [`removeProjects`](#removeprojects)  */
export const signalRemoveProjects: Server.Signal = {
  name: 'kernel.parameters.signalRemoveProjects',
};

const getRemoveProjects_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRemoveProjects',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`removeProjects`](#removeprojects)  */
export const getRemoveProjects: Server.GetRequest<null,string>= getRemoveProjects_internal;

const setRemoveProjects_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRemoveProjects',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`removeProjects`](#removeprojects)  */
export const setRemoveProjects: Server.SetRequest<string,null>= setRemoveProjects_internal;

const removeProjects_internal: State.State<string> = {
  name: 'kernel.parameters.removeProjects',
  signal: signalRemoveProjects,
  getter: getRemoveProjects,
  setter: setRemoveProjects,
};
/** State of parameter -remove-projects */
export const removeProjects: State.State<string> = removeProjects_internal;

/** Signal for state [`setProjectAsDefault`](#setprojectasdefault)  */
export const signalSetProjectAsDefault: Server.Signal = {
  name: 'kernel.parameters.signalSetProjectAsDefault',
};

const getSetProjectAsDefault_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getSetProjectAsDefault',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`setProjectAsDefault`](#setprojectasdefault)  */
export const getSetProjectAsDefault: Server.GetRequest<null,boolean>= getSetProjectAsDefault_internal;

const setSetProjectAsDefault_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setSetProjectAsDefault',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`setProjectAsDefault`](#setprojectasdefault)  */
export const setSetProjectAsDefault: Server.SetRequest<boolean,null>= setSetProjectAsDefault_internal;

const setProjectAsDefault_internal: State.State<boolean> = {
  name: 'kernel.parameters.setProjectAsDefault',
  signal: signalSetProjectAsDefault,
  getter: getSetProjectAsDefault,
  setter: setSetProjectAsDefault,
};
/** State of parameter -set-project-as-default */
export const setProjectAsDefault: State.State<boolean> = setProjectAsDefault_internal;

/** Signal for state [`typecheck`](#typecheck)  */
export const signalTypecheck: Server.Signal = {
  name: 'kernel.parameters.signalTypecheck',
};

const getTypecheck_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getTypecheck',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`typecheck`](#typecheck)  */
export const getTypecheck: Server.GetRequest<null,boolean>= getTypecheck_internal;

const setTypecheck_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setTypecheck',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`typecheck`](#typecheck)  */
export const setTypecheck: Server.SetRequest<boolean,null>= setTypecheck_internal;

const typecheck_internal: State.State<boolean> = {
  name: 'kernel.parameters.typecheck',
  signal: signalTypecheck,
  getter: getTypecheck,
  setter: setTypecheck,
};
/** State of parameter -typecheck */
export const typecheck: State.State<boolean> = typecheck_internal;

/** Signal for state [`copy`](#copy)  */
export const signalCopy: Server.Signal = {
  name: 'kernel.parameters.signalCopy',
};

const getCopy_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getCopy',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`copy`](#copy)  */
export const getCopy: Server.GetRequest<null,boolean>= getCopy_internal;

const setCopy_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setCopy',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`copy`](#copy)  */
export const setCopy: Server.SetRequest<boolean,null>= setCopy_internal;

const copy_internal: State.State<boolean> = {
  name: 'kernel.parameters.copy',
  signal: signalCopy,
  getter: getCopy,
  setter: setCopy,
};
/** State of parameter -copy */
export const copy: State.State<boolean> = copy_internal;

/** Signal for state [`check`](#check)  */
export const signalCheck: Server.Signal = {
  name: 'kernel.parameters.signalCheck',
};

const getCheck_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getCheck',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`check`](#check)  */
export const getCheck: Server.GetRequest<null,boolean>= getCheck_internal;

const setCheck_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setCheck',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`check`](#check)  */
export const setCheck: Server.SetRequest<boolean,null>= setCheck_internal;

const check_internal: State.State<boolean> = {
  name: 'kernel.parameters.check',
  signal: signalCheck,
  getter: getCheck,
  setter: setCheck,
};
/** State of parameter -check */
export const check: State.State<boolean> = check_internal;

/** Signal for state [`dumpDependencies`](#dumpdependencies)  */
export const signalDumpDependencies: Server.Signal = {
  name: 'kernel.parameters.signalDumpDependencies',
};

const getDumpDependencies_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getDumpDependencies',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`dumpDependencies`](#dumpdependencies)  */
export const getDumpDependencies: Server.GetRequest<null,string>= getDumpDependencies_internal;

const setDumpDependencies_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setDumpDependencies',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`dumpDependencies`](#dumpdependencies)  */
export const setDumpDependencies: Server.SetRequest<string,null>= setDumpDependencies_internal;

const dumpDependencies_internal: State.State<string> = {
  name: 'kernel.parameters.dumpDependencies',
  signal: signalDumpDependencies,
  getter: getDumpDependencies,
  setter: setDumpDependencies,
};
/** State of parameter -dump-dependencies */
export const dumpDependencies: State.State<string> = dumpDependencies_internal;

/** Signal for state [`addSymbolicPath`](#addsymbolicpath)  */
export const signalAddSymbolicPath: Server.Signal = {
  name: 'kernel.parameters.signalAddSymbolicPath',
};

const getAddSymbolicPath_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAddSymbolicPath',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`addSymbolicPath`](#addsymbolicpath)  */
export const getAddSymbolicPath: Server.GetRequest<null,string>= getAddSymbolicPath_internal;

const setAddSymbolicPath_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAddSymbolicPath',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`addSymbolicPath`](#addsymbolicpath)  */
export const setAddSymbolicPath: Server.SetRequest<string,null>= setAddSymbolicPath_internal;

const addSymbolicPath_internal: State.State<string> = {
  name: 'kernel.parameters.addSymbolicPath',
  signal: signalAddSymbolicPath,
  getter: getAddSymbolicPath,
  setter: setAddSymbolicPath,
};
/** State of parameter -add-symbolic-path */
export const addSymbolicPath: State.State<string> = addSymbolicPath_internal;

/** Signal for state [`time`](#time)  */
export const signalTime: Server.Signal = {
  name: 'kernel.parameters.signalTime',
};

const getTime_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getTime',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`time`](#time)  */
export const getTime: Server.GetRequest<null,string>= getTime_internal;

const setTime_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setTime',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`time`](#time)  */
export const setTime: Server.SetRequest<string,null>= setTime_internal;

const time_internal: State.State<string> = {
  name: 'kernel.parameters.time',
  signal: signalTime,
  getter: getTime,
  setter: setTime,
};
/** State of parameter -time */
export const time: State.State<string> = time_internal;

/** Signal for state [`quiet`](#quiet)  */
export const signalQuiet: Server.Signal = {
  name: 'kernel.parameters.signalQuiet',
};

const getQuiet_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getQuiet',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`quiet`](#quiet)  */
export const getQuiet: Server.GetRequest<null,boolean>= getQuiet_internal;

const setQuiet_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setQuiet',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`quiet`](#quiet)  */
export const setQuiet: Server.SetRequest<boolean,null>= setQuiet_internal;

const quiet_internal: State.State<boolean> = {
  name: 'kernel.parameters.quiet',
  signal: signalQuiet,
  getter: getQuiet,
  setter: setQuiet,
};
/** State of parameter -quiet */
export const quiet: State.State<boolean> = quiet_internal;

/** Signal for state [`debug`](#debug)  */
export const signalDebug: Server.Signal = {
  name: 'kernel.parameters.signalDebug',
};

const getDebug_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getDebug',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`debug`](#debug)  */
export const getDebug: Server.GetRequest<null,number>= getDebug_internal;

const setDebug_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setDebug',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`debug`](#debug)  */
export const setDebug: Server.SetRequest<number,null>= setDebug_internal;

const debug_internal: State.State<number> = {
  name: 'kernel.parameters.debug',
  signal: signalDebug,
  getter: getDebug,
  setter: setDebug,
};
/** State of parameter -debug */
export const debug: State.State<number> = debug_internal;

/** Signal for state [`verbose`](#verbose)  */
export const signalVerbose: Server.Signal = {
  name: 'kernel.parameters.signalVerbose',
};

const getVerbose_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getVerbose',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`verbose`](#verbose)  */
export const getVerbose: Server.GetRequest<null,number>= getVerbose_internal;

const setVerbose_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setVerbose',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`verbose`](#verbose)  */
export const setVerbose: Server.SetRequest<number,null>= setVerbose_internal;

const verbose_internal: State.State<number> = {
  name: 'kernel.parameters.verbose',
  signal: signalVerbose,
  getter: getVerbose,
  setter: setVerbose,
};
/** State of parameter -verbose */
export const verbose: State.State<number> = verbose_internal;

/** Signal for state [`kernelWarnKey`](#kernelwarnkey)  */
export const signalKernelWarnKey: Server.Signal = {
  name: 'kernel.parameters.signalKernelWarnKey',
};

const getKernelWarnKey_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getKernelWarnKey',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`kernelWarnKey`](#kernelwarnkey)  */
export const getKernelWarnKey: Server.GetRequest<null,string>= getKernelWarnKey_internal;

const setKernelWarnKey_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setKernelWarnKey',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`kernelWarnKey`](#kernelwarnkey)  */
export const setKernelWarnKey: Server.SetRequest<string,null>= setKernelWarnKey_internal;

const kernelWarnKey_internal: State.State<string> = {
  name: 'kernel.parameters.kernelWarnKey',
  signal: signalKernelWarnKey,
  getter: getKernelWarnKey,
  setter: setKernelWarnKey,
};
/** State of parameter -kernel-warn-key */
export const kernelWarnKey: State.State<string> = kernelWarnKey_internal;

/** Signal for state [`kernelMsgKey`](#kernelmsgkey)  */
export const signalKernelMsgKey: Server.Signal = {
  name: 'kernel.parameters.signalKernelMsgKey',
};

const getKernelMsgKey_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getKernelMsgKey',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`kernelMsgKey`](#kernelmsgkey)  */
export const getKernelMsgKey: Server.GetRequest<null,string>= getKernelMsgKey_internal;

const setKernelMsgKey_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setKernelMsgKey',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`kernelMsgKey`](#kernelmsgkey)  */
export const setKernelMsgKey: Server.SetRequest<string,null>= setKernelMsgKey_internal;

const kernelMsgKey_internal: State.State<string> = {
  name: 'kernel.parameters.kernelMsgKey',
  signal: signalKernelMsgKey,
  getter: getKernelMsgKey,
  setter: setKernelMsgKey,
};
/** State of parameter -kernel-msg-key */
export const kernelMsgKey: State.State<string> = kernelMsgKey_internal;

/** Signal for state [`kernelDebug`](#kerneldebug)  */
export const signalKernelDebug: Server.Signal = {
  name: 'kernel.parameters.signalKernelDebug',
};

const getKernelDebug_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getKernelDebug',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`kernelDebug`](#kerneldebug)  */
export const getKernelDebug: Server.GetRequest<null,number>= getKernelDebug_internal;

const setKernelDebug_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setKernelDebug',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`kernelDebug`](#kerneldebug)  */
export const setKernelDebug: Server.SetRequest<number,null>= setKernelDebug_internal;

const kernelDebug_internal: State.State<number> = {
  name: 'kernel.parameters.kernelDebug',
  signal: signalKernelDebug,
  getter: getKernelDebug,
  setter: setKernelDebug,
};
/** State of parameter -kernel-debug */
export const kernelDebug: State.State<number> = kernelDebug_internal;

/** Signal for state [`kernelVerbose`](#kernelverbose)  */
export const signalKernelVerbose: Server.Signal = {
  name: 'kernel.parameters.signalKernelVerbose',
};

const getKernelVerbose_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getKernelVerbose',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`kernelVerbose`](#kernelverbose)  */
export const getKernelVerbose: Server.GetRequest<null,number>= getKernelVerbose_internal;

const setKernelVerbose_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setKernelVerbose',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`kernelVerbose`](#kernelverbose)  */
export const setKernelVerbose: Server.SetRequest<number,null>= setKernelVerbose_internal;

const kernelVerbose_internal: State.State<number> = {
  name: 'kernel.parameters.kernelVerbose',
  signal: signalKernelVerbose,
  getter: getKernelVerbose,
  setter: setKernelVerbose,
};
/** State of parameter -kernel-verbose */
export const kernelVerbose: State.State<number> = kernelVerbose_internal;

/** Signal for state [`kernelLog`](#kernellog)  */
export const signalKernelLog: Server.Signal = {
  name: 'kernel.parameters.signalKernelLog',
};

const getKernelLog_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getKernelLog',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`kernelLog`](#kernellog)  */
export const getKernelLog: Server.GetRequest<null,string>= getKernelLog_internal;

const setKernelLog_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setKernelLog',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`kernelLog`](#kernellog)  */
export const setKernelLog: Server.SetRequest<string,null>= setKernelLog_internal;

const kernelLog_internal: State.State<string> = {
  name: 'kernel.parameters.kernelLog',
  signal: signalKernelLog,
  getter: getKernelLog,
  setter: setKernelLog,
};
/** State of parameter -kernel-log */
export const kernelLog: State.State<string> = kernelLog_internal;

/** Signal for state [`state`](#state)  */
export const signalState: Server.Signal = {
  name: 'kernel.parameters.signalState',
};

const getState_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getState',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`state`](#state)  */
export const getState: Server.GetRequest<null,string>= getState_internal;

const setState_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setState',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`state`](#state)  */
export const setState: Server.SetRequest<string,null>= setState_internal;

const state_internal: State.State<string> = {
  name: 'kernel.parameters.state',
  signal: signalState,
  getter: getState,
  setter: setState,
};
/** State of parameter -state */
export const state: State.State<string> = state_internal;

/** Signal for state [`config`](#config)  */
export const signalConfig: Server.Signal = {
  name: 'kernel.parameters.signalConfig',
};

const getConfig_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getConfig',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`config`](#config)  */
export const getConfig: Server.GetRequest<null,string>= getConfig_internal;

const setConfig_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setConfig',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`config`](#config)  */
export const setConfig: Server.SetRequest<string,null>= setConfig_internal;

const config_internal: State.State<string> = {
  name: 'kernel.parameters.config',
  signal: signalConfig,
  getter: getConfig,
  setter: setConfig,
};
/** State of parameter -config */
export const config: State.State<string> = config_internal;

/** Signal for state [`cache`](#cache)  */
export const signalCache: Server.Signal = {
  name: 'kernel.parameters.signalCache',
};

const getCache_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getCache',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`cache`](#cache)  */
export const getCache: Server.GetRequest<null,string>= getCache_internal;

const setCache_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setCache',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`cache`](#cache)  */
export const setCache: Server.SetRequest<string,null>= setCache_internal;

const cache_internal: State.State<string> = {
  name: 'kernel.parameters.cache',
  signal: signalCache,
  getter: getCache,
  setter: setCache,
};
/** State of parameter -cache */
export const cache: State.State<string> = cache_internal;

/** Signal for state [`save`](#save)  */
export const signalSave: Server.Signal = {
  name: 'kernel.parameters.signalSave',
};

const getSave_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getSave',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`save`](#save)  */
export const getSave: Server.GetRequest<null,string>= getSave_internal;

const setSave_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setSave',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`save`](#save)  */
export const setSave: Server.SetRequest<string,null>= setSave_internal;

const save_internal: State.State<string> = {
  name: 'kernel.parameters.save',
  signal: signalSave,
  getter: getSave,
  setter: setSave,
};
/** State of parameter -save */
export const save: State.State<string> = save_internal;

/** Signal for state [`jsonCompilationDatabase`](#jsoncompilationdatabase)  */
export const signalJsonCompilationDatabase: Server.Signal = {
  name: 'kernel.parameters.signalJsonCompilationDatabase',
};

const getJsonCompilationDatabase_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getJsonCompilationDatabase',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`jsonCompilationDatabase`](#jsoncompilationdatabase)  */
export const getJsonCompilationDatabase: Server.GetRequest<null,string>= getJsonCompilationDatabase_internal;

const setJsonCompilationDatabase_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setJsonCompilationDatabase',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`jsonCompilationDatabase`](#jsoncompilationdatabase)  */
export const setJsonCompilationDatabase: Server.SetRequest<string,null>= setJsonCompilationDatabase_internal;

const jsonCompilationDatabase_internal: State.State<string> = {
  name: 'kernel.parameters.jsonCompilationDatabase',
  signal: signalJsonCompilationDatabase,
  getter: getJsonCompilationDatabase,
  setter: setJsonCompilationDatabase,
};
/** State of parameter -json-compilation-database */
export const jsonCompilationDatabase: State.State<string> = jsonCompilationDatabase_internal;

/** Signal for state [`c11`](#c11)  */
export const signalC11: Server.Signal = {
  name: 'kernel.parameters.signalC11',
};

const getC11_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getC11',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`c11`](#c11)  */
export const getC11: Server.GetRequest<null,boolean>= getC11_internal;

const setC11_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setC11',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`c11`](#c11)  */
export const setC11: Server.SetRequest<boolean,null>= setC11_internal;

const c11_internal: State.State<boolean> = {
  name: 'kernel.parameters.c11',
  signal: signalC11,
  getter: getC11,
  setter: setC11,
};
/** State of parameter -c11 */
export const c11: State.State<boolean> = c11_internal;

/** Signal for state [`origName`](#origname)  */
export const signalOrigName: Server.Signal = {
  name: 'kernel.parameters.signalOrigName',
};

const getOrigName_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getOrigName',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`origName`](#origname)  */
export const getOrigName: Server.GetRequest<null,boolean>= getOrigName_internal;

const setOrigName_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setOrigName',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`origName`](#origname)  */
export const setOrigName: Server.SetRequest<boolean,null>= setOrigName_internal;

const origName_internal: State.State<boolean> = {
  name: 'kernel.parameters.origName',
  signal: signalOrigName,
  getter: getOrigName,
  setter: setOrigName,
};
/** State of parameter -orig-name */
export const origName: State.State<boolean> = origName_internal;

/** Signal for state [`framaCStdlib`](#framacstdlib)  */
export const signalFramaCStdlib: Server.Signal = {
  name: 'kernel.parameters.signalFramaCStdlib',
};

const getFramaCStdlib_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getFramaCStdlib',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`framaCStdlib`](#framacstdlib)  */
export const getFramaCStdlib: Server.GetRequest<null,boolean>= getFramaCStdlib_internal;

const setFramaCStdlib_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setFramaCStdlib',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`framaCStdlib`](#framacstdlib)  */
export const setFramaCStdlib: Server.SetRequest<boolean,null>= setFramaCStdlib_internal;

const framaCStdlib_internal: State.State<boolean> = {
  name: 'kernel.parameters.framaCStdlib',
  signal: signalFramaCStdlib,
  getter: getFramaCStdlib,
  setter: setFramaCStdlib,
};
/** State of parameter -frama-c-stdlib */
export const framaCStdlib: State.State<boolean> = framaCStdlib_internal;

/** Signal for state [`auditCheck`](#auditcheck)  */
export const signalAuditCheck: Server.Signal = {
  name: 'kernel.parameters.signalAuditCheck',
};

const getAuditCheck_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAuditCheck',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`auditCheck`](#auditcheck)  */
export const getAuditCheck: Server.GetRequest<null,string>= getAuditCheck_internal;

const setAuditCheck_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAuditCheck',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`auditCheck`](#auditcheck)  */
export const setAuditCheck: Server.SetRequest<string,null>= setAuditCheck_internal;

const auditCheck_internal: State.State<string> = {
  name: 'kernel.parameters.auditCheck',
  signal: signalAuditCheck,
  getter: getAuditCheck,
  setter: setAuditCheck,
};
/** State of parameter -audit-check */
export const auditCheck: State.State<string> = auditCheck_internal;

/** Signal for state [`auditPrepare`](#auditprepare)  */
export const signalAuditPrepare: Server.Signal = {
  name: 'kernel.parameters.signalAuditPrepare',
};

const getAuditPrepare_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAuditPrepare',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`auditPrepare`](#auditprepare)  */
export const getAuditPrepare: Server.GetRequest<null,string>= getAuditPrepare_internal;

const setAuditPrepare_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAuditPrepare',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`auditPrepare`](#auditprepare)  */
export const setAuditPrepare: Server.SetRequest<string,null>= setAuditPrepare_internal;

const auditPrepare_internal: State.State<string> = {
  name: 'kernel.parameters.auditPrepare',
  signal: signalAuditPrepare,
  getter: getAuditPrepare,
  setter: setAuditPrepare,
};
/** State of parameter -audit-prepare */
export const auditPrepare: State.State<string> = auditPrepare_internal;

/** Signal for state [`printCppCommands`](#printcppcommands)  */
export const signalPrintCppCommands: Server.Signal = {
  name: 'kernel.parameters.signalPrintCppCommands',
};

const getPrintCppCommands_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getPrintCppCommands',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`printCppCommands`](#printcppcommands)  */
export const getPrintCppCommands: Server.GetRequest<null,boolean>= getPrintCppCommands_internal;

const setPrintCppCommands_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setPrintCppCommands',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`printCppCommands`](#printcppcommands)  */
export const setPrintCppCommands: Server.SetRequest<boolean,null>= setPrintCppCommands_internal;

const printCppCommands_internal: State.State<boolean> = {
  name: 'kernel.parameters.printCppCommands',
  signal: signalPrintCppCommands,
  getter: getPrintCppCommands,
  setter: setPrintCppCommands,
};
/** State of parameter -print-cpp-commands */
export const printCppCommands: State.State<boolean> = printCppCommands_internal;

/** Signal for state [`cppFramaCCompliant`](#cppframaccompliant)  */
export const signalCppFramaCCompliant: Server.Signal = {
  name: 'kernel.parameters.signalCppFramaCCompliant',
};

const getCppFramaCCompliant_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getCppFramaCCompliant',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`cppFramaCCompliant`](#cppframaccompliant)  */
export const getCppFramaCCompliant: Server.GetRequest<null,boolean>= getCppFramaCCompliant_internal;

const setCppFramaCCompliant_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setCppFramaCCompliant',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`cppFramaCCompliant`](#cppframaccompliant)  */
export const setCppFramaCCompliant: Server.SetRequest<boolean,null>= setCppFramaCCompliant_internal;

const cppFramaCCompliant_internal: State.State<boolean> = {
  name: 'kernel.parameters.cppFramaCCompliant',
  signal: signalCppFramaCCompliant,
  getter: getCppFramaCCompliant,
  setter: setCppFramaCCompliant,
};
/** State of parameter -cpp-frama-c-compliant */
export const cppFramaCCompliant: State.State<boolean> = cppFramaCCompliant_internal;

/** Signal for state [`cppExtraArgsPerFile`](#cppextraargsperfile)  */
export const signalCppExtraArgsPerFile: Server.Signal = {
  name: 'kernel.parameters.signalCppExtraArgsPerFile',
};

const getCppExtraArgsPerFile_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getCppExtraArgsPerFile',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`cppExtraArgsPerFile`](#cppextraargsperfile)  */
export const getCppExtraArgsPerFile: Server.GetRequest<null,string>= getCppExtraArgsPerFile_internal;

const setCppExtraArgsPerFile_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setCppExtraArgsPerFile',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`cppExtraArgsPerFile`](#cppextraargsperfile)  */
export const setCppExtraArgsPerFile: Server.SetRequest<string,null>= setCppExtraArgsPerFile_internal;

const cppExtraArgsPerFile_internal: State.State<string> = {
  name: 'kernel.parameters.cppExtraArgsPerFile',
  signal: signalCppExtraArgsPerFile,
  getter: getCppExtraArgsPerFile,
  setter: setCppExtraArgsPerFile,
};
/** State of parameter -cpp-extra-args-per-file */
export const cppExtraArgsPerFile: State.State<string> = cppExtraArgsPerFile_internal;

/** Signal for state [`cppExtraArgs`](#cppextraargs)  */
export const signalCppExtraArgs: Server.Signal = {
  name: 'kernel.parameters.signalCppExtraArgs',
};

const getCppExtraArgs_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getCppExtraArgs',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`cppExtraArgs`](#cppextraargs)  */
export const getCppExtraArgs: Server.GetRequest<null,string>= getCppExtraArgs_internal;

const setCppExtraArgs_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setCppExtraArgs',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`cppExtraArgs`](#cppextraargs)  */
export const setCppExtraArgs: Server.SetRequest<string,null>= setCppExtraArgs_internal;

const cppExtraArgs_internal: State.State<string> = {
  name: 'kernel.parameters.cppExtraArgs',
  signal: signalCppExtraArgs,
  getter: getCppExtraArgs,
  setter: setCppExtraArgs,
};
/** State of parameter -cpp-extra-args */
export const cppExtraArgs: State.State<string> = cppExtraArgs_internal;

/** Signal for state [`cppCommand`](#cppcommand)  */
export const signalCppCommand: Server.Signal = {
  name: 'kernel.parameters.signalCppCommand',
};

const getCppCommand_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getCppCommand',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`cppCommand`](#cppcommand)  */
export const getCppCommand: Server.GetRequest<null,string>= getCppCommand_internal;

const setCppCommand_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setCppCommand',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`cppCommand`](#cppcommand)  */
export const setCppCommand: Server.SetRequest<string,null>= setCppCommand_internal;

const cppCommand_internal: State.State<string> = {
  name: 'kernel.parameters.cppCommand',
  signal: signalCppCommand,
  getter: getCppCommand,
  setter: setCppCommand,
};
/** State of parameter -cpp-command */
export const cppCommand: State.State<string> = cppCommand_internal;

/** Signal for state [`ppAnnot`](#ppannot)  */
export const signalPpAnnot: Server.Signal = {
  name: 'kernel.parameters.signalPpAnnot',
};

const getPpAnnot_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getPpAnnot',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`ppAnnot`](#ppannot)  */
export const getPpAnnot: Server.GetRequest<null,boolean>= getPpAnnot_internal;

const setPpAnnot_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setPpAnnot',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`ppAnnot`](#ppannot)  */
export const setPpAnnot: Server.SetRequest<boolean,null>= setPpAnnot_internal;

const ppAnnot_internal: State.State<boolean> = {
  name: 'kernel.parameters.ppAnnot',
  signal: signalPpAnnot,
  getter: getPpAnnot,
  setter: setPpAnnot,
};
/** State of parameter -pp-annot */
export const ppAnnot: State.State<boolean> = ppAnnot_internal;

/** Signal for state [`annot`](#annot)  */
export const signalAnnot: Server.Signal = {
  name: 'kernel.parameters.signalAnnot',
};

const getAnnot_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAnnot',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`annot`](#annot)  */
export const getAnnot: Server.GetRequest<null,boolean>= getAnnot_internal;

const setAnnot_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAnnot',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`annot`](#annot)  */
export const setAnnot: Server.SetRequest<boolean,null>= setAnnot_internal;

const annot_internal: State.State<boolean> = {
  name: 'kernel.parameters.annot',
  signal: signalAnnot,
  getter: getAnnot,
  setter: setAnnot,
};
/** State of parameter -annot */
export const annot: State.State<boolean> = annot_internal;

/** Signal for state [`warnInvalidPointer`](#warninvalidpointer)  */
export const signalWarnInvalidPointer: Server.Signal = {
  name: 'kernel.parameters.signalWarnInvalidPointer',
};

const getWarnInvalidPointer_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnInvalidPointer',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`warnInvalidPointer`](#warninvalidpointer)  */
export const getWarnInvalidPointer: Server.GetRequest<null,boolean>= getWarnInvalidPointer_internal;

const setWarnInvalidPointer_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnInvalidPointer',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnInvalidPointer`](#warninvalidpointer)  */
export const setWarnInvalidPointer: Server.SetRequest<boolean,null>= setWarnInvalidPointer_internal;

const warnInvalidPointer_internal: State.State<boolean> = {
  name: 'kernel.parameters.warnInvalidPointer',
  signal: signalWarnInvalidPointer,
  getter: getWarnInvalidPointer,
  setter: setWarnInvalidPointer,
};
/** State of parameter -warn-invalid-pointer */
export const warnInvalidPointer: State.State<boolean> = warnInvalidPointer_internal;

/** Signal for state [`warnInvalidBool`](#warninvalidbool)  */
export const signalWarnInvalidBool: Server.Signal = {
  name: 'kernel.parameters.signalWarnInvalidBool',
};

const getWarnInvalidBool_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnInvalidBool',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`warnInvalidBool`](#warninvalidbool)  */
export const getWarnInvalidBool: Server.GetRequest<null,boolean>= getWarnInvalidBool_internal;

const setWarnInvalidBool_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnInvalidBool',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnInvalidBool`](#warninvalidbool)  */
export const setWarnInvalidBool: Server.SetRequest<boolean,null>= setWarnInvalidBool_internal;

const warnInvalidBool_internal: State.State<boolean> = {
  name: 'kernel.parameters.warnInvalidBool',
  signal: signalWarnInvalidBool,
  getter: getWarnInvalidBool,
  setter: setWarnInvalidBool,
};
/** State of parameter -warn-invalid-bool */
export const warnInvalidBool: State.State<boolean> = warnInvalidBool_internal;

/** Signal for state [`warnSpecialFloat`](#warnspecialfloat)  */
export const signalWarnSpecialFloat: Server.Signal = {
  name: 'kernel.parameters.signalWarnSpecialFloat',
};

const getWarnSpecialFloat_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnSpecialFloat',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`warnSpecialFloat`](#warnspecialfloat)  */
export const getWarnSpecialFloat: Server.GetRequest<null,string>= getWarnSpecialFloat_internal;

const setWarnSpecialFloat_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnSpecialFloat',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnSpecialFloat`](#warnspecialfloat)  */
export const setWarnSpecialFloat: Server.SetRequest<string,null>= setWarnSpecialFloat_internal;

const warnSpecialFloat_internal: State.State<string> = {
  name: 'kernel.parameters.warnSpecialFloat',
  signal: signalWarnSpecialFloat,
  getter: getWarnSpecialFloat,
  setter: setWarnSpecialFloat,
};
/** State of parameter -warn-special-float */
export const warnSpecialFloat: State.State<string> = warnSpecialFloat_internal;

/** Signal for state [`warnPointerDowncast`](#warnpointerdowncast)  */
export const signalWarnPointerDowncast: Server.Signal = {
  name: 'kernel.parameters.signalWarnPointerDowncast',
};

const getWarnPointerDowncast_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnPointerDowncast',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`warnPointerDowncast`](#warnpointerdowncast)  */
export const getWarnPointerDowncast: Server.GetRequest<null,boolean>= getWarnPointerDowncast_internal;

const setWarnPointerDowncast_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnPointerDowncast',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnPointerDowncast`](#warnpointerdowncast)  */
export const setWarnPointerDowncast: Server.SetRequest<boolean,null>= setWarnPointerDowncast_internal;

const warnPointerDowncast_internal: State.State<boolean> = {
  name: 'kernel.parameters.warnPointerDowncast',
  signal: signalWarnPointerDowncast,
  getter: getWarnPointerDowncast,
  setter: setWarnPointerDowncast,
};
/** State of parameter -warn-pointer-downcast */
export const warnPointerDowncast: State.State<boolean> = warnPointerDowncast_internal;

/** Signal for state [`warnUnsignedDowncast`](#warnunsigneddowncast)  */
export const signalWarnUnsignedDowncast: Server.Signal = {
  name: 'kernel.parameters.signalWarnUnsignedDowncast',
};

const getWarnUnsignedDowncast_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnUnsignedDowncast',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`warnUnsignedDowncast`](#warnunsigneddowncast)  */
export const getWarnUnsignedDowncast: Server.GetRequest<null,boolean>= getWarnUnsignedDowncast_internal;

const setWarnUnsignedDowncast_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnUnsignedDowncast',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnUnsignedDowncast`](#warnunsigneddowncast)  */
export const setWarnUnsignedDowncast: Server.SetRequest<boolean,null>= setWarnUnsignedDowncast_internal;

const warnUnsignedDowncast_internal: State.State<boolean> = {
  name: 'kernel.parameters.warnUnsignedDowncast',
  signal: signalWarnUnsignedDowncast,
  getter: getWarnUnsignedDowncast,
  setter: setWarnUnsignedDowncast,
};
/** State of parameter -warn-unsigned-downcast */
export const warnUnsignedDowncast: State.State<boolean> = warnUnsignedDowncast_internal;

/** Signal for state [`warnSignedDowncast`](#warnsigneddowncast)  */
export const signalWarnSignedDowncast: Server.Signal = {
  name: 'kernel.parameters.signalWarnSignedDowncast',
};

const getWarnSignedDowncast_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnSignedDowncast',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`warnSignedDowncast`](#warnsigneddowncast)  */
export const getWarnSignedDowncast: Server.GetRequest<null,boolean>= getWarnSignedDowncast_internal;

const setWarnSignedDowncast_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnSignedDowncast',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnSignedDowncast`](#warnsigneddowncast)  */
export const setWarnSignedDowncast: Server.SetRequest<boolean,null>= setWarnSignedDowncast_internal;

const warnSignedDowncast_internal: State.State<boolean> = {
  name: 'kernel.parameters.warnSignedDowncast',
  signal: signalWarnSignedDowncast,
  getter: getWarnSignedDowncast,
  setter: setWarnSignedDowncast,
};
/** State of parameter -warn-signed-downcast */
export const warnSignedDowncast: State.State<boolean> = warnSignedDowncast_internal;

/** Signal for state [`warnRightShiftNegative`](#warnrightshiftnegative)  */
export const signalWarnRightShiftNegative: Server.Signal = {
  name: 'kernel.parameters.signalWarnRightShiftNegative',
};

const getWarnRightShiftNegative_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnRightShiftNegative',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`warnRightShiftNegative`](#warnrightshiftnegative)  */
export const getWarnRightShiftNegative: Server.GetRequest<null,boolean>= getWarnRightShiftNegative_internal;

const setWarnRightShiftNegative_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnRightShiftNegative',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnRightShiftNegative`](#warnrightshiftnegative)  */
export const setWarnRightShiftNegative: Server.SetRequest<boolean,null>= setWarnRightShiftNegative_internal;

const warnRightShiftNegative_internal: State.State<boolean> = {
  name: 'kernel.parameters.warnRightShiftNegative',
  signal: signalWarnRightShiftNegative,
  getter: getWarnRightShiftNegative,
  setter: setWarnRightShiftNegative,
};
/** State of parameter -warn-right-shift-negative */
export const warnRightShiftNegative: State.State<boolean> = warnRightShiftNegative_internal;

/** Signal for state [`warnLeftShiftNegative`](#warnleftshiftnegative)  */
export const signalWarnLeftShiftNegative: Server.Signal = {
  name: 'kernel.parameters.signalWarnLeftShiftNegative',
};

const getWarnLeftShiftNegative_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnLeftShiftNegative',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`warnLeftShiftNegative`](#warnleftshiftnegative)  */
export const getWarnLeftShiftNegative: Server.GetRequest<null,boolean>= getWarnLeftShiftNegative_internal;

const setWarnLeftShiftNegative_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnLeftShiftNegative',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnLeftShiftNegative`](#warnleftshiftnegative)  */
export const setWarnLeftShiftNegative: Server.SetRequest<boolean,null>= setWarnLeftShiftNegative_internal;

const warnLeftShiftNegative_internal: State.State<boolean> = {
  name: 'kernel.parameters.warnLeftShiftNegative',
  signal: signalWarnLeftShiftNegative,
  getter: getWarnLeftShiftNegative,
  setter: setWarnLeftShiftNegative,
};
/** State of parameter -warn-left-shift-negative */
export const warnLeftShiftNegative: State.State<boolean> = warnLeftShiftNegative_internal;

/** Signal for state [`warnUnsignedOverflow`](#warnunsignedoverflow)  */
export const signalWarnUnsignedOverflow: Server.Signal = {
  name: 'kernel.parameters.signalWarnUnsignedOverflow',
};

const getWarnUnsignedOverflow_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnUnsignedOverflow',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`warnUnsignedOverflow`](#warnunsignedoverflow)  */
export const getWarnUnsignedOverflow: Server.GetRequest<null,boolean>= getWarnUnsignedOverflow_internal;

const setWarnUnsignedOverflow_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnUnsignedOverflow',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnUnsignedOverflow`](#warnunsignedoverflow)  */
export const setWarnUnsignedOverflow: Server.SetRequest<boolean,null>= setWarnUnsignedOverflow_internal;

const warnUnsignedOverflow_internal: State.State<boolean> = {
  name: 'kernel.parameters.warnUnsignedOverflow',
  signal: signalWarnUnsignedOverflow,
  getter: getWarnUnsignedOverflow,
  setter: setWarnUnsignedOverflow,
};
/** State of parameter -warn-unsigned-overflow */
export const warnUnsignedOverflow: State.State<boolean> = warnUnsignedOverflow_internal;

/** Signal for state [`warnSignedOverflow`](#warnsignedoverflow)  */
export const signalWarnSignedOverflow: Server.Signal = {
  name: 'kernel.parameters.signalWarnSignedOverflow',
};

const getWarnSignedOverflow_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWarnSignedOverflow',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`warnSignedOverflow`](#warnsignedoverflow)  */
export const getWarnSignedOverflow: Server.GetRequest<null,boolean>= getWarnSignedOverflow_internal;

const setWarnSignedOverflow_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWarnSignedOverflow',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`warnSignedOverflow`](#warnsignedoverflow)  */
export const setWarnSignedOverflow: Server.SetRequest<boolean,null>= setWarnSignedOverflow_internal;

const warnSignedOverflow_internal: State.State<boolean> = {
  name: 'kernel.parameters.warnSignedOverflow',
  signal: signalWarnSignedOverflow,
  getter: getWarnSignedOverflow,
  setter: setWarnSignedOverflow,
};
/** State of parameter -warn-signed-overflow */
export const warnSignedOverflow: State.State<boolean> = warnSignedOverflow_internal;

/** Signal for state [`absoluteValidRange`](#absolutevalidrange)  */
export const signalAbsoluteValidRange: Server.Signal = {
  name: 'kernel.parameters.signalAbsoluteValidRange',
};

const getAbsoluteValidRange_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAbsoluteValidRange',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`absoluteValidRange`](#absolutevalidrange)  */
export const getAbsoluteValidRange: Server.GetRequest<null,string>= getAbsoluteValidRange_internal;

const setAbsoluteValidRange_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAbsoluteValidRange',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`absoluteValidRange`](#absolutevalidrange)  */
export const setAbsoluteValidRange: Server.SetRequest<string,null>= setAbsoluteValidRange_internal;

const absoluteValidRange_internal: State.State<string> = {
  name: 'kernel.parameters.absoluteValidRange',
  signal: signalAbsoluteValidRange,
  getter: getAbsoluteValidRange,
  setter: setAbsoluteValidRange,
};
/** State of parameter -absolute-valid-range */
export const absoluteValidRange: State.State<string> = absoluteValidRange_internal;

/** Signal for state [`safeArrays`](#safearrays)  */
export const signalSafeArrays: Server.Signal = {
  name: 'kernel.parameters.signalSafeArrays',
};

const getSafeArrays_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getSafeArrays',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`safeArrays`](#safearrays)  */
export const getSafeArrays: Server.GetRequest<null,boolean>= getSafeArrays_internal;

const setSafeArrays_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setSafeArrays',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`safeArrays`](#safearrays)  */
export const setSafeArrays: Server.SetRequest<boolean,null>= setSafeArrays_internal;

const safeArrays_internal: State.State<boolean> = {
  name: 'kernel.parameters.safeArrays',
  signal: signalSafeArrays,
  getter: getSafeArrays,
  setter: setSafeArrays,
};
/** State of parameter -safe-arrays */
export const safeArrays: State.State<boolean> = safeArrays_internal;

/** Signal for state [`unspecifiedAccess`](#unspecifiedaccess)  */
export const signalUnspecifiedAccess: Server.Signal = {
  name: 'kernel.parameters.signalUnspecifiedAccess',
};

const getUnspecifiedAccess_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getUnspecifiedAccess',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`unspecifiedAccess`](#unspecifiedaccess)  */
export const getUnspecifiedAccess: Server.GetRequest<null,boolean>= getUnspecifiedAccess_internal;

const setUnspecifiedAccess_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setUnspecifiedAccess',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`unspecifiedAccess`](#unspecifiedaccess)  */
export const setUnspecifiedAccess: Server.SetRequest<boolean,null>= setUnspecifiedAccess_internal;

const unspecifiedAccess_internal: State.State<boolean> = {
  name: 'kernel.parameters.unspecifiedAccess',
  signal: signalUnspecifiedAccess,
  getter: getUnspecifiedAccess,
  setter: setUnspecifiedAccess,
};
/** State of parameter -unspecified-access */
export const unspecifiedAccess: State.State<boolean> = unspecifiedAccess_internal;

/** Signal for state [`libEntry`](#libentry)  */
export const signalLibEntry: Server.Signal = {
  name: 'kernel.parameters.signalLibEntry',
};

const getLibEntry_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getLibEntry',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`libEntry`](#libentry)  */
export const getLibEntry: Server.GetRequest<null,boolean>= getLibEntry_internal;

const setLibEntry_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setLibEntry',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`libEntry`](#libentry)  */
export const setLibEntry: Server.SetRequest<boolean,null>= setLibEntry_internal;

const libEntry_internal: State.State<boolean> = {
  name: 'kernel.parameters.libEntry',
  signal: signalLibEntry,
  getter: getLibEntry,
  setter: setLibEntry,
};
/** State of parameter -lib-entry */
export const libEntry: State.State<boolean> = libEntry_internal;

/** Signal for state [`main`](#main)  */
export const signalMain: Server.Signal = {
  name: 'kernel.parameters.signalMain',
};

const getMain_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getMain',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`main`](#main)  */
export const getMain: Server.GetRequest<null,string>= getMain_internal;

const setMain_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setMain',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`main`](#main)  */
export const setMain: Server.SetRequest<string,null>= setMain_internal;

const main_internal: State.State<string> = {
  name: 'kernel.parameters.main',
  signal: signalMain,
  getter: getMain,
  setter: setMain,
};
/** State of parameter -main */
export const main: State.State<string> = main_internal;

/** Signal for state [`removeInlined`](#removeinlined)  */
export const signalRemoveInlined: Server.Signal = {
  name: 'kernel.parameters.signalRemoveInlined',
};

const getRemoveInlined_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRemoveInlined',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`removeInlined`](#removeinlined)  */
export const getRemoveInlined: Server.GetRequest<null,string>= getRemoveInlined_internal;

const setRemoveInlined_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRemoveInlined',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`removeInlined`](#removeinlined)  */
export const setRemoveInlined: Server.SetRequest<string,null>= setRemoveInlined_internal;

const removeInlined_internal: State.State<string> = {
  name: 'kernel.parameters.removeInlined',
  signal: signalRemoveInlined,
  getter: getRemoveInlined,
  setter: setRemoveInlined,
};
/** State of parameter -remove-inlined */
export const removeInlined: State.State<string> = removeInlined_internal;

/** Signal for state [`inlineCalls`](#inlinecalls)  */
export const signalInlineCalls: Server.Signal = {
  name: 'kernel.parameters.signalInlineCalls',
};

const getInlineCalls_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getInlineCalls',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`inlineCalls`](#inlinecalls)  */
export const getInlineCalls: Server.GetRequest<null,string>= getInlineCalls_internal;

const setInlineCalls_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setInlineCalls',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`inlineCalls`](#inlinecalls)  */
export const setInlineCalls: Server.SetRequest<string,null>= setInlineCalls_internal;

const inlineCalls_internal: State.State<string> = {
  name: 'kernel.parameters.inlineCalls',
  signal: signalInlineCalls,
  getter: getInlineCalls,
  setter: setInlineCalls,
};
/** State of parameter -inline-calls */
export const inlineCalls: State.State<string> = inlineCalls_internal;

/** Signal for state [`generatedSpecCustom`](#generatedspeccustom)  */
export const signalGeneratedSpecCustom: Server.Signal = {
  name: 'kernel.parameters.signalGeneratedSpecCustom',
};

const getGeneratedSpecCustom_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getGeneratedSpecCustom',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`generatedSpecCustom`](#generatedspeccustom)  */
export const getGeneratedSpecCustom: Server.GetRequest<null,string>= getGeneratedSpecCustom_internal;

const setGeneratedSpecCustom_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setGeneratedSpecCustom',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`generatedSpecCustom`](#generatedspeccustom)  */
export const setGeneratedSpecCustom: Server.SetRequest<string,null>= setGeneratedSpecCustom_internal;

const generatedSpecCustom_internal: State.State<string> = {
  name: 'kernel.parameters.generatedSpecCustom',
  signal: signalGeneratedSpecCustom,
  getter: getGeneratedSpecCustom,
  setter: setGeneratedSpecCustom,
};
/** State of parameter -generated-spec-custom */
export const generatedSpecCustom: State.State<string> = generatedSpecCustom_internal;

/** Signal for state [`generatedSpecMode`](#generatedspecmode)  */
export const signalGeneratedSpecMode: Server.Signal = {
  name: 'kernel.parameters.signalGeneratedSpecMode',
};

const getGeneratedSpecMode_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getGeneratedSpecMode',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`generatedSpecMode`](#generatedspecmode)  */
export const getGeneratedSpecMode: Server.GetRequest<null,string>= getGeneratedSpecMode_internal;

const setGeneratedSpecMode_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setGeneratedSpecMode',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`generatedSpecMode`](#generatedspecmode)  */
export const setGeneratedSpecMode: Server.SetRequest<string,null>= setGeneratedSpecMode_internal;

const generatedSpecMode_internal: State.State<string> = {
  name: 'kernel.parameters.generatedSpecMode',
  signal: signalGeneratedSpecMode,
  getter: getGeneratedSpecMode,
  setter: setGeneratedSpecMode,
};
/** State of parameter -generated-spec-mode */
export const generatedSpecMode: State.State<string> = generatedSpecMode_internal;

/** Signal for state [`collapseCallCast`](#collapsecallcast)  */
export const signalCollapseCallCast: Server.Signal = {
  name: 'kernel.parameters.signalCollapseCallCast',
};

const getCollapseCallCast_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getCollapseCallCast',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`collapseCallCast`](#collapsecallcast)  */
export const getCollapseCallCast: Server.GetRequest<null,boolean>= getCollapseCallCast_internal;

const setCollapseCallCast_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setCollapseCallCast',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`collapseCallCast`](#collapsecallcast)  */
export const setCollapseCallCast: Server.SetRequest<boolean,null>= setCollapseCallCast_internal;

const collapseCallCast_internal: State.State<boolean> = {
  name: 'kernel.parameters.collapseCallCast',
  signal: signalCollapseCallCast,
  getter: getCollapseCallCast,
  setter: setCollapseCallCast,
};
/** State of parameter -collapse-call-cast */
export const collapseCallCast: State.State<boolean> = collapseCallCast_internal;

/** Signal for state [`allowDuplication`](#allowduplication)  */
export const signalAllowDuplication: Server.Signal = {
  name: 'kernel.parameters.signalAllowDuplication',
};

const getAllowDuplication_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAllowDuplication',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`allowDuplication`](#allowduplication)  */
export const getAllowDuplication: Server.GetRequest<null,boolean>= getAllowDuplication_internal;

const setAllowDuplication_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAllowDuplication',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`allowDuplication`](#allowduplication)  */
export const setAllowDuplication: Server.SetRequest<boolean,null>= setAllowDuplication_internal;

const allowDuplication_internal: State.State<boolean> = {
  name: 'kernel.parameters.allowDuplication',
  signal: signalAllowDuplication,
  getter: getAllowDuplication,
  setter: setAllowDuplication,
};
/** State of parameter -allow-duplication */
export const allowDuplication: State.State<boolean> = allowDuplication_internal;

/** Signal for state [`removeExn`](#removeexn)  */
export const signalRemoveExn: Server.Signal = {
  name: 'kernel.parameters.signalRemoveExn',
};

const getRemoveExn_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRemoveExn',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`removeExn`](#removeexn)  */
export const getRemoveExn: Server.GetRequest<null,boolean>= getRemoveExn_internal;

const setRemoveExn_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRemoveExn',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`removeExn`](#removeexn)  */
export const setRemoveExn: Server.SetRequest<boolean,null>= setRemoveExn_internal;

const removeExn_internal: State.State<boolean> = {
  name: 'kernel.parameters.removeExn',
  signal: signalRemoveExn,
  getter: getRemoveExn,
  setter: setRemoveExn,
};
/** State of parameter -remove-exn */
export const removeExn: State.State<boolean> = removeExn_internal;

/** Signal for state [`asmContractsAutoValidate`](#asmcontractsautovalidate)  */
export const signalAsmContractsAutoValidate: Server.Signal = {
  name: 'kernel.parameters.signalAsmContractsAutoValidate',
};

const getAsmContractsAutoValidate_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAsmContractsAutoValidate',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`asmContractsAutoValidate`](#asmcontractsautovalidate)  */
export const getAsmContractsAutoValidate: Server.GetRequest<null,boolean>= getAsmContractsAutoValidate_internal;

const setAsmContractsAutoValidate_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAsmContractsAutoValidate',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`asmContractsAutoValidate`](#asmcontractsautovalidate)  */
export const setAsmContractsAutoValidate: Server.SetRequest<boolean,null>= setAsmContractsAutoValidate_internal;

const asmContractsAutoValidate_internal: State.State<boolean> = {
  name: 'kernel.parameters.asmContractsAutoValidate',
  signal: signalAsmContractsAutoValidate,
  getter: getAsmContractsAutoValidate,
  setter: setAsmContractsAutoValidate,
};
/** State of parameter -asm-contracts-auto-validate */
export const asmContractsAutoValidate: State.State<boolean> = asmContractsAutoValidate_internal;

/** Signal for state [`asmContracts`](#asmcontracts)  */
export const signalAsmContracts: Server.Signal = {
  name: 'kernel.parameters.signalAsmContracts',
};

const getAsmContracts_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAsmContracts',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`asmContracts`](#asmcontracts)  */
export const getAsmContracts: Server.GetRequest<null,boolean>= getAsmContracts_internal;

const setAsmContracts_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAsmContracts',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`asmContracts`](#asmcontracts)  */
export const setAsmContracts: Server.SetRequest<boolean,null>= setAsmContracts_internal;

const asmContracts_internal: State.State<boolean> = {
  name: 'kernel.parameters.asmContracts',
  signal: signalAsmContracts,
  getter: getAsmContracts,
  setter: setAsmContracts,
};
/** State of parameter -asm-contracts */
export const asmContracts: State.State<boolean> = asmContracts_internal;

/** Signal for state [`aggressiveMerging`](#aggressivemerging)  */
export const signalAggressiveMerging: Server.Signal = {
  name: 'kernel.parameters.signalAggressiveMerging',
};

const getAggressiveMerging_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getAggressiveMerging',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`aggressiveMerging`](#aggressivemerging)  */
export const getAggressiveMerging: Server.GetRequest<null,boolean>= getAggressiveMerging_internal;

const setAggressiveMerging_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setAggressiveMerging',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`aggressiveMerging`](#aggressivemerging)  */
export const setAggressiveMerging: Server.SetRequest<boolean,null>= setAggressiveMerging_internal;

const aggressiveMerging_internal: State.State<boolean> = {
  name: 'kernel.parameters.aggressiveMerging',
  signal: signalAggressiveMerging,
  getter: getAggressiveMerging,
  setter: setAggressiveMerging,
};
/** State of parameter -aggressive-merging */
export const aggressiveMerging: State.State<boolean> = aggressiveMerging_internal;

/** Signal for state [`initializedPaddingLocals`](#initializedpaddinglocals)  */
export const signalInitializedPaddingLocals: Server.Signal = {
  name: 'kernel.parameters.signalInitializedPaddingLocals',
};

const getInitializedPaddingLocals_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getInitializedPaddingLocals',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`initializedPaddingLocals`](#initializedpaddinglocals)  */
export const getInitializedPaddingLocals: Server.GetRequest<null,boolean>= getInitializedPaddingLocals_internal;

const setInitializedPaddingLocals_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setInitializedPaddingLocals',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`initializedPaddingLocals`](#initializedpaddinglocals)  */
export const setInitializedPaddingLocals: Server.SetRequest<boolean,null>= setInitializedPaddingLocals_internal;

const initializedPaddingLocals_internal: State.State<boolean> = {
  name: 'kernel.parameters.initializedPaddingLocals',
  signal: signalInitializedPaddingLocals,
  getter: getInitializedPaddingLocals,
  setter: setInitializedPaddingLocals,
};
/** State of parameter -initialized-padding-locals */
export const initializedPaddingLocals: State.State<boolean> = initializedPaddingLocals_internal;

/** Signal for state [`constfold`](#constfold)  */
export const signalConstfold: Server.Signal = {
  name: 'kernel.parameters.signalConstfold',
};

const getConstfold_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getConstfold',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`constfold`](#constfold)  */
export const getConstfold: Server.GetRequest<null,boolean>= getConstfold_internal;

const setConstfold_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setConstfold',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`constfold`](#constfold)  */
export const setConstfold: Server.SetRequest<boolean,null>= setConstfold_internal;

const constfold_internal: State.State<boolean> = {
  name: 'kernel.parameters.constfold',
  signal: signalConstfold,
  getter: getConstfold,
  setter: setConstfold,
};
/** State of parameter -constfold */
export const constfold: State.State<boolean> = constfold_internal;

/** Signal for state [`simplifyTrivialLoops`](#simplifytrivialloops)  */
export const signalSimplifyTrivialLoops: Server.Signal = {
  name: 'kernel.parameters.signalSimplifyTrivialLoops',
};

const getSimplifyTrivialLoops_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getSimplifyTrivialLoops',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`simplifyTrivialLoops`](#simplifytrivialloops)  */
export const getSimplifyTrivialLoops: Server.GetRequest<null,boolean>= getSimplifyTrivialLoops_internal;

const setSimplifyTrivialLoops_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setSimplifyTrivialLoops',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`simplifyTrivialLoops`](#simplifytrivialloops)  */
export const setSimplifyTrivialLoops: Server.SetRequest<boolean,null>= setSimplifyTrivialLoops_internal;

const simplifyTrivialLoops_internal: State.State<boolean> = {
  name: 'kernel.parameters.simplifyTrivialLoops',
  signal: signalSimplifyTrivialLoops,
  getter: getSimplifyTrivialLoops,
  setter: setSimplifyTrivialLoops,
};
/** State of parameter -simplify-trivial-loops */
export const simplifyTrivialLoops: State.State<boolean> = simplifyTrivialLoops_internal;

/** Signal for state [`keepUnusedTypes`](#keepunusedtypes)  */
export const signalKeepUnusedTypes: Server.Signal = {
  name: 'kernel.parameters.signalKeepUnusedTypes',
};

const getKeepUnusedTypes_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getKeepUnusedTypes',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`keepUnusedTypes`](#keepunusedtypes)  */
export const getKeepUnusedTypes: Server.GetRequest<null,boolean>= getKeepUnusedTypes_internal;

const setKeepUnusedTypes_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setKeepUnusedTypes',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`keepUnusedTypes`](#keepunusedtypes)  */
export const setKeepUnusedTypes: Server.SetRequest<boolean,null>= setKeepUnusedTypes_internal;

const keepUnusedTypes_internal: State.State<boolean> = {
  name: 'kernel.parameters.keepUnusedTypes',
  signal: signalKeepUnusedTypes,
  getter: getKeepUnusedTypes,
  setter: setKeepUnusedTypes,
};
/** State of parameter -keep-unused-types */
export const keepUnusedTypes: State.State<boolean> = keepUnusedTypes_internal;

/** Signal for state [`keepUnusedFunctions`](#keepunusedfunctions)  */
export const signalKeepUnusedFunctions: Server.Signal = {
  name: 'kernel.parameters.signalKeepUnusedFunctions',
};

const getKeepUnusedFunctions_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getKeepUnusedFunctions',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`keepUnusedFunctions`](#keepunusedfunctions)  */
export const getKeepUnusedFunctions: Server.GetRequest<null,string>= getKeepUnusedFunctions_internal;

const setKeepUnusedFunctions_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setKeepUnusedFunctions',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`keepUnusedFunctions`](#keepunusedfunctions)  */
export const setKeepUnusedFunctions: Server.SetRequest<string,null>= setKeepUnusedFunctions_internal;

const keepUnusedFunctions_internal: State.State<string> = {
  name: 'kernel.parameters.keepUnusedFunctions',
  signal: signalKeepUnusedFunctions,
  getter: getKeepUnusedFunctions,
  setter: setKeepUnusedFunctions,
};
/** State of parameter -keep-unused-functions */
export const keepUnusedFunctions: State.State<string> = keepUnusedFunctions_internal;

/** Signal for state [`keepSwitch`](#keepswitch)  */
export const signalKeepSwitch: Server.Signal = {
  name: 'kernel.parameters.signalKeepSwitch',
};

const getKeepSwitch_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getKeepSwitch',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`keepSwitch`](#keepswitch)  */
export const getKeepSwitch: Server.GetRequest<null,boolean>= getKeepSwitch_internal;

const setKeepSwitch_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setKeepSwitch',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`keepSwitch`](#keepswitch)  */
export const setKeepSwitch: Server.SetRequest<boolean,null>= setKeepSwitch_internal;

const keepSwitch_internal: State.State<boolean> = {
  name: 'kernel.parameters.keepSwitch',
  signal: signalKeepSwitch,
  getter: getKeepSwitch,
  setter: setKeepSwitch,
};
/** State of parameter -keep-switch */
export const keepSwitch: State.State<boolean> = keepSwitch_internal;

/** Signal for state [`simplifyCfg`](#simplifycfg)  */
export const signalSimplifyCfg: Server.Signal = {
  name: 'kernel.parameters.signalSimplifyCfg',
};

const getSimplifyCfg_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getSimplifyCfg',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`simplifyCfg`](#simplifycfg)  */
export const getSimplifyCfg: Server.GetRequest<null,boolean>= getSimplifyCfg_internal;

const setSimplifyCfg_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setSimplifyCfg',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`simplifyCfg`](#simplifycfg)  */
export const setSimplifyCfg: Server.SetRequest<boolean,null>= setSimplifyCfg_internal;

const simplifyCfg_internal: State.State<boolean> = {
  name: 'kernel.parameters.simplifyCfg',
  signal: signalSimplifyCfg,
  getter: getSimplifyCfg,
  setter: setSimplifyCfg,
};
/** State of parameter -simplify-cfg */
export const simplifyCfg: State.State<boolean> = simplifyCfg_internal;

/** Signal for state [`enums`](#enums)  */
export const signalEnums: Server.Signal = {
  name: 'kernel.parameters.signalEnums',
};

const getEnums_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEnums',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`enums`](#enums)  */
export const getEnums: Server.GetRequest<null,string>= getEnums_internal;

const setEnums_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEnums',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`enums`](#enums)  */
export const setEnums: Server.SetRequest<string,null>= setEnums_internal;

const enums_internal: State.State<string> = {
  name: 'kernel.parameters.enums',
  signal: signalEnums,
  getter: getEnums,
  setter: setEnums,
};
/** State of parameter -enums */
export const enums: State.State<string> = enums_internal;

/** Signal for state [`ulevelForce`](#ulevelforce)  */
export const signalUlevelForce: Server.Signal = {
  name: 'kernel.parameters.signalUlevelForce',
};

const getUlevelForce_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getUlevelForce',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`ulevelForce`](#ulevelforce)  */
export const getUlevelForce: Server.GetRequest<null,boolean>= getUlevelForce_internal;

const setUlevelForce_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setUlevelForce',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`ulevelForce`](#ulevelforce)  */
export const setUlevelForce: Server.SetRequest<boolean,null>= setUlevelForce_internal;

const ulevelForce_internal: State.State<boolean> = {
  name: 'kernel.parameters.ulevelForce',
  signal: signalUlevelForce,
  getter: getUlevelForce,
  setter: setUlevelForce,
};
/** State of parameter -ulevel-force */
export const ulevelForce: State.State<boolean> = ulevelForce_internal;

/** Signal for state [`ulevel`](#ulevel)  */
export const signalUlevel: Server.Signal = {
  name: 'kernel.parameters.signalUlevel',
};

const getUlevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getUlevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`ulevel`](#ulevel)  */
export const getUlevel: Server.GetRequest<null,number>= getUlevel_internal;

const setUlevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setUlevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`ulevel`](#ulevel)  */
export const setUlevel: Server.SetRequest<number,null>= setUlevel_internal;

const ulevel_internal: State.State<number> = {
  name: 'kernel.parameters.ulevel',
  signal: signalUlevel,
  getter: getUlevel,
  setter: setUlevel,
};
/** State of parameter -ulevel */
export const ulevel: State.State<number> = ulevel_internal;

/** Signal for state [`evaPrecision`](#evaprecision)  */
export const signalEvaPrecision: Server.Signal = {
  name: 'kernel.parameters.signalEvaPrecision',
};

const getEvaPrecision_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaPrecision',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaPrecision`](#evaprecision)  */
export const getEvaPrecision: Server.GetRequest<null,number>= getEvaPrecision_internal;

const setEvaPrecision_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaPrecision',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaPrecision`](#evaprecision)  */
export const setEvaPrecision: Server.SetRequest<number,null>= setEvaPrecision_internal;

const evaPrecision_internal: State.State<number> = {
  name: 'kernel.parameters.evaPrecision',
  signal: signalEvaPrecision,
  getter: getEvaPrecision,
  setter: setEvaPrecision,
};
/** State of parameter -eva-precision */
export const evaPrecision: State.State<number> = evaPrecision_internal;

/** Signal for state [`eva`](#eva)  */
export const signalEva: Server.Signal = {
  name: 'kernel.parameters.signalEva',
};

const getEva_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEva',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`eva`](#eva)  */
export const getEva: Server.GetRequest<null,boolean>= getEva_internal;

const setEva_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEva',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`eva`](#eva)  */
export const setEva: Server.SetRequest<boolean,null>= setEva_internal;

const eva_internal: State.State<boolean> = {
  name: 'kernel.parameters.eva',
  signal: signalEva,
  getter: getEva,
  setter: setEva,
};
/** State of parameter -eva */
export const eva: State.State<boolean> = eva_internal;

/** Signal for state [`evaJoinResults`](#evajoinresults)  */
export const signalEvaJoinResults: Server.Signal = {
  name: 'kernel.parameters.signalEvaJoinResults',
};

const getEvaJoinResults_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaJoinResults',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaJoinResults`](#evajoinresults)  */
export const getEvaJoinResults: Server.GetRequest<null,boolean>= getEvaJoinResults_internal;

const setEvaJoinResults_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaJoinResults',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaJoinResults`](#evajoinresults)  */
export const setEvaJoinResults: Server.SetRequest<boolean,null>= setEvaJoinResults_internal;

const evaJoinResults_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaJoinResults',
  signal: signalEvaJoinResults,
  getter: getEvaJoinResults,
  setter: setEvaJoinResults,
};
/** State of parameter -eva-join-results */
export const evaJoinResults: State.State<boolean> = evaJoinResults_internal;

/** Signal for state [`evaResults`](#evaresults)  */
export const signalEvaResults: Server.Signal = {
  name: 'kernel.parameters.signalEvaResults',
};

const getEvaResults_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaResults',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaResults`](#evaresults)  */
export const getEvaResults: Server.GetRequest<null,boolean>= getEvaResults_internal;

const setEvaResults_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaResults',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaResults`](#evaresults)  */
export const setEvaResults: Server.SetRequest<boolean,null>= setEvaResults_internal;

const evaResults_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaResults',
  signal: signalEvaResults,
  getter: getEvaResults,
  setter: setEvaResults,
};
/** State of parameter -eva-results */
export const evaResults: State.State<boolean> = evaResults_internal;

/** Signal for state [`evaNoResultsFunction`](#evanoresultsfunction)  */
export const signalEvaNoResultsFunction: Server.Signal = {
  name: 'kernel.parameters.signalEvaNoResultsFunction',
};

const getEvaNoResultsFunction_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaNoResultsFunction',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaNoResultsFunction`](#evanoresultsfunction)  */
export const getEvaNoResultsFunction: Server.GetRequest<null,string>= getEvaNoResultsFunction_internal;

const setEvaNoResultsFunction_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaNoResultsFunction',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaNoResultsFunction`](#evanoresultsfunction)  */
export const setEvaNoResultsFunction: Server.SetRequest<string,null>= setEvaNoResultsFunction_internal;

const evaNoResultsFunction_internal: State.State<string> = {
  name: 'kernel.parameters.evaNoResultsFunction',
  signal: signalEvaNoResultsFunction,
  getter: getEvaNoResultsFunction,
  setter: setEvaNoResultsFunction,
};
/** State of parameter -eva-no-results-function */
export const evaNoResultsFunction: State.State<string> = evaNoResultsFunction_internal;

/** Signal for state [`evaNoResultsDomain`](#evanoresultsdomain)  */
export const signalEvaNoResultsDomain: Server.Signal = {
  name: 'kernel.parameters.signalEvaNoResultsDomain',
};

const getEvaNoResultsDomain_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaNoResultsDomain',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaNoResultsDomain`](#evanoresultsdomain)  */
export const getEvaNoResultsDomain: Server.GetRequest<null,string>= getEvaNoResultsDomain_internal;

const setEvaNoResultsDomain_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaNoResultsDomain',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaNoResultsDomain`](#evanoresultsdomain)  */
export const setEvaNoResultsDomain: Server.SetRequest<string,null>= setEvaNoResultsDomain_internal;

const evaNoResultsDomain_internal: State.State<string> = {
  name: 'kernel.parameters.evaNoResultsDomain',
  signal: signalEvaNoResultsDomain,
  getter: getEvaNoResultsDomain,
  setter: setEvaNoResultsDomain,
};
/** State of parameter -eva-no-results-domain */
export const evaNoResultsDomain: State.State<string> = evaNoResultsDomain_internal;

/** Signal for state [`evaReductionDepth`](#evareductiondepth)  */
export const signalEvaReductionDepth: Server.Signal = {
  name: 'kernel.parameters.signalEvaReductionDepth',
};

const getEvaReductionDepth_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaReductionDepth',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaReductionDepth`](#evareductiondepth)  */
export const getEvaReductionDepth: Server.GetRequest<null,number>= getEvaReductionDepth_internal;

const setEvaReductionDepth_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaReductionDepth',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaReductionDepth`](#evareductiondepth)  */
export const setEvaReductionDepth: Server.SetRequest<number,null>= setEvaReductionDepth_internal;

const evaReductionDepth_internal: State.State<number> = {
  name: 'kernel.parameters.evaReductionDepth',
  signal: signalEvaReductionDepth,
  getter: getEvaReductionDepth,
  setter: setEvaReductionDepth,
};
/** State of parameter -eva-reduction-depth */
export const evaReductionDepth: State.State<number> = evaReductionDepth_internal;

/** Signal for state [`evaOracleDepth`](#evaoracledepth)  */
export const signalEvaOracleDepth: Server.Signal = {
  name: 'kernel.parameters.signalEvaOracleDepth',
};

const getEvaOracleDepth_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaOracleDepth',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaOracleDepth`](#evaoracledepth)  */
export const getEvaOracleDepth: Server.GetRequest<null,number>= getEvaOracleDepth_internal;

const setEvaOracleDepth_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaOracleDepth',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaOracleDepth`](#evaoracledepth)  */
export const setEvaOracleDepth: Server.SetRequest<number,null>= setEvaOracleDepth_internal;

const evaOracleDepth_internal: State.State<number> = {
  name: 'kernel.parameters.evaOracleDepth',
  signal: signalEvaOracleDepth,
  getter: getEvaOracleDepth,
  setter: setEvaOracleDepth,
};
/** State of parameter -eva-oracle-depth */
export const evaOracleDepth: State.State<number> = evaOracleDepth_internal;

/** Signal for state [`evaEnumerateCond`](#evaenumeratecond)  */
export const signalEvaEnumerateCond: Server.Signal = {
  name: 'kernel.parameters.signalEvaEnumerateCond',
};

const getEvaEnumerateCond_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaEnumerateCond',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaEnumerateCond`](#evaenumeratecond)  */
export const getEvaEnumerateCond: Server.GetRequest<null,boolean>= getEvaEnumerateCond_internal;

const setEvaEnumerateCond_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaEnumerateCond',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaEnumerateCond`](#evaenumeratecond)  */
export const setEvaEnumerateCond: Server.SetRequest<boolean,null>= setEvaEnumerateCond_internal;

const evaEnumerateCond_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaEnumerateCond',
  signal: signalEvaEnumerateCond,
  getter: getEvaEnumerateCond,
  setter: setEvaEnumerateCond,
};
/** State of parameter -eva-enumerate-cond */
export const evaEnumerateCond: State.State<boolean> = evaEnumerateCond_internal;

/** Signal for state [`evaPlevel`](#evaplevel)  */
export const signalEvaPlevel: Server.Signal = {
  name: 'kernel.parameters.signalEvaPlevel',
};

const getEvaPlevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaPlevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaPlevel`](#evaplevel)  */
export const getEvaPlevel: Server.GetRequest<null,number>= getEvaPlevel_internal;

const setEvaPlevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaPlevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaPlevel`](#evaplevel)  */
export const setEvaPlevel: Server.SetRequest<number,null>= setEvaPlevel_internal;

const evaPlevel_internal: State.State<number> = {
  name: 'kernel.parameters.evaPlevel',
  signal: signalEvaPlevel,
  getter: getEvaPlevel,
  setter: setEvaPlevel,
};
/** State of parameter -eva-plevel */
export const evaPlevel: State.State<number> = evaPlevel_internal;

/** Signal for state [`evaMemexec`](#evamemexec)  */
export const signalEvaMemexec: Server.Signal = {
  name: 'kernel.parameters.signalEvaMemexec',
};

const getEvaMemexec_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaMemexec',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaMemexec`](#evamemexec)  */
export const getEvaMemexec: Server.GetRequest<null,boolean>= getEvaMemexec_internal;

const setEvaMemexec_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaMemexec',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaMemexec`](#evamemexec)  */
export const setEvaMemexec: Server.SetRequest<boolean,null>= setEvaMemexec_internal;

const evaMemexec_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaMemexec',
  signal: signalEvaMemexec,
  getter: getEvaMemexec,
  setter: setEvaMemexec,
};
/** State of parameter -eva-memexec */
export const evaMemexec: State.State<boolean> = evaMemexec_internal;

/** Signal for state [`evaRemoveRedundantAlarms`](#evaremoveredundantalarms)  */
export const signalEvaRemoveRedundantAlarms: Server.Signal = {
  name: 'kernel.parameters.signalEvaRemoveRedundantAlarms',
};

const getEvaRemoveRedundantAlarms_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaRemoveRedundantAlarms',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaRemoveRedundantAlarms`](#evaremoveredundantalarms)  */
export const getEvaRemoveRedundantAlarms: Server.GetRequest<null,boolean>= getEvaRemoveRedundantAlarms_internal;

const setEvaRemoveRedundantAlarms_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaRemoveRedundantAlarms',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaRemoveRedundantAlarms`](#evaremoveredundantalarms)  */
export const setEvaRemoveRedundantAlarms: Server.SetRequest<boolean,null>= setEvaRemoveRedundantAlarms_internal;

const evaRemoveRedundantAlarms_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaRemoveRedundantAlarms',
  signal: signalEvaRemoveRedundantAlarms,
  getter: getEvaRemoveRedundantAlarms,
  setter: setEvaRemoveRedundantAlarms,
};
/** State of parameter -eva-remove-redundant-alarms */
export const evaRemoveRedundantAlarms: State.State<boolean> = evaRemoveRedundantAlarms_internal;

/** Signal for state [`evaSkipStdlibSpecs`](#evaskipstdlibspecs)  */
export const signalEvaSkipStdlibSpecs: Server.Signal = {
  name: 'kernel.parameters.signalEvaSkipStdlibSpecs',
};

const getEvaSkipStdlibSpecs_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaSkipStdlibSpecs',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaSkipStdlibSpecs`](#evaskipstdlibspecs)  */
export const getEvaSkipStdlibSpecs: Server.GetRequest<null,boolean>= getEvaSkipStdlibSpecs_internal;

const setEvaSkipStdlibSpecs_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaSkipStdlibSpecs',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaSkipStdlibSpecs`](#evaskipstdlibspecs)  */
export const setEvaSkipStdlibSpecs: Server.SetRequest<boolean,null>= setEvaSkipStdlibSpecs_internal;

const evaSkipStdlibSpecs_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaSkipStdlibSpecs',
  signal: signalEvaSkipStdlibSpecs,
  getter: getEvaSkipStdlibSpecs,
  setter: setEvaSkipStdlibSpecs,
};
/** State of parameter -eva-skip-stdlib-specs */
export const evaSkipStdlibSpecs: State.State<boolean> = evaSkipStdlibSpecs_internal;

/** Signal for state [`evaUseSpec`](#evausespec)  */
export const signalEvaUseSpec: Server.Signal = {
  name: 'kernel.parameters.signalEvaUseSpec',
};

const getEvaUseSpec_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaUseSpec',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaUseSpec`](#evausespec)  */
export const getEvaUseSpec: Server.GetRequest<null,string>= getEvaUseSpec_internal;

const setEvaUseSpec_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaUseSpec',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaUseSpec`](#evausespec)  */
export const setEvaUseSpec: Server.SetRequest<string,null>= setEvaUseSpec_internal;

const evaUseSpec_internal: State.State<string> = {
  name: 'kernel.parameters.evaUseSpec',
  signal: signalEvaUseSpec,
  getter: getEvaUseSpec,
  setter: setEvaUseSpec,
};
/** State of parameter -eva-use-spec */
export const evaUseSpec: State.State<string> = evaUseSpec_internal;

/** Signal for state
    [`evaSubdivideNonLinearFunction`](#evasubdividenonlinearfunction)  */
export const signalEvaSubdivideNonLinearFunction: Server.Signal = {
  name: 'kernel.parameters.signalEvaSubdivideNonLinearFunction',
};

const getEvaSubdivideNonLinearFunction_internal: Server.GetRequest<
  null,
  string
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaSubdivideNonLinearFunction',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state
    [`evaSubdivideNonLinearFunction`](#evasubdividenonlinearfunction)  */
export const getEvaSubdivideNonLinearFunction: Server.GetRequest<null,string>= getEvaSubdivideNonLinearFunction_internal;

const setEvaSubdivideNonLinearFunction_internal: Server.SetRequest<
  string,
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaSubdivideNonLinearFunction',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state
    [`evaSubdivideNonLinearFunction`](#evasubdividenonlinearfunction)  */
export const setEvaSubdivideNonLinearFunction: Server.SetRequest<string,null>= setEvaSubdivideNonLinearFunction_internal;

const evaSubdivideNonLinearFunction_internal: State.State<string> = {
  name: 'kernel.parameters.evaSubdivideNonLinearFunction',
  signal: signalEvaSubdivideNonLinearFunction,
  getter: getEvaSubdivideNonLinearFunction,
  setter: setEvaSubdivideNonLinearFunction,
};
/** State of parameter -eva-subdivide-non-linear-function */
export const evaSubdivideNonLinearFunction: State.State<string> = evaSubdivideNonLinearFunction_internal;

/** Signal for state [`evaSubdivideNonLinear`](#evasubdividenonlinear)  */
export const signalEvaSubdivideNonLinear: Server.Signal = {
  name: 'kernel.parameters.signalEvaSubdivideNonLinear',
};

const getEvaSubdivideNonLinear_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaSubdivideNonLinear',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaSubdivideNonLinear`](#evasubdividenonlinear)  */
export const getEvaSubdivideNonLinear: Server.GetRequest<null,number>= getEvaSubdivideNonLinear_internal;

const setEvaSubdivideNonLinear_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaSubdivideNonLinear',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaSubdivideNonLinear`](#evasubdividenonlinear)  */
export const setEvaSubdivideNonLinear: Server.SetRequest<number,null>= setEvaSubdivideNonLinear_internal;

const evaSubdivideNonLinear_internal: State.State<number> = {
  name: 'kernel.parameters.evaSubdivideNonLinear',
  signal: signalEvaSubdivideNonLinear,
  getter: getEvaSubdivideNonLinear,
  setter: setEvaSubdivideNonLinear,
};
/** State of parameter -eva-subdivide-non-linear */
export const evaSubdivideNonLinear: State.State<number> = evaSubdivideNonLinear_internal;

/** Signal for state [`evaBuiltinsList`](#evabuiltinslist)  */
export const signalEvaBuiltinsList: Server.Signal = {
  name: 'kernel.parameters.signalEvaBuiltinsList',
};

const getEvaBuiltinsList_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaBuiltinsList',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaBuiltinsList`](#evabuiltinslist)  */
export const getEvaBuiltinsList: Server.GetRequest<null,boolean>= getEvaBuiltinsList_internal;

const setEvaBuiltinsList_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaBuiltinsList',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaBuiltinsList`](#evabuiltinslist)  */
export const setEvaBuiltinsList: Server.SetRequest<boolean,null>= setEvaBuiltinsList_internal;

const evaBuiltinsList_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaBuiltinsList',
  signal: signalEvaBuiltinsList,
  getter: getEvaBuiltinsList,
  setter: setEvaBuiltinsList,
};
/** State of parameter -eva-builtins-list */
export const evaBuiltinsList: State.State<boolean> = evaBuiltinsList_internal;

/** Signal for state [`evaBuiltinsAuto`](#evabuiltinsauto)  */
export const signalEvaBuiltinsAuto: Server.Signal = {
  name: 'kernel.parameters.signalEvaBuiltinsAuto',
};

const getEvaBuiltinsAuto_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaBuiltinsAuto',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaBuiltinsAuto`](#evabuiltinsauto)  */
export const getEvaBuiltinsAuto: Server.GetRequest<null,boolean>= getEvaBuiltinsAuto_internal;

const setEvaBuiltinsAuto_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaBuiltinsAuto',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaBuiltinsAuto`](#evabuiltinsauto)  */
export const setEvaBuiltinsAuto: Server.SetRequest<boolean,null>= setEvaBuiltinsAuto_internal;

const evaBuiltinsAuto_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaBuiltinsAuto',
  signal: signalEvaBuiltinsAuto,
  getter: getEvaBuiltinsAuto,
  setter: setEvaBuiltinsAuto,
};
/** State of parameter -eva-builtins-auto */
export const evaBuiltinsAuto: State.State<boolean> = evaBuiltinsAuto_internal;

/** Signal for state [`evaBuiltin`](#evabuiltin)  */
export const signalEvaBuiltin: Server.Signal = {
  name: 'kernel.parameters.signalEvaBuiltin',
};

const getEvaBuiltin_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaBuiltin',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaBuiltin`](#evabuiltin)  */
export const getEvaBuiltin: Server.GetRequest<null,string>= getEvaBuiltin_internal;

const setEvaBuiltin_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaBuiltin',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaBuiltin`](#evabuiltin)  */
export const setEvaBuiltin: Server.SetRequest<string,null>= setEvaBuiltin_internal;

const evaBuiltin_internal: State.State<string> = {
  name: 'kernel.parameters.evaBuiltin',
  signal: signalEvaBuiltin,
  getter: getEvaBuiltin,
  setter: setEvaBuiltin,
};
/** State of parameter -eva-builtin */
export const evaBuiltin: State.State<string> = evaBuiltin_internal;

/** Signal for state [`evaIlevel`](#evailevel)  */
export const signalEvaIlevel: Server.Signal = {
  name: 'kernel.parameters.signalEvaIlevel',
};

const getEvaIlevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaIlevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaIlevel`](#evailevel)  */
export const getEvaIlevel: Server.GetRequest<null,number>= getEvaIlevel_internal;

const setEvaIlevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaIlevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaIlevel`](#evailevel)  */
export const setEvaIlevel: Server.SetRequest<number,null>= setEvaIlevel_internal;

const evaIlevel_internal: State.State<number> = {
  name: 'kernel.parameters.evaIlevel',
  signal: signalEvaIlevel,
  getter: getEvaIlevel,
  setter: setEvaIlevel,
};
/** State of parameter -eva-ilevel */
export const evaIlevel: State.State<number> = evaIlevel_internal;

/** Signal for state [`evaSplitReturn`](#evasplitreturn)  */
export const signalEvaSplitReturn: Server.Signal = {
  name: 'kernel.parameters.signalEvaSplitReturn',
};

const getEvaSplitReturn_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaSplitReturn',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaSplitReturn`](#evasplitreturn)  */
export const getEvaSplitReturn: Server.GetRequest<null,string>= getEvaSplitReturn_internal;

const setEvaSplitReturn_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaSplitReturn',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaSplitReturn`](#evasplitreturn)  */
export const setEvaSplitReturn: Server.SetRequest<string,null>= setEvaSplitReturn_internal;

const evaSplitReturn_internal: State.State<string> = {
  name: 'kernel.parameters.evaSplitReturn',
  signal: signalEvaSplitReturn,
  getter: getEvaSplitReturn,
  setter: setEvaSplitReturn,
};
/** State of parameter -eva-split-return */
export const evaSplitReturn: State.State<string> = evaSplitReturn_internal;

/** Signal for state [`evaSplitReturnFunction`](#evasplitreturnfunction)  */
export const signalEvaSplitReturnFunction: Server.Signal = {
  name: 'kernel.parameters.signalEvaSplitReturnFunction',
};

const getEvaSplitReturnFunction_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaSplitReturnFunction',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaSplitReturnFunction`](#evasplitreturnfunction)  */
export const getEvaSplitReturnFunction: Server.GetRequest<null,string>= getEvaSplitReturnFunction_internal;

const setEvaSplitReturnFunction_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaSplitReturnFunction',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaSplitReturnFunction`](#evasplitreturnfunction)  */
export const setEvaSplitReturnFunction: Server.SetRequest<string,null>= setEvaSplitReturnFunction_internal;

const evaSplitReturnFunction_internal: State.State<string> = {
  name: 'kernel.parameters.evaSplitReturnFunction',
  signal: signalEvaSplitReturnFunction,
  getter: getEvaSplitReturnFunction,
  setter: setEvaSplitReturnFunction,
};
/** State of parameter -eva-split-return-function */
export const evaSplitReturnFunction: State.State<string> = evaSplitReturnFunction_internal;

/** Signal for state
    [`evaInterproceduralHistory`](#evainterproceduralhistory)  */
export const signalEvaInterproceduralHistory: Server.Signal = {
  name: 'kernel.parameters.signalEvaInterproceduralHistory',
};

const getEvaInterproceduralHistory_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaInterproceduralHistory',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state
    [`evaInterproceduralHistory`](#evainterproceduralhistory)  */
export const getEvaInterproceduralHistory: Server.GetRequest<null,boolean>= getEvaInterproceduralHistory_internal;

const setEvaInterproceduralHistory_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaInterproceduralHistory',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state
    [`evaInterproceduralHistory`](#evainterproceduralhistory)  */
export const setEvaInterproceduralHistory: Server.SetRequest<boolean,null>= setEvaInterproceduralHistory_internal;

const evaInterproceduralHistory_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaInterproceduralHistory',
  signal: signalEvaInterproceduralHistory,
  getter: getEvaInterproceduralHistory,
  setter: setEvaInterproceduralHistory,
};
/** State of parameter -eva-interprocedural-history */
export const evaInterproceduralHistory: State.State<boolean> = evaInterproceduralHistory_internal;

/** Signal for state [`evaInterproceduralSplits`](#evainterproceduralsplits)  */
export const signalEvaInterproceduralSplits: Server.Signal = {
  name: 'kernel.parameters.signalEvaInterproceduralSplits',
};

const getEvaInterproceduralSplits_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaInterproceduralSplits',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaInterproceduralSplits`](#evainterproceduralsplits)  */
export const getEvaInterproceduralSplits: Server.GetRequest<null,boolean>= getEvaInterproceduralSplits_internal;

const setEvaInterproceduralSplits_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaInterproceduralSplits',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaInterproceduralSplits`](#evainterproceduralsplits)  */
export const setEvaInterproceduralSplits: Server.SetRequest<boolean,null>= setEvaInterproceduralSplits_internal;

const evaInterproceduralSplits_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaInterproceduralSplits',
  signal: signalEvaInterproceduralSplits,
  getter: getEvaInterproceduralSplits,
  setter: setEvaInterproceduralSplits,
};
/** State of parameter -eva-interprocedural-splits */
export const evaInterproceduralSplits: State.State<boolean> = evaInterproceduralSplits_internal;

/** Signal for state [`evaSplitLimit`](#evasplitlimit)  */
export const signalEvaSplitLimit: Server.Signal = {
  name: 'kernel.parameters.signalEvaSplitLimit',
};

const getEvaSplitLimit_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaSplitLimit',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaSplitLimit`](#evasplitlimit)  */
export const getEvaSplitLimit: Server.GetRequest<null,number>= getEvaSplitLimit_internal;

const setEvaSplitLimit_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaSplitLimit',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaSplitLimit`](#evasplitlimit)  */
export const setEvaSplitLimit: Server.SetRequest<number,null>= setEvaSplitLimit_internal;

const evaSplitLimit_internal: State.State<number> = {
  name: 'kernel.parameters.evaSplitLimit',
  signal: signalEvaSplitLimit,
  getter: getEvaSplitLimit,
  setter: setEvaSplitLimit,
};
/** State of parameter -eva-split-limit */
export const evaSplitLimit: State.State<number> = evaSplitLimit_internal;

/** Signal for state [`evaPartitionValue`](#evapartitionvalue)  */
export const signalEvaPartitionValue: Server.Signal = {
  name: 'kernel.parameters.signalEvaPartitionValue',
};

const getEvaPartitionValue_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaPartitionValue',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaPartitionValue`](#evapartitionvalue)  */
export const getEvaPartitionValue: Server.GetRequest<null,string>= getEvaPartitionValue_internal;

const setEvaPartitionValue_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaPartitionValue',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaPartitionValue`](#evapartitionvalue)  */
export const setEvaPartitionValue: Server.SetRequest<string,null>= setEvaPartitionValue_internal;

const evaPartitionValue_internal: State.State<string> = {
  name: 'kernel.parameters.evaPartitionValue',
  signal: signalEvaPartitionValue,
  getter: getEvaPartitionValue,
  setter: setEvaPartitionValue,
};
/** State of parameter -eva-partition-value */
export const evaPartitionValue: State.State<string> = evaPartitionValue_internal;

/** Signal for state [`evaPartitionHistory`](#evapartitionhistory)  */
export const signalEvaPartitionHistory: Server.Signal = {
  name: 'kernel.parameters.signalEvaPartitionHistory',
};

const getEvaPartitionHistory_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaPartitionHistory',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaPartitionHistory`](#evapartitionhistory)  */
export const getEvaPartitionHistory: Server.GetRequest<null,number>= getEvaPartitionHistory_internal;

const setEvaPartitionHistory_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaPartitionHistory',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaPartitionHistory`](#evapartitionhistory)  */
export const setEvaPartitionHistory: Server.SetRequest<number,null>= setEvaPartitionHistory_internal;

const evaPartitionHistory_internal: State.State<number> = {
  name: 'kernel.parameters.evaPartitionHistory',
  signal: signalEvaPartitionHistory,
  getter: getEvaPartitionHistory,
  setter: setEvaPartitionHistory,
};
/** State of parameter -eva-partition-history */
export const evaPartitionHistory: State.State<number> = evaPartitionHistory_internal;

/** Signal for state [`evaDefaultLoopUnroll`](#evadefaultloopunroll)  */
export const signalEvaDefaultLoopUnroll: Server.Signal = {
  name: 'kernel.parameters.signalEvaDefaultLoopUnroll',
};

const getEvaDefaultLoopUnroll_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaDefaultLoopUnroll',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaDefaultLoopUnroll`](#evadefaultloopunroll)  */
export const getEvaDefaultLoopUnroll: Server.GetRequest<null,number>= getEvaDefaultLoopUnroll_internal;

const setEvaDefaultLoopUnroll_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaDefaultLoopUnroll',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaDefaultLoopUnroll`](#evadefaultloopunroll)  */
export const setEvaDefaultLoopUnroll: Server.SetRequest<number,null>= setEvaDefaultLoopUnroll_internal;

const evaDefaultLoopUnroll_internal: State.State<number> = {
  name: 'kernel.parameters.evaDefaultLoopUnroll',
  signal: signalEvaDefaultLoopUnroll,
  getter: getEvaDefaultLoopUnroll,
  setter: setEvaDefaultLoopUnroll,
};
/** State of parameter -eva-default-loop-unroll */
export const evaDefaultLoopUnroll: State.State<number> = evaDefaultLoopUnroll_internal;

/** Signal for state [`evaAutoLoopUnroll`](#evaautoloopunroll)  */
export const signalEvaAutoLoopUnroll: Server.Signal = {
  name: 'kernel.parameters.signalEvaAutoLoopUnroll',
};

const getEvaAutoLoopUnroll_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaAutoLoopUnroll',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaAutoLoopUnroll`](#evaautoloopunroll)  */
export const getEvaAutoLoopUnroll: Server.GetRequest<null,number>= getEvaAutoLoopUnroll_internal;

const setEvaAutoLoopUnroll_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaAutoLoopUnroll',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaAutoLoopUnroll`](#evaautoloopunroll)  */
export const setEvaAutoLoopUnroll: Server.SetRequest<number,null>= setEvaAutoLoopUnroll_internal;

const evaAutoLoopUnroll_internal: State.State<number> = {
  name: 'kernel.parameters.evaAutoLoopUnroll',
  signal: signalEvaAutoLoopUnroll,
  getter: getEvaAutoLoopUnroll,
  setter: setEvaAutoLoopUnroll,
};
/** State of parameter -eva-auto-loop-unroll */
export const evaAutoLoopUnroll: State.State<number> = evaAutoLoopUnroll_internal;

/** Signal for state [`evaMinLoopUnroll`](#evaminloopunroll)  */
export const signalEvaMinLoopUnroll: Server.Signal = {
  name: 'kernel.parameters.signalEvaMinLoopUnroll',
};

const getEvaMinLoopUnroll_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaMinLoopUnroll',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaMinLoopUnroll`](#evaminloopunroll)  */
export const getEvaMinLoopUnroll: Server.GetRequest<null,number>= getEvaMinLoopUnroll_internal;

const setEvaMinLoopUnroll_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaMinLoopUnroll',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaMinLoopUnroll`](#evaminloopunroll)  */
export const setEvaMinLoopUnroll: Server.SetRequest<number,null>= setEvaMinLoopUnroll_internal;

const evaMinLoopUnroll_internal: State.State<number> = {
  name: 'kernel.parameters.evaMinLoopUnroll',
  signal: signalEvaMinLoopUnroll,
  getter: getEvaMinLoopUnroll,
  setter: setEvaMinLoopUnroll,
};
/** State of parameter -eva-min-loop-unroll */
export const evaMinLoopUnroll: State.State<number> = evaMinLoopUnroll_internal;

/** Signal for state [`evaSlevelMergeAfterLoop`](#evaslevelmergeafterloop)  */
export const signalEvaSlevelMergeAfterLoop: Server.Signal = {
  name: 'kernel.parameters.signalEvaSlevelMergeAfterLoop',
};

const getEvaSlevelMergeAfterLoop_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaSlevelMergeAfterLoop',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaSlevelMergeAfterLoop`](#evaslevelmergeafterloop)  */
export const getEvaSlevelMergeAfterLoop: Server.GetRequest<null,string>= getEvaSlevelMergeAfterLoop_internal;

const setEvaSlevelMergeAfterLoop_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaSlevelMergeAfterLoop',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaSlevelMergeAfterLoop`](#evaslevelmergeafterloop)  */
export const setEvaSlevelMergeAfterLoop: Server.SetRequest<string,null>= setEvaSlevelMergeAfterLoop_internal;

const evaSlevelMergeAfterLoop_internal: State.State<string> = {
  name: 'kernel.parameters.evaSlevelMergeAfterLoop',
  signal: signalEvaSlevelMergeAfterLoop,
  getter: getEvaSlevelMergeAfterLoop,
  setter: setEvaSlevelMergeAfterLoop,
};
/** State of parameter -eva-slevel-merge-after-loop */
export const evaSlevelMergeAfterLoop: State.State<string> = evaSlevelMergeAfterLoop_internal;

/** Signal for state [`evaSlevelFunction`](#evaslevelfunction)  */
export const signalEvaSlevelFunction: Server.Signal = {
  name: 'kernel.parameters.signalEvaSlevelFunction',
};

const getEvaSlevelFunction_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaSlevelFunction',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaSlevelFunction`](#evaslevelfunction)  */
export const getEvaSlevelFunction: Server.GetRequest<null,string>= getEvaSlevelFunction_internal;

const setEvaSlevelFunction_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaSlevelFunction',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaSlevelFunction`](#evaslevelfunction)  */
export const setEvaSlevelFunction: Server.SetRequest<string,null>= setEvaSlevelFunction_internal;

const evaSlevelFunction_internal: State.State<string> = {
  name: 'kernel.parameters.evaSlevelFunction',
  signal: signalEvaSlevelFunction,
  getter: getEvaSlevelFunction,
  setter: setEvaSlevelFunction,
};
/** State of parameter -eva-slevel-function */
export const evaSlevelFunction: State.State<string> = evaSlevelFunction_internal;

/** Signal for state [`evaSlevel`](#evaslevel)  */
export const signalEvaSlevel: Server.Signal = {
  name: 'kernel.parameters.signalEvaSlevel',
};

const getEvaSlevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaSlevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaSlevel`](#evaslevel)  */
export const getEvaSlevel: Server.GetRequest<null,number>= getEvaSlevel_internal;

const setEvaSlevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaSlevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaSlevel`](#evaslevel)  */
export const setEvaSlevel: Server.SetRequest<number,null>= setEvaSlevel_internal;

const evaSlevel_internal: State.State<number> = {
  name: 'kernel.parameters.evaSlevel',
  signal: signalEvaSlevel,
  getter: getEvaSlevel,
  setter: setEvaSlevel,
};
/** State of parameter -eva-slevel */
export const evaSlevel: State.State<number> = evaSlevel_internal;

/** Signal for state [`evaUnrollRecursiveCalls`](#evaunrollrecursivecalls)  */
export const signalEvaUnrollRecursiveCalls: Server.Signal = {
  name: 'kernel.parameters.signalEvaUnrollRecursiveCalls',
};

const getEvaUnrollRecursiveCalls_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaUnrollRecursiveCalls',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaUnrollRecursiveCalls`](#evaunrollrecursivecalls)  */
export const getEvaUnrollRecursiveCalls: Server.GetRequest<null,number>= getEvaUnrollRecursiveCalls_internal;

const setEvaUnrollRecursiveCalls_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaUnrollRecursiveCalls',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaUnrollRecursiveCalls`](#evaunrollrecursivecalls)  */
export const setEvaUnrollRecursiveCalls: Server.SetRequest<number,null>= setEvaUnrollRecursiveCalls_internal;

const evaUnrollRecursiveCalls_internal: State.State<number> = {
  name: 'kernel.parameters.evaUnrollRecursiveCalls',
  signal: signalEvaUnrollRecursiveCalls,
  getter: getEvaUnrollRecursiveCalls,
  setter: setEvaUnrollRecursiveCalls,
};
/** State of parameter -eva-unroll-recursive-calls */
export const evaUnrollRecursiveCalls: State.State<number> = evaUnrollRecursiveCalls_internal;

/** Signal for state [`evaWideningPeriod`](#evawideningperiod)  */
export const signalEvaWideningPeriod: Server.Signal = {
  name: 'kernel.parameters.signalEvaWideningPeriod',
};

const getEvaWideningPeriod_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaWideningPeriod',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaWideningPeriod`](#evawideningperiod)  */
export const getEvaWideningPeriod: Server.GetRequest<null,number>= getEvaWideningPeriod_internal;

const setEvaWideningPeriod_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaWideningPeriod',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaWideningPeriod`](#evawideningperiod)  */
export const setEvaWideningPeriod: Server.SetRequest<number,null>= setEvaWideningPeriod_internal;

const evaWideningPeriod_internal: State.State<number> = {
  name: 'kernel.parameters.evaWideningPeriod',
  signal: signalEvaWideningPeriod,
  getter: getEvaWideningPeriod,
  setter: setEvaWideningPeriod,
};
/** State of parameter -eva-widening-period */
export const evaWideningPeriod: State.State<number> = evaWideningPeriod_internal;

/** Signal for state [`evaWideningDelay`](#evawideningdelay)  */
export const signalEvaWideningDelay: Server.Signal = {
  name: 'kernel.parameters.signalEvaWideningDelay',
};

const getEvaWideningDelay_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaWideningDelay',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaWideningDelay`](#evawideningdelay)  */
export const getEvaWideningDelay: Server.GetRequest<null,number>= getEvaWideningDelay_internal;

const setEvaWideningDelay_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaWideningDelay',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaWideningDelay`](#evawideningdelay)  */
export const setEvaWideningDelay: Server.SetRequest<number,null>= setEvaWideningDelay_internal;

const evaWideningDelay_internal: State.State<number> = {
  name: 'kernel.parameters.evaWideningDelay',
  signal: signalEvaWideningDelay,
  getter: getEvaWideningDelay,
  setter: setEvaWideningDelay,
};
/** State of parameter -eva-widening-delay */
export const evaWideningDelay: State.State<number> = evaWideningDelay_internal;

/** Signal for state [`evaStatisticsFile`](#evastatisticsfile)  */
export const signalEvaStatisticsFile: Server.Signal = {
  name: 'kernel.parameters.signalEvaStatisticsFile',
};

const getEvaStatisticsFile_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaStatisticsFile',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaStatisticsFile`](#evastatisticsfile)  */
export const getEvaStatisticsFile: Server.GetRequest<null,string>= getEvaStatisticsFile_internal;

const setEvaStatisticsFile_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaStatisticsFile',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaStatisticsFile`](#evastatisticsfile)  */
export const setEvaStatisticsFile: Server.SetRequest<string,null>= setEvaStatisticsFile_internal;

const evaStatisticsFile_internal: State.State<string> = {
  name: 'kernel.parameters.evaStatisticsFile',
  signal: signalEvaStatisticsFile,
  getter: getEvaStatisticsFile,
  setter: setEvaStatisticsFile,
};
/** State of parameter -eva-statistics-file */
export const evaStatisticsFile: State.State<string> = evaStatisticsFile_internal;

/** Signal for state [`evaNumerorsLogFile`](#evanumerorslogfile)  */
export const signalEvaNumerorsLogFile: Server.Signal = {
  name: 'kernel.parameters.signalEvaNumerorsLogFile',
};

const getEvaNumerorsLogFile_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaNumerorsLogFile',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaNumerorsLogFile`](#evanumerorslogfile)  */
export const getEvaNumerorsLogFile: Server.GetRequest<null,string>= getEvaNumerorsLogFile_internal;

const setEvaNumerorsLogFile_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaNumerorsLogFile',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaNumerorsLogFile`](#evanumerorslogfile)  */
export const setEvaNumerorsLogFile: Server.SetRequest<string,null>= setEvaNumerorsLogFile_internal;

const evaNumerorsLogFile_internal: State.State<string> = {
  name: 'kernel.parameters.evaNumerorsLogFile',
  signal: signalEvaNumerorsLogFile,
  getter: getEvaNumerorsLogFile,
  setter: setEvaNumerorsLogFile,
};
/** State of parameter -eva-numerors-log-file */
export const evaNumerorsLogFile: State.State<string> = evaNumerorsLogFile_internal;

/** Signal for state [`evaReportRedStatuses`](#evareportredstatuses)  */
export const signalEvaReportRedStatuses: Server.Signal = {
  name: 'kernel.parameters.signalEvaReportRedStatuses',
};

const getEvaReportRedStatuses_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaReportRedStatuses',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaReportRedStatuses`](#evareportredstatuses)  */
export const getEvaReportRedStatuses: Server.GetRequest<null,string>= getEvaReportRedStatuses_internal;

const setEvaReportRedStatuses_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaReportRedStatuses',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaReportRedStatuses`](#evareportredstatuses)  */
export const setEvaReportRedStatuses: Server.SetRequest<string,null>= setEvaReportRedStatuses_internal;

const evaReportRedStatuses_internal: State.State<string> = {
  name: 'kernel.parameters.evaReportRedStatuses',
  signal: signalEvaReportRedStatuses,
  getter: getEvaReportRedStatuses,
  setter: setEvaReportRedStatuses,
};
/** State of parameter -eva-report-red-statuses */
export const evaReportRedStatuses: State.State<string> = evaReportRedStatuses_internal;

/** Signal for state [`evaPrintCallstacks`](#evaprintcallstacks)  */
export const signalEvaPrintCallstacks: Server.Signal = {
  name: 'kernel.parameters.signalEvaPrintCallstacks',
};

const getEvaPrintCallstacks_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaPrintCallstacks',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaPrintCallstacks`](#evaprintcallstacks)  */
export const getEvaPrintCallstacks: Server.GetRequest<null,boolean>= getEvaPrintCallstacks_internal;

const setEvaPrintCallstacks_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaPrintCallstacks',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaPrintCallstacks`](#evaprintcallstacks)  */
export const setEvaPrintCallstacks: Server.SetRequest<boolean,null>= setEvaPrintCallstacks_internal;

const evaPrintCallstacks_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaPrintCallstacks',
  signal: signalEvaPrintCallstacks,
  getter: getEvaPrintCallstacks,
  setter: setEvaPrintCallstacks,
};
/** State of parameter -eva-print-callstacks */
export const evaPrintCallstacks: State.State<boolean> = evaPrintCallstacks_internal;

/** Signal for state [`evaShowSlevel`](#evashowslevel)  */
export const signalEvaShowSlevel: Server.Signal = {
  name: 'kernel.parameters.signalEvaShowSlevel',
};

const getEvaShowSlevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaShowSlevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaShowSlevel`](#evashowslevel)  */
export const getEvaShowSlevel: Server.GetRequest<null,number>= getEvaShowSlevel_internal;

const setEvaShowSlevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaShowSlevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaShowSlevel`](#evashowslevel)  */
export const setEvaShowSlevel: Server.SetRequest<number,null>= setEvaShowSlevel_internal;

const evaShowSlevel_internal: State.State<number> = {
  name: 'kernel.parameters.evaShowSlevel',
  signal: signalEvaShowSlevel,
  getter: getEvaShowSlevel,
  setter: setEvaShowSlevel,
};
/** State of parameter -eva-show-slevel */
export const evaShowSlevel: State.State<number> = evaShowSlevel_internal;

/** Signal for state [`evaFlamegraph`](#evaflamegraph)  */
export const signalEvaFlamegraph: Server.Signal = {
  name: 'kernel.parameters.signalEvaFlamegraph',
};

const getEvaFlamegraph_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaFlamegraph',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaFlamegraph`](#evaflamegraph)  */
export const getEvaFlamegraph: Server.GetRequest<null,string>= getEvaFlamegraph_internal;

const setEvaFlamegraph_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaFlamegraph',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaFlamegraph`](#evaflamegraph)  */
export const setEvaFlamegraph: Server.SetRequest<string,null>= setEvaFlamegraph_internal;

const evaFlamegraph_internal: State.State<string> = {
  name: 'kernel.parameters.evaFlamegraph',
  signal: signalEvaFlamegraph,
  getter: getEvaFlamegraph,
  setter: setEvaFlamegraph,
};
/** State of parameter -eva-flamegraph */
export const evaFlamegraph: State.State<string> = evaFlamegraph_internal;

/** Signal for state [`evaShowPerf`](#evashowperf)  */
export const signalEvaShowPerf: Server.Signal = {
  name: 'kernel.parameters.signalEvaShowPerf',
};

const getEvaShowPerf_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaShowPerf',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaShowPerf`](#evashowperf)  */
export const getEvaShowPerf: Server.GetRequest<null,boolean>= getEvaShowPerf_internal;

const setEvaShowPerf_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaShowPerf',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaShowPerf`](#evashowperf)  */
export const setEvaShowPerf: Server.SetRequest<boolean,null>= setEvaShowPerf_internal;

const evaShowPerf_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaShowPerf',
  signal: signalEvaShowPerf,
  getter: getEvaShowPerf,
  setter: setEvaShowPerf,
};
/** State of parameter -eva-show-perf */
export const evaShowPerf: State.State<boolean> = evaShowPerf_internal;

/** Signal for state [`evaShowProgress`](#evashowprogress)  */
export const signalEvaShowProgress: Server.Signal = {
  name: 'kernel.parameters.signalEvaShowProgress',
};

const getEvaShowProgress_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaShowProgress',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaShowProgress`](#evashowprogress)  */
export const getEvaShowProgress: Server.GetRequest<null,boolean>= getEvaShowProgress_internal;

const setEvaShowProgress_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaShowProgress',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaShowProgress`](#evashowprogress)  */
export const setEvaShowProgress: Server.SetRequest<boolean,null>= setEvaShowProgress_internal;

const evaShowProgress_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaShowProgress',
  signal: signalEvaShowProgress,
  getter: getEvaShowProgress,
  setter: setEvaShowProgress,
};
/** State of parameter -eva-show-progress */
export const evaShowProgress: State.State<boolean> = evaShowProgress_internal;

/** Signal for state [`evaPrint`](#evaprint)  */
export const signalEvaPrint: Server.Signal = {
  name: 'kernel.parameters.signalEvaPrint',
};

const getEvaPrint_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaPrint',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaPrint`](#evaprint)  */
export const getEvaPrint: Server.GetRequest<null,boolean>= getEvaPrint_internal;

const setEvaPrint_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaPrint',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaPrint`](#evaprint)  */
export const setEvaPrint: Server.SetRequest<boolean,null>= setEvaPrint_internal;

const evaPrint_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaPrint',
  signal: signalEvaPrint,
  getter: getEvaPrint,
  setter: setEvaPrint,
};
/** State of parameter -eva-print */
export const evaPrint: State.State<boolean> = evaPrint_internal;

/** Signal for state [`evaWarnKey`](#evawarnkey)  */
export const signalEvaWarnKey: Server.Signal = {
  name: 'kernel.parameters.signalEvaWarnKey',
};

const getEvaWarnKey_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaWarnKey',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaWarnKey`](#evawarnkey)  */
export const getEvaWarnKey: Server.GetRequest<null,string>= getEvaWarnKey_internal;

const setEvaWarnKey_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaWarnKey',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaWarnKey`](#evawarnkey)  */
export const setEvaWarnKey: Server.SetRequest<string,null>= setEvaWarnKey_internal;

const evaWarnKey_internal: State.State<string> = {
  name: 'kernel.parameters.evaWarnKey',
  signal: signalEvaWarnKey,
  getter: getEvaWarnKey,
  setter: setEvaWarnKey,
};
/** State of parameter -eva-warn-key */
export const evaWarnKey: State.State<string> = evaWarnKey_internal;

/** Signal for state [`evaMsgKey`](#evamsgkey)  */
export const signalEvaMsgKey: Server.Signal = {
  name: 'kernel.parameters.signalEvaMsgKey',
};

const getEvaMsgKey_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaMsgKey',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaMsgKey`](#evamsgkey)  */
export const getEvaMsgKey: Server.GetRequest<null,string>= getEvaMsgKey_internal;

const setEvaMsgKey_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaMsgKey',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaMsgKey`](#evamsgkey)  */
export const setEvaMsgKey: Server.SetRequest<string,null>= setEvaMsgKey_internal;

const evaMsgKey_internal: State.State<string> = {
  name: 'kernel.parameters.evaMsgKey',
  signal: signalEvaMsgKey,
  getter: getEvaMsgKey,
  setter: setEvaMsgKey,
};
/** State of parameter -eva-msg-key */
export const evaMsgKey: State.State<string> = evaMsgKey_internal;

/** Signal for state [`evaDebug`](#evadebug)  */
export const signalEvaDebug: Server.Signal = {
  name: 'kernel.parameters.signalEvaDebug',
};

const getEvaDebug_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaDebug',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaDebug`](#evadebug)  */
export const getEvaDebug: Server.GetRequest<null,number>= getEvaDebug_internal;

const setEvaDebug_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaDebug',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaDebug`](#evadebug)  */
export const setEvaDebug: Server.SetRequest<number,null>= setEvaDebug_internal;

const evaDebug_internal: State.State<number> = {
  name: 'kernel.parameters.evaDebug',
  signal: signalEvaDebug,
  getter: getEvaDebug,
  setter: setEvaDebug,
};
/** State of parameter -eva-debug */
export const evaDebug: State.State<number> = evaDebug_internal;

/** Signal for state [`evaVerbose`](#evaverbose)  */
export const signalEvaVerbose: Server.Signal = {
  name: 'kernel.parameters.signalEvaVerbose',
};

const getEvaVerbose_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaVerbose',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaVerbose`](#evaverbose)  */
export const getEvaVerbose: Server.GetRequest<null,number>= getEvaVerbose_internal;

const setEvaVerbose_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaVerbose',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaVerbose`](#evaverbose)  */
export const setEvaVerbose: Server.SetRequest<number,null>= setEvaVerbose_internal;

const evaVerbose_internal: State.State<number> = {
  name: 'kernel.parameters.evaVerbose',
  signal: signalEvaVerbose,
  getter: getEvaVerbose,
  setter: setEvaVerbose,
};
/** State of parameter -eva-verbose */
export const evaVerbose: State.State<number> = evaVerbose_internal;

/** Signal for state [`evaLog`](#evalog)  */
export const signalEvaLog: Server.Signal = {
  name: 'kernel.parameters.signalEvaLog',
};

const getEvaLog_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaLog',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaLog`](#evalog)  */
export const getEvaLog: Server.GetRequest<null,string>= getEvaLog_internal;

const setEvaLog_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaLog',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaLog`](#evalog)  */
export const setEvaLog: Server.SetRequest<string,null>= setEvaLog_internal;

const evaLog_internal: State.State<string> = {
  name: 'kernel.parameters.evaLog',
  signal: signalEvaLog,
  getter: getEvaLog,
  setter: setEvaLog,
};
/** State of parameter -eva-log */
export const evaLog: State.State<string> = evaLog_internal;

/** Signal for state
    [`evaInitializationPaddingGlobals`](#evainitializationpaddingglobals)  */
export const signalEvaInitializationPaddingGlobals: Server.Signal = {
  name: 'kernel.parameters.signalEvaInitializationPaddingGlobals',
};

const getEvaInitializationPaddingGlobals_internal: Server.GetRequest<
  null,
  string
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaInitializationPaddingGlobals',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state
    [`evaInitializationPaddingGlobals`](#evainitializationpaddingglobals)  */
export const getEvaInitializationPaddingGlobals: Server.GetRequest<
  null,
  string
  >= getEvaInitializationPaddingGlobals_internal;

const setEvaInitializationPaddingGlobals_internal: Server.SetRequest<
  string,
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaInitializationPaddingGlobals',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state
    [`evaInitializationPaddingGlobals`](#evainitializationpaddingglobals)  */
export const setEvaInitializationPaddingGlobals: Server.SetRequest<
  string,
  null
  >= setEvaInitializationPaddingGlobals_internal;

const evaInitializationPaddingGlobals_internal: State.State<string> = {
  name: 'kernel.parameters.evaInitializationPaddingGlobals',
  signal: signalEvaInitializationPaddingGlobals,
  getter: getEvaInitializationPaddingGlobals,
  setter: setEvaInitializationPaddingGlobals,
};
/** State of parameter -eva-initialization-padding-globals */
export const evaInitializationPaddingGlobals: State.State<string> = evaInitializationPaddingGlobals_internal;

/** Signal for state [`evaContextValidPointers`](#evacontextvalidpointers)  */
export const signalEvaContextValidPointers: Server.Signal = {
  name: 'kernel.parameters.signalEvaContextValidPointers',
};

const getEvaContextValidPointers_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaContextValidPointers',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaContextValidPointers`](#evacontextvalidpointers)  */
export const getEvaContextValidPointers: Server.GetRequest<null,boolean>= getEvaContextValidPointers_internal;

const setEvaContextValidPointers_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaContextValidPointers',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaContextValidPointers`](#evacontextvalidpointers)  */
export const setEvaContextValidPointers: Server.SetRequest<boolean,null>= setEvaContextValidPointers_internal;

const evaContextValidPointers_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaContextValidPointers',
  signal: signalEvaContextValidPointers,
  getter: getEvaContextValidPointers,
  setter: setEvaContextValidPointers,
};
/** State of parameter -eva-context-valid-pointers */
export const evaContextValidPointers: State.State<boolean> = evaContextValidPointers_internal;

/** Signal for state [`evaContextWidth`](#evacontextwidth)  */
export const signalEvaContextWidth: Server.Signal = {
  name: 'kernel.parameters.signalEvaContextWidth',
};

const getEvaContextWidth_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaContextWidth',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaContextWidth`](#evacontextwidth)  */
export const getEvaContextWidth: Server.GetRequest<null,number>= getEvaContextWidth_internal;

const setEvaContextWidth_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaContextWidth',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaContextWidth`](#evacontextwidth)  */
export const setEvaContextWidth: Server.SetRequest<number,null>= setEvaContextWidth_internal;

const evaContextWidth_internal: State.State<number> = {
  name: 'kernel.parameters.evaContextWidth',
  signal: signalEvaContextWidth,
  getter: getEvaContextWidth,
  setter: setEvaContextWidth,
};
/** State of parameter -eva-context-width */
export const evaContextWidth: State.State<number> = evaContextWidth_internal;

/** Signal for state [`evaContextDepth`](#evacontextdepth)  */
export const signalEvaContextDepth: Server.Signal = {
  name: 'kernel.parameters.signalEvaContextDepth',
};

const getEvaContextDepth_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaContextDepth',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaContextDepth`](#evacontextdepth)  */
export const getEvaContextDepth: Server.GetRequest<null,number>= getEvaContextDepth_internal;

const setEvaContextDepth_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaContextDepth',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaContextDepth`](#evacontextdepth)  */
export const setEvaContextDepth: Server.SetRequest<number,null>= setEvaContextDepth_internal;

const evaContextDepth_internal: State.State<number> = {
  name: 'kernel.parameters.evaContextDepth',
  signal: signalEvaContextDepth,
  getter: getEvaContextDepth,
  setter: setEvaContextDepth,
};
/** State of parameter -eva-context-depth */
export const evaContextDepth: State.State<number> = evaContextDepth_internal;

/** Signal for state [`evaMlevel`](#evamlevel)  */
export const signalEvaMlevel: Server.Signal = {
  name: 'kernel.parameters.signalEvaMlevel',
};

const getEvaMlevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaMlevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaMlevel`](#evamlevel)  */
export const getEvaMlevel: Server.GetRequest<null,number>= getEvaMlevel_internal;

const setEvaMlevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaMlevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaMlevel`](#evamlevel)  */
export const setEvaMlevel: Server.SetRequest<number,null>= setEvaMlevel_internal;

const evaMlevel_internal: State.State<number> = {
  name: 'kernel.parameters.evaMlevel',
  signal: signalEvaMlevel,
  getter: getEvaMlevel,
  setter: setEvaMlevel,
};
/** State of parameter -eva-mlevel */
export const evaMlevel: State.State<number> = evaMlevel_internal;

/** Signal for state [`evaAllocReturnsNull`](#evaallocreturnsnull)  */
export const signalEvaAllocReturnsNull: Server.Signal = {
  name: 'kernel.parameters.signalEvaAllocReturnsNull',
};

const getEvaAllocReturnsNull_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaAllocReturnsNull',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaAllocReturnsNull`](#evaallocreturnsnull)  */
export const getEvaAllocReturnsNull: Server.GetRequest<null,boolean>= getEvaAllocReturnsNull_internal;

const setEvaAllocReturnsNull_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaAllocReturnsNull',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaAllocReturnsNull`](#evaallocreturnsnull)  */
export const setEvaAllocReturnsNull: Server.SetRequest<boolean,null>= setEvaAllocReturnsNull_internal;

const evaAllocReturnsNull_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaAllocReturnsNull',
  signal: signalEvaAllocReturnsNull,
  getter: getEvaAllocReturnsNull,
  setter: setEvaAllocReturnsNull,
};
/** State of parameter -eva-alloc-returns-null */
export const evaAllocReturnsNull: State.State<boolean> = evaAllocReturnsNull_internal;

/** Signal for state [`evaAllocFunctions`](#evaallocfunctions)  */
export const signalEvaAllocFunctions: Server.Signal = {
  name: 'kernel.parameters.signalEvaAllocFunctions',
};

const getEvaAllocFunctions_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaAllocFunctions',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaAllocFunctions`](#evaallocfunctions)  */
export const getEvaAllocFunctions: Server.GetRequest<null,string>= getEvaAllocFunctions_internal;

const setEvaAllocFunctions_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaAllocFunctions',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaAllocFunctions`](#evaallocfunctions)  */
export const setEvaAllocFunctions: Server.SetRequest<string,null>= setEvaAllocFunctions_internal;

const evaAllocFunctions_internal: State.State<string> = {
  name: 'kernel.parameters.evaAllocFunctions',
  signal: signalEvaAllocFunctions,
  getter: getEvaAllocFunctions,
  setter: setEvaAllocFunctions,
};
/** State of parameter -eva-alloc-functions */
export const evaAllocFunctions: State.State<string> = evaAllocFunctions_internal;

/** Signal for state [`evaAllocBuiltin`](#evaallocbuiltin)  */
export const signalEvaAllocBuiltin: Server.Signal = {
  name: 'kernel.parameters.signalEvaAllocBuiltin',
};

const getEvaAllocBuiltin_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaAllocBuiltin',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaAllocBuiltin`](#evaallocbuiltin)  */
export const getEvaAllocBuiltin: Server.GetRequest<null,string>= getEvaAllocBuiltin_internal;

const setEvaAllocBuiltin_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaAllocBuiltin',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaAllocBuiltin`](#evaallocbuiltin)  */
export const setEvaAllocBuiltin: Server.SetRequest<string,null>= setEvaAllocBuiltin_internal;

const evaAllocBuiltin_internal: State.State<string> = {
  name: 'kernel.parameters.evaAllocBuiltin',
  signal: signalEvaAllocBuiltin,
  getter: getEvaAllocBuiltin,
  setter: setEvaAllocBuiltin,
};
/** State of parameter -eva-alloc-builtin */
export const evaAllocBuiltin: State.State<string> = evaAllocBuiltin_internal;

/** Signal for state [`evaInitializedLocals`](#evainitializedlocals)  */
export const signalEvaInitializedLocals: Server.Signal = {
  name: 'kernel.parameters.signalEvaInitializedLocals',
};

const getEvaInitializedLocals_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaInitializedLocals',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaInitializedLocals`](#evainitializedlocals)  */
export const getEvaInitializedLocals: Server.GetRequest<null,boolean>= getEvaInitializedLocals_internal;

const setEvaInitializedLocals_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaInitializedLocals',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaInitializedLocals`](#evainitializedlocals)  */
export const setEvaInitializedLocals: Server.SetRequest<boolean,null>= setEvaInitializedLocals_internal;

const evaInitializedLocals_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaInitializedLocals',
  signal: signalEvaInitializedLocals,
  getter: getEvaInitializedLocals,
  setter: setEvaInitializedLocals,
};
/** State of parameter -eva-initialized-locals */
export const evaInitializedLocals: State.State<boolean> = evaInitializedLocals_internal;

/** Signal for state [`evaReduceOnLogicAlarms`](#evareduceonlogicalarms)  */
export const signalEvaReduceOnLogicAlarms: Server.Signal = {
  name: 'kernel.parameters.signalEvaReduceOnLogicAlarms',
};

const getEvaReduceOnLogicAlarms_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaReduceOnLogicAlarms',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaReduceOnLogicAlarms`](#evareduceonlogicalarms)  */
export const getEvaReduceOnLogicAlarms: Server.GetRequest<null,boolean>= getEvaReduceOnLogicAlarms_internal;

const setEvaReduceOnLogicAlarms_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaReduceOnLogicAlarms',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaReduceOnLogicAlarms`](#evareduceonlogicalarms)  */
export const setEvaReduceOnLogicAlarms: Server.SetRequest<boolean,null>= setEvaReduceOnLogicAlarms_internal;

const evaReduceOnLogicAlarms_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaReduceOnLogicAlarms',
  signal: signalEvaReduceOnLogicAlarms,
  getter: getEvaReduceOnLogicAlarms,
  setter: setEvaReduceOnLogicAlarms,
};
/** State of parameter -eva-reduce-on-logic-alarms */
export const evaReduceOnLogicAlarms: State.State<boolean> = evaReduceOnLogicAlarms_internal;

/** Signal for state [`evaWarnCopyIndeterminate`](#evawarncopyindeterminate)  */
export const signalEvaWarnCopyIndeterminate: Server.Signal = {
  name: 'kernel.parameters.signalEvaWarnCopyIndeterminate',
};

const getEvaWarnCopyIndeterminate_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaWarnCopyIndeterminate',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaWarnCopyIndeterminate`](#evawarncopyindeterminate)  */
export const getEvaWarnCopyIndeterminate: Server.GetRequest<null,string>= getEvaWarnCopyIndeterminate_internal;

const setEvaWarnCopyIndeterminate_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaWarnCopyIndeterminate',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaWarnCopyIndeterminate`](#evawarncopyindeterminate)  */
export const setEvaWarnCopyIndeterminate: Server.SetRequest<string,null>= setEvaWarnCopyIndeterminate_internal;

const evaWarnCopyIndeterminate_internal: State.State<string> = {
  name: 'kernel.parameters.evaWarnCopyIndeterminate',
  signal: signalEvaWarnCopyIndeterminate,
  getter: getEvaWarnCopyIndeterminate,
  setter: setEvaWarnCopyIndeterminate,
};
/** State of parameter -eva-warn-copy-indeterminate */
export const evaWarnCopyIndeterminate: State.State<string> = evaWarnCopyIndeterminate_internal;

/** Signal for state
    [`evaWarnPointerSubtraction`](#evawarnpointersubtraction)  */
export const signalEvaWarnPointerSubtraction: Server.Signal = {
  name: 'kernel.parameters.signalEvaWarnPointerSubtraction',
};

const getEvaWarnPointerSubtraction_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaWarnPointerSubtraction',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state
    [`evaWarnPointerSubtraction`](#evawarnpointersubtraction)  */
export const getEvaWarnPointerSubtraction: Server.GetRequest<null,boolean>= getEvaWarnPointerSubtraction_internal;

const setEvaWarnPointerSubtraction_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaWarnPointerSubtraction',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state
    [`evaWarnPointerSubtraction`](#evawarnpointersubtraction)  */
export const setEvaWarnPointerSubtraction: Server.SetRequest<boolean,null>= setEvaWarnPointerSubtraction_internal;

const evaWarnPointerSubtraction_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaWarnPointerSubtraction',
  signal: signalEvaWarnPointerSubtraction,
  getter: getEvaWarnPointerSubtraction,
  setter: setEvaWarnPointerSubtraction,
};
/** State of parameter -eva-warn-pointer-subtraction */
export const evaWarnPointerSubtraction: State.State<boolean> = evaWarnPointerSubtraction_internal;

/** Signal for state
    [`evaWarnSignedConvertedDowncast`](#evawarnsignedconverteddowncast)  */
export const signalEvaWarnSignedConvertedDowncast: Server.Signal = {
  name: 'kernel.parameters.signalEvaWarnSignedConvertedDowncast',
};

const getEvaWarnSignedConvertedDowncast_internal: Server.GetRequest<
  null,
  boolean
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaWarnSignedConvertedDowncast',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state
    [`evaWarnSignedConvertedDowncast`](#evawarnsignedconverteddowncast)  */
export const getEvaWarnSignedConvertedDowncast: Server.GetRequest<
  null,
  boolean
  >= getEvaWarnSignedConvertedDowncast_internal;

const setEvaWarnSignedConvertedDowncast_internal: Server.SetRequest<
  boolean,
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaWarnSignedConvertedDowncast',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state
    [`evaWarnSignedConvertedDowncast`](#evawarnsignedconverteddowncast)  */
export const setEvaWarnSignedConvertedDowncast: Server.SetRequest<
  boolean,
  null
  >= setEvaWarnSignedConvertedDowncast_internal;

const evaWarnSignedConvertedDowncast_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaWarnSignedConvertedDowncast',
  signal: signalEvaWarnSignedConvertedDowncast,
  getter: getEvaWarnSignedConvertedDowncast,
  setter: setEvaWarnSignedConvertedDowncast,
};
/** State of parameter -eva-warn-signed-converted-downcast */
export const evaWarnSignedConvertedDowncast: State.State<boolean> = evaWarnSignedConvertedDowncast_internal;

/** Signal for state
    [`evaWarnUndefinedPointerComparison`](#evawarnundefinedpointercomparison)  */
export const signalEvaWarnUndefinedPointerComparison: Server.Signal = {
  name: 'kernel.parameters.signalEvaWarnUndefinedPointerComparison',
};

const getEvaWarnUndefinedPointerComparison_internal: Server.GetRequest<
  null,
  string
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaWarnUndefinedPointerComparison',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state
    [`evaWarnUndefinedPointerComparison`](#evawarnundefinedpointercomparison)  */
export const getEvaWarnUndefinedPointerComparison: Server.GetRequest<
  null,
  string
  >= getEvaWarnUndefinedPointerComparison_internal;

const setEvaWarnUndefinedPointerComparison_internal: Server.SetRequest<
  string,
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaWarnUndefinedPointerComparison',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state
    [`evaWarnUndefinedPointerComparison`](#evawarnundefinedpointercomparison)  */
export const setEvaWarnUndefinedPointerComparison: Server.SetRequest<
  string,
  null
  >= setEvaWarnUndefinedPointerComparison_internal;

const evaWarnUndefinedPointerComparison_internal: State.State<string> = {
  name: 'kernel.parameters.evaWarnUndefinedPointerComparison',
  signal: signalEvaWarnUndefinedPointerComparison,
  getter: getEvaWarnUndefinedPointerComparison,
  setter: setEvaWarnUndefinedPointerComparison,
};
/** State of parameter -eva-warn-undefined-pointer-comparison */
export const evaWarnUndefinedPointerComparison: State.State<string> = evaWarnUndefinedPointerComparison_internal;

/** Signal for state
    [`evaUndefinedPointerComparisonPropagateAll`](#evaundefinedpointercomparisonpropagateall)
     */
export const signalEvaUndefinedPointerComparisonPropagateAll: Server.Signal = {
  name: 'kernel.parameters.signalEvaUndefinedPointerComparisonPropagateAll',
};

const getEvaUndefinedPointerComparisonPropagateAll_internal: Server.GetRequest<
  null,
  boolean
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaUndefinedPointerComparisonPropagateAll',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state
    [`evaUndefinedPointerComparisonPropagateAll`](#evaundefinedpointercomparisonpropagateall)
     */
export const getEvaUndefinedPointerComparisonPropagateAll: Server.GetRequest<
  null,
  boolean
  >= getEvaUndefinedPointerComparisonPropagateAll_internal;

const setEvaUndefinedPointerComparisonPropagateAll_internal: Server.SetRequest<
  boolean,
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaUndefinedPointerComparisonPropagateAll',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state
    [`evaUndefinedPointerComparisonPropagateAll`](#evaundefinedpointercomparisonpropagateall)
     */
export const setEvaUndefinedPointerComparisonPropagateAll: Server.SetRequest<
  boolean,
  null
  >= setEvaUndefinedPointerComparisonPropagateAll_internal;

const evaUndefinedPointerComparisonPropagateAll_internal: State.State<
  boolean
  > = {
  name: 'kernel.parameters.evaUndefinedPointerComparisonPropagateAll',
  signal: signalEvaUndefinedPointerComparisonPropagateAll,
  getter: getEvaUndefinedPointerComparisonPropagateAll,
  setter: setEvaUndefinedPointerComparisonPropagateAll,
};
/** State of parameter -eva-undefined-pointer-comparison-propagate-all */
export const evaUndefinedPointerComparisonPropagateAll: State.State<boolean> = evaUndefinedPointerComparisonPropagateAll_internal;

/** Signal for state
    [`evaMultidimDisjunctiveInvariants`](#evamultidimdisjunctiveinvariants)  */
export const signalEvaMultidimDisjunctiveInvariants: Server.Signal = {
  name: 'kernel.parameters.signalEvaMultidimDisjunctiveInvariants',
};

const getEvaMultidimDisjunctiveInvariants_internal: Server.GetRequest<
  null,
  boolean
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaMultidimDisjunctiveInvariants',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state
    [`evaMultidimDisjunctiveInvariants`](#evamultidimdisjunctiveinvariants)  */
export const getEvaMultidimDisjunctiveInvariants: Server.GetRequest<
  null,
  boolean
  >= getEvaMultidimDisjunctiveInvariants_internal;

const setEvaMultidimDisjunctiveInvariants_internal: Server.SetRequest<
  boolean,
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaMultidimDisjunctiveInvariants',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state
    [`evaMultidimDisjunctiveInvariants`](#evamultidimdisjunctiveinvariants)  */
export const setEvaMultidimDisjunctiveInvariants: Server.SetRequest<
  boolean,
  null
  >= setEvaMultidimDisjunctiveInvariants_internal;

const evaMultidimDisjunctiveInvariants_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaMultidimDisjunctiveInvariants',
  signal: signalEvaMultidimDisjunctiveInvariants,
  getter: getEvaMultidimDisjunctiveInvariants,
  setter: setEvaMultidimDisjunctiveInvariants,
};
/** State of parameter -eva-multidim-disjunctive-invariants */
export const evaMultidimDisjunctiveInvariants: State.State<boolean> = evaMultidimDisjunctiveInvariants_internal;

/** Signal for state [`evaMultidimSegmentLimit`](#evamultidimsegmentlimit)  */
export const signalEvaMultidimSegmentLimit: Server.Signal = {
  name: 'kernel.parameters.signalEvaMultidimSegmentLimit',
};

const getEvaMultidimSegmentLimit_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaMultidimSegmentLimit',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaMultidimSegmentLimit`](#evamultidimsegmentlimit)  */
export const getEvaMultidimSegmentLimit: Server.GetRequest<null,number>= getEvaMultidimSegmentLimit_internal;

const setEvaMultidimSegmentLimit_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaMultidimSegmentLimit',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaMultidimSegmentLimit`](#evamultidimsegmentlimit)  */
export const setEvaMultidimSegmentLimit: Server.SetRequest<number,null>= setEvaMultidimSegmentLimit_internal;

const evaMultidimSegmentLimit_internal: State.State<number> = {
  name: 'kernel.parameters.evaMultidimSegmentLimit',
  signal: signalEvaMultidimSegmentLimit,
  getter: getEvaMultidimSegmentLimit,
  setter: setEvaMultidimSegmentLimit,
};
/** State of parameter -eva-multidim-segment-limit */
export const evaMultidimSegmentLimit: State.State<number> = evaMultidimSegmentLimit_internal;

/** Signal for state [`evaTracesProject`](#evatracesproject)  */
export const signalEvaTracesProject: Server.Signal = {
  name: 'kernel.parameters.signalEvaTracesProject',
};

const getEvaTracesProject_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaTracesProject',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaTracesProject`](#evatracesproject)  */
export const getEvaTracesProject: Server.GetRequest<null,boolean>= getEvaTracesProject_internal;

const setEvaTracesProject_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaTracesProject',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaTracesProject`](#evatracesproject)  */
export const setEvaTracesProject: Server.SetRequest<boolean,null>= setEvaTracesProject_internal;

const evaTracesProject_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaTracesProject',
  signal: signalEvaTracesProject,
  getter: getEvaTracesProject,
  setter: setEvaTracesProject,
};
/** State of parameter -eva-traces-project */
export const evaTracesProject: State.State<boolean> = evaTracesProject_internal;

/** Signal for state [`evaTracesDot`](#evatracesdot)  */
export const signalEvaTracesDot: Server.Signal = {
  name: 'kernel.parameters.signalEvaTracesDot',
};

const getEvaTracesDot_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaTracesDot',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaTracesDot`](#evatracesdot)  */
export const getEvaTracesDot: Server.GetRequest<null,string>= getEvaTracesDot_internal;

const setEvaTracesDot_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaTracesDot',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaTracesDot`](#evatracesdot)  */
export const setEvaTracesDot: Server.SetRequest<string,null>= setEvaTracesDot_internal;

const evaTracesDot_internal: State.State<string> = {
  name: 'kernel.parameters.evaTracesDot',
  signal: signalEvaTracesDot,
  getter: getEvaTracesDot,
  setter: setEvaTracesDot,
};
/** State of parameter -eva-traces-dot */
export const evaTracesDot: State.State<string> = evaTracesDot_internal;

/** Signal for state [`evaTracesUnifyLoop`](#evatracesunifyloop)  */
export const signalEvaTracesUnifyLoop: Server.Signal = {
  name: 'kernel.parameters.signalEvaTracesUnifyLoop',
};

const getEvaTracesUnifyLoop_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaTracesUnifyLoop',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaTracesUnifyLoop`](#evatracesunifyloop)  */
export const getEvaTracesUnifyLoop: Server.GetRequest<null,boolean>= getEvaTracesUnifyLoop_internal;

const setEvaTracesUnifyLoop_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaTracesUnifyLoop',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaTracesUnifyLoop`](#evatracesunifyloop)  */
export const setEvaTracesUnifyLoop: Server.SetRequest<boolean,null>= setEvaTracesUnifyLoop_internal;

const evaTracesUnifyLoop_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaTracesUnifyLoop',
  signal: signalEvaTracesUnifyLoop,
  getter: getEvaTracesUnifyLoop,
  setter: setEvaTracesUnifyLoop,
};
/** State of parameter -eva-traces-unify-loop */
export const evaTracesUnifyLoop: State.State<boolean> = evaTracesUnifyLoop_internal;

/** Signal for state [`evaTracesUnrollLoop`](#evatracesunrollloop)  */
export const signalEvaTracesUnrollLoop: Server.Signal = {
  name: 'kernel.parameters.signalEvaTracesUnrollLoop',
};

const getEvaTracesUnrollLoop_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaTracesUnrollLoop',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaTracesUnrollLoop`](#evatracesunrollloop)  */
export const getEvaTracesUnrollLoop: Server.GetRequest<null,boolean>= getEvaTracesUnrollLoop_internal;

const setEvaTracesUnrollLoop_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaTracesUnrollLoop',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaTracesUnrollLoop`](#evatracesunrollloop)  */
export const setEvaTracesUnrollLoop: Server.SetRequest<boolean,null>= setEvaTracesUnrollLoop_internal;

const evaTracesUnrollLoop_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaTracesUnrollLoop',
  signal: signalEvaTracesUnrollLoop,
  getter: getEvaTracesUnrollLoop,
  setter: setEvaTracesUnrollLoop,
};
/** State of parameter -eva-traces-unroll-loop */
export const evaTracesUnrollLoop: State.State<boolean> = evaTracesUnrollLoop_internal;

/** Signal for state [`evaNumerorsInteraction`](#evanumerorsinteraction)  */
export const signalEvaNumerorsInteraction: Server.Signal = {
  name: 'kernel.parameters.signalEvaNumerorsInteraction',
};

const getEvaNumerorsInteraction_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaNumerorsInteraction',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaNumerorsInteraction`](#evanumerorsinteraction)  */
export const getEvaNumerorsInteraction: Server.GetRequest<null,string>= getEvaNumerorsInteraction_internal;

const setEvaNumerorsInteraction_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaNumerorsInteraction',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaNumerorsInteraction`](#evanumerorsinteraction)  */
export const setEvaNumerorsInteraction: Server.SetRequest<string,null>= setEvaNumerorsInteraction_internal;

const evaNumerorsInteraction_internal: State.State<string> = {
  name: 'kernel.parameters.evaNumerorsInteraction',
  signal: signalEvaNumerorsInteraction,
  getter: getEvaNumerorsInteraction,
  setter: setEvaNumerorsInteraction,
};
/** State of parameter -eva-numerors-interaction */
export const evaNumerorsInteraction: State.State<string> = evaNumerorsInteraction_internal;

/** Signal for state [`evaNumerorsRealSize`](#evanumerorsrealsize)  */
export const signalEvaNumerorsRealSize: Server.Signal = {
  name: 'kernel.parameters.signalEvaNumerorsRealSize',
};

const getEvaNumerorsRealSize_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaNumerorsRealSize',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaNumerorsRealSize`](#evanumerorsrealsize)  */
export const getEvaNumerorsRealSize: Server.GetRequest<null,number>= getEvaNumerorsRealSize_internal;

const setEvaNumerorsRealSize_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaNumerorsRealSize',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaNumerorsRealSize`](#evanumerorsrealsize)  */
export const setEvaNumerorsRealSize: Server.SetRequest<number,null>= setEvaNumerorsRealSize_internal;

const evaNumerorsRealSize_internal: State.State<number> = {
  name: 'kernel.parameters.evaNumerorsRealSize',
  signal: signalEvaNumerorsRealSize,
  getter: getEvaNumerorsRealSize,
  setter: setEvaNumerorsRealSize,
};
/** State of parameter -eva-numerors-real-size */
export const evaNumerorsRealSize: State.State<number> = evaNumerorsRealSize_internal;

/** Signal for state [`evaOctagonThroughCalls`](#evaoctagonthroughcalls)  */
export const signalEvaOctagonThroughCalls: Server.Signal = {
  name: 'kernel.parameters.signalEvaOctagonThroughCalls',
};

const getEvaOctagonThroughCalls_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaOctagonThroughCalls',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaOctagonThroughCalls`](#evaoctagonthroughcalls)  */
export const getEvaOctagonThroughCalls: Server.GetRequest<null,boolean>= getEvaOctagonThroughCalls_internal;

const setEvaOctagonThroughCalls_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaOctagonThroughCalls',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaOctagonThroughCalls`](#evaoctagonthroughcalls)  */
export const setEvaOctagonThroughCalls: Server.SetRequest<boolean,null>= setEvaOctagonThroughCalls_internal;

const evaOctagonThroughCalls_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaOctagonThroughCalls',
  signal: signalEvaOctagonThroughCalls,
  getter: getEvaOctagonThroughCalls,
  setter: setEvaOctagonThroughCalls,
};
/** State of parameter -eva-octagon-through-calls */
export const evaOctagonThroughCalls: State.State<boolean> = evaOctagonThroughCalls_internal;

/** Signal for state
    [`evaEqualityThroughCallsFunction`](#evaequalitythroughcallsfunction)  */
export const signalEvaEqualityThroughCallsFunction: Server.Signal = {
  name: 'kernel.parameters.signalEvaEqualityThroughCallsFunction',
};

const getEvaEqualityThroughCallsFunction_internal: Server.GetRequest<
  null,
  string
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaEqualityThroughCallsFunction',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state
    [`evaEqualityThroughCallsFunction`](#evaequalitythroughcallsfunction)  */
export const getEvaEqualityThroughCallsFunction: Server.GetRequest<
  null,
  string
  >= getEvaEqualityThroughCallsFunction_internal;

const setEvaEqualityThroughCallsFunction_internal: Server.SetRequest<
  string,
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaEqualityThroughCallsFunction',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state
    [`evaEqualityThroughCallsFunction`](#evaequalitythroughcallsfunction)  */
export const setEvaEqualityThroughCallsFunction: Server.SetRequest<
  string,
  null
  >= setEvaEqualityThroughCallsFunction_internal;

const evaEqualityThroughCallsFunction_internal: State.State<string> = {
  name: 'kernel.parameters.evaEqualityThroughCallsFunction',
  signal: signalEvaEqualityThroughCallsFunction,
  getter: getEvaEqualityThroughCallsFunction,
  setter: setEvaEqualityThroughCallsFunction,
};
/** State of parameter -eva-equality-through-calls-function */
export const evaEqualityThroughCallsFunction: State.State<string> = evaEqualityThroughCallsFunction_internal;

/** Signal for state [`evaEqualityThroughCalls`](#evaequalitythroughcalls)  */
export const signalEvaEqualityThroughCalls: Server.Signal = {
  name: 'kernel.parameters.signalEvaEqualityThroughCalls',
};

const getEvaEqualityThroughCalls_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaEqualityThroughCalls',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaEqualityThroughCalls`](#evaequalitythroughcalls)  */
export const getEvaEqualityThroughCalls: Server.GetRequest<null,string>= getEvaEqualityThroughCalls_internal;

const setEvaEqualityThroughCalls_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaEqualityThroughCalls',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaEqualityThroughCalls`](#evaequalitythroughcalls)  */
export const setEvaEqualityThroughCalls: Server.SetRequest<string,null>= setEvaEqualityThroughCalls_internal;

const evaEqualityThroughCalls_internal: State.State<string> = {
  name: 'kernel.parameters.evaEqualityThroughCalls',
  signal: signalEvaEqualityThroughCalls,
  getter: getEvaEqualityThroughCalls,
  setter: setEvaEqualityThroughCalls,
};
/** State of parameter -eva-equality-through-calls */
export const evaEqualityThroughCalls: State.State<string> = evaEqualityThroughCalls_internal;

/** Signal for state [`evaDomainsFunction`](#evadomainsfunction)  */
export const signalEvaDomainsFunction: Server.Signal = {
  name: 'kernel.parameters.signalEvaDomainsFunction',
};

const getEvaDomainsFunction_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaDomainsFunction',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaDomainsFunction`](#evadomainsfunction)  */
export const getEvaDomainsFunction: Server.GetRequest<null,string>= getEvaDomainsFunction_internal;

const setEvaDomainsFunction_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaDomainsFunction',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaDomainsFunction`](#evadomainsfunction)  */
export const setEvaDomainsFunction: Server.SetRequest<string,null>= setEvaDomainsFunction_internal;

const evaDomainsFunction_internal: State.State<string> = {
  name: 'kernel.parameters.evaDomainsFunction',
  signal: signalEvaDomainsFunction,
  getter: getEvaDomainsFunction,
  setter: setEvaDomainsFunction,
};
/** State of parameter -eva-domains-function */
export const evaDomainsFunction: State.State<string> = evaDomainsFunction_internal;

/** Signal for state [`evaDomains`](#evadomains)  */
export const signalEvaDomains: Server.Signal = {
  name: 'kernel.parameters.signalEvaDomains',
};

const getEvaDomains_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaDomains',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`evaDomains`](#evadomains)  */
export const getEvaDomains: Server.GetRequest<null,string>= getEvaDomains_internal;

const setEvaDomains_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaDomains',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaDomains`](#evadomains)  */
export const setEvaDomains: Server.SetRequest<string,null>= setEvaDomains_internal;

const evaDomains_internal: State.State<string> = {
  name: 'kernel.parameters.evaDomains',
  signal: signalEvaDomains,
  getter: getEvaDomains,
  setter: setEvaDomains,
};
/** State of parameter -eva-domains */
export const evaDomains: State.State<string> = evaDomains_internal;

/** Signal for state [`evaStopAtNthAlarm`](#evastopatnthalarm)  */
export const signalEvaStopAtNthAlarm: Server.Signal = {
  name: 'kernel.parameters.signalEvaStopAtNthAlarm',
};

const getEvaStopAtNthAlarm_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaStopAtNthAlarm',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`evaStopAtNthAlarm`](#evastopatnthalarm)  */
export const getEvaStopAtNthAlarm: Server.GetRequest<null,number>= getEvaStopAtNthAlarm_internal;

const setEvaStopAtNthAlarm_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaStopAtNthAlarm',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaStopAtNthAlarm`](#evastopatnthalarm)  */
export const setEvaStopAtNthAlarm: Server.SetRequest<number,null>= setEvaStopAtNthAlarm_internal;

const evaStopAtNthAlarm_internal: State.State<number> = {
  name: 'kernel.parameters.evaStopAtNthAlarm',
  signal: signalEvaStopAtNthAlarm,
  getter: getEvaStopAtNthAlarm,
  setter: setEvaStopAtNthAlarm,
};
/** State of parameter -eva-stop-at-nth-alarm */
export const evaStopAtNthAlarm: State.State<number> = evaStopAtNthAlarm_internal;

/** Signal for state [`evaInterpreterMode`](#evainterpretermode)  */
export const signalEvaInterpreterMode: Server.Signal = {
  name: 'kernel.parameters.signalEvaInterpreterMode',
};

const getEvaInterpreterMode_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getEvaInterpreterMode',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`evaInterpreterMode`](#evainterpretermode)  */
export const getEvaInterpreterMode: Server.GetRequest<null,boolean>= getEvaInterpreterMode_internal;

const setEvaInterpreterMode_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setEvaInterpreterMode',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`evaInterpreterMode`](#evainterpretermode)  */
export const setEvaInterpreterMode: Server.SetRequest<boolean,null>= setEvaInterpreterMode_internal;

const evaInterpreterMode_internal: State.State<boolean> = {
  name: 'kernel.parameters.evaInterpreterMode',
  signal: signalEvaInterpreterMode,
  getter: getEvaInterpreterMode,
  setter: setEvaInterpreterMode,
};
/** State of parameter -eva-interpreter-mode */
export const evaInterpreterMode: State.State<boolean> = evaInterpreterMode_internal;

/** Signal for state [`wpCounterExamples`](#wpcounterexamples)  */
export const signalWpCounterExamples: Server.Signal = {
  name: 'kernel.parameters.signalWpCounterExamples',
};

const getWpCounterExamples_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpCounterExamples',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpCounterExamples`](#wpcounterexamples)  */
export const getWpCounterExamples: Server.GetRequest<null,boolean>= getWpCounterExamples_internal;

const setWpCounterExamples_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpCounterExamples',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpCounterExamples`](#wpcounterexamples)  */
export const setWpCounterExamples: Server.SetRequest<boolean,null>= setWpCounterExamples_internal;

const wpCounterExamples_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpCounterExamples',
  signal: signalWpCounterExamples,
  getter: getWpCounterExamples,
  setter: setWpCounterExamples,
};
/** State of parameter -wp-counter-examples */
export const wpCounterExamples: State.State<boolean> = wpCounterExamples_internal;

/** Signal for state [`wpProbes`](#wpprobes)  */
export const signalWpProbes: Server.Signal = {
  name: 'kernel.parameters.signalWpProbes',
};

const getWpProbes_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpProbes',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpProbes`](#wpprobes)  */
export const getWpProbes: Server.GetRequest<null,boolean>= getWpProbes_internal;

const setWpProbes_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpProbes',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpProbes`](#wpprobes)  */
export const setWpProbes: Server.SetRequest<boolean,null>= setWpProbes_internal;

const wpProbes_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpProbes',
  signal: signalWpProbes,
  getter: getWpProbes,
  setter: setWpProbes,
};
/** State of parameter -wp-probes */
export const wpProbes: State.State<boolean> = wpProbes_internal;

/** Signal for state [`wpTactic`](#wptactic)  */
export const signalWpTactic: Server.Signal = {
  name: 'kernel.parameters.signalWpTactic',
};

const getWpTactic_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpTactic',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpTactic`](#wptactic)  */
export const getWpTactic: Server.GetRequest<null,string>= getWpTactic_internal;

const setWpTactic_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpTactic',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpTactic`](#wptactic)  */
export const setWpTactic: Server.SetRequest<string,null>= setWpTactic_internal;

const wpTactic_internal: State.State<string> = {
  name: 'kernel.parameters.wpTactic',
  signal: signalWpTactic,
  getter: getWpTactic,
  setter: setWpTactic,
};
/** State of parameter -wp-tactic */
export const wpTactic: State.State<string> = wpTactic_internal;

/** Signal for state [`wpSession`](#wpsession)  */
export const signalWpSession: Server.Signal = {
  name: 'kernel.parameters.signalWpSession',
};

const getWpSession_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSession',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpSession`](#wpsession)  */
export const getWpSession: Server.GetRequest<null,string>= getWpSession_internal;

const setWpSession_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSession',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSession`](#wpsession)  */
export const setWpSession: Server.SetRequest<string,null>= setWpSession_internal;

const wpSession_internal: State.State<string> = {
  name: 'kernel.parameters.wpSession',
  signal: signalWpSession,
  getter: getWpSession,
  setter: setWpSession,
};
/** State of parameter -wp-session */
export const wpSession: State.State<string> = wpSession_internal;

/** Signal for state [`wpShare`](#wpshare)  */
export const signalWpShare: Server.Signal = {
  name: 'kernel.parameters.signalWpShare',
};

const getWpShare_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpShare',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpShare`](#wpshare)  */
export const getWpShare: Server.GetRequest<null,string>= getWpShare_internal;

const setWpShare_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpShare',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpShare`](#wpshare)  */
export const setWpShare: Server.SetRequest<string,null>= setWpShare_internal;

const wpShare_internal: State.State<string> = {
  name: 'kernel.parameters.wpShare',
  signal: signalWpShare,
  getter: getWpShare,
  setter: setWpShare,
};
/** State of parameter -wp-share */
export const wpShare: State.State<string> = wpShare_internal;

/** Signal for state [`wpOut`](#wpout)  */
export const signalWpOut: Server.Signal = {
  name: 'kernel.parameters.signalWpOut',
};

const getWpOut_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpOut',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpOut`](#wpout)  */
export const getWpOut: Server.GetRequest<null,string>= getWpOut_internal;

const setWpOut_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpOut',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpOut`](#wpout)  */
export const setWpOut: Server.SetRequest<string,null>= setWpOut_internal;

const wpOut_internal: State.State<string> = {
  name: 'kernel.parameters.wpOut',
  signal: signalWpOut,
  getter: getWpOut,
  setter: setWpOut,
};
/** State of parameter -wp-out */
export const wpOut: State.State<string> = wpOut_internal;

/** Signal for state [`wpCheckMemoryModel`](#wpcheckmemorymodel)  */
export const signalWpCheckMemoryModel: Server.Signal = {
  name: 'kernel.parameters.signalWpCheckMemoryModel',
};

const getWpCheckMemoryModel_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpCheckMemoryModel',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpCheckMemoryModel`](#wpcheckmemorymodel)  */
export const getWpCheckMemoryModel: Server.GetRequest<null,boolean>= getWpCheckMemoryModel_internal;

const setWpCheckMemoryModel_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpCheckMemoryModel',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpCheckMemoryModel`](#wpcheckmemorymodel)  */
export const setWpCheckMemoryModel: Server.SetRequest<boolean,null>= setWpCheckMemoryModel_internal;

const wpCheckMemoryModel_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpCheckMemoryModel',
  signal: signalWpCheckMemoryModel,
  getter: getWpCheckMemoryModel,
  setter: setWpCheckMemoryModel,
};
/** State of parameter -wp-check-memory-model */
export const wpCheckMemoryModel: State.State<boolean> = wpCheckMemoryModel_internal;

/** Signal for state [`wpWarnMemoryModel`](#wpwarnmemorymodel)  */
export const signalWpWarnMemoryModel: Server.Signal = {
  name: 'kernel.parameters.signalWpWarnMemoryModel',
};

const getWpWarnMemoryModel_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpWarnMemoryModel',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpWarnMemoryModel`](#wpwarnmemorymodel)  */
export const getWpWarnMemoryModel: Server.GetRequest<null,boolean>= getWpWarnMemoryModel_internal;

const setWpWarnMemoryModel_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpWarnMemoryModel',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpWarnMemoryModel`](#wpwarnmemorymodel)  */
export const setWpWarnMemoryModel: Server.SetRequest<boolean,null>= setWpWarnMemoryModel_internal;

const wpWarnMemoryModel_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpWarnMemoryModel',
  signal: signalWpWarnMemoryModel,
  getter: getWpWarnMemoryModel,
  setter: setWpWarnMemoryModel,
};
/** State of parameter -wp-warn-memory-model */
export const wpWarnMemoryModel: State.State<boolean> = wpWarnMemoryModel_internal;

/** Signal for state [`wpReportBasename`](#wpreportbasename)  */
export const signalWpReportBasename: Server.Signal = {
  name: 'kernel.parameters.signalWpReportBasename',
};

const getWpReportBasename_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpReportBasename',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpReportBasename`](#wpreportbasename)  */
export const getWpReportBasename: Server.GetRequest<null,string>= getWpReportBasename_internal;

const setWpReportBasename_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpReportBasename',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpReportBasename`](#wpreportbasename)  */
export const setWpReportBasename: Server.SetRequest<string,null>= setWpReportBasename_internal;

const wpReportBasename_internal: State.State<string> = {
  name: 'kernel.parameters.wpReportBasename',
  signal: signalWpReportBasename,
  getter: getWpReportBasename,
  setter: setWpReportBasename,
};
/** State of parameter -wp-report-basename */
export const wpReportBasename: State.State<string> = wpReportBasename_internal;

/** Signal for state [`wpDeprecatedReportJson`](#wpdeprecatedreportjson)  */
export const signalWpDeprecatedReportJson: Server.Signal = {
  name: 'kernel.parameters.signalWpDeprecatedReportJson',
};

const getWpDeprecatedReportJson_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpDeprecatedReportJson',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpDeprecatedReportJson`](#wpdeprecatedreportjson)  */
export const getWpDeprecatedReportJson: Server.GetRequest<null,string>= getWpDeprecatedReportJson_internal;

const setWpDeprecatedReportJson_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpDeprecatedReportJson',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpDeprecatedReportJson`](#wpdeprecatedreportjson)  */
export const setWpDeprecatedReportJson: Server.SetRequest<string,null>= setWpDeprecatedReportJson_internal;

const wpDeprecatedReportJson_internal: State.State<string> = {
  name: 'kernel.parameters.wpDeprecatedReportJson',
  signal: signalWpDeprecatedReportJson,
  getter: getWpDeprecatedReportJson,
  setter: setWpDeprecatedReportJson,
};
/** State of parameter -wp-deprecated-report-json */
export const wpDeprecatedReportJson: State.State<string> = wpDeprecatedReportJson_internal;

/** Signal for state [`wpReportJson`](#wpreportjson)  */
export const signalWpReportJson: Server.Signal = {
  name: 'kernel.parameters.signalWpReportJson',
};

const getWpReportJson_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpReportJson',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpReportJson`](#wpreportjson)  */
export const getWpReportJson: Server.GetRequest<null,string>= getWpReportJson_internal;

const setWpReportJson_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpReportJson',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpReportJson`](#wpreportjson)  */
export const setWpReportJson: Server.SetRequest<string,null>= setWpReportJson_internal;

const wpReportJson_internal: State.State<string> = {
  name: 'kernel.parameters.wpReportJson',
  signal: signalWpReportJson,
  getter: getWpReportJson,
  setter: setWpReportJson,
};
/** State of parameter -wp-report-json */
export const wpReportJson: State.State<string> = wpReportJson_internal;

/** Signal for state [`wpReport`](#wpreport)  */
export const signalWpReport: Server.Signal = {
  name: 'kernel.parameters.signalWpReport',
};

const getWpReport_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpReport',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpReport`](#wpreport)  */
export const getWpReport: Server.GetRequest<null,string>= getWpReport_internal;

const setWpReport_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpReport',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpReport`](#wpreport)  */
export const setWpReport: Server.SetRequest<string,null>= setWpReport_internal;

const wpReport_internal: State.State<string> = {
  name: 'kernel.parameters.wpReport',
  signal: signalWpReport,
  getter: getWpReport,
  setter: setWpReport,
};
/** State of parameter -wp-report */
export const wpReport: State.State<string> = wpReport_internal;

/** Signal for state [`wpStatus`](#wpstatus)  */
export const signalWpStatus: Server.Signal = {
  name: 'kernel.parameters.signalWpStatus',
};

const getWpStatus_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpStatus',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpStatus`](#wpstatus)  */
export const getWpStatus: Server.GetRequest<null,boolean>= getWpStatus_internal;

const setWpStatus_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpStatus',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpStatus`](#wpstatus)  */
export const setWpStatus: Server.SetRequest<boolean,null>= setWpStatus_internal;

const wpStatus_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpStatus',
  signal: signalWpStatus,
  getter: getWpStatus,
  setter: setWpStatus,
};
/** State of parameter -wp-status */
export const wpStatus: State.State<boolean> = wpStatus_internal;

/** Signal for state [`wpPrint`](#wpprint)  */
export const signalWpPrint: Server.Signal = {
  name: 'kernel.parameters.signalWpPrint',
};

const getWpPrint_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpPrint',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpPrint`](#wpprint)  */
export const getWpPrint: Server.GetRequest<null,boolean>= getWpPrint_internal;

const setWpPrint_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpPrint',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpPrint`](#wpprint)  */
export const setWpPrint: Server.SetRequest<boolean,null>= setWpPrint_internal;

const wpPrint_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpPrint',
  signal: signalWpPrint,
  getter: getWpPrint,
  setter: setWpPrint,
};
/** State of parameter -wp-print */
export const wpPrint: State.State<boolean> = wpPrint_internal;

/** Signal for state [`wpFilenameTruncation`](#wpfilenametruncation)  */
export const signalWpFilenameTruncation: Server.Signal = {
  name: 'kernel.parameters.signalWpFilenameTruncation',
};

const getWpFilenameTruncation_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpFilenameTruncation',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpFilenameTruncation`](#wpfilenametruncation)  */
export const getWpFilenameTruncation: Server.GetRequest<null,number>= getWpFilenameTruncation_internal;

const setWpFilenameTruncation_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpFilenameTruncation',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpFilenameTruncation`](#wpfilenametruncation)  */
export const setWpFilenameTruncation: Server.SetRequest<number,null>= setWpFilenameTruncation_internal;

const wpFilenameTruncation_internal: State.State<number> = {
  name: 'kernel.parameters.wpFilenameTruncation',
  signal: signalWpFilenameTruncation,
  getter: getWpFilenameTruncation,
  setter: setWpFilenameTruncation,
};
/** State of parameter -wp-filename-truncation */
export const wpFilenameTruncation: State.State<number> = wpFilenameTruncation_internal;

/** Signal for state [`wpVariantWithTerminates`](#wpvariantwithterminates)  */
export const signalWpVariantWithTerminates: Server.Signal = {
  name: 'kernel.parameters.signalWpVariantWithTerminates',
};

const getWpVariantWithTerminates_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpVariantWithTerminates',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpVariantWithTerminates`](#wpvariantwithterminates)  */
export const getWpVariantWithTerminates: Server.GetRequest<null,boolean>= getWpVariantWithTerminates_internal;

const setWpVariantWithTerminates_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpVariantWithTerminates',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpVariantWithTerminates`](#wpvariantwithterminates)  */
export const setWpVariantWithTerminates: Server.SetRequest<boolean,null>= setWpVariantWithTerminates_internal;

const wpVariantWithTerminates_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpVariantWithTerminates',
  signal: signalWpVariantWithTerminates,
  getter: getWpVariantWithTerminates,
  setter: setWpVariantWithTerminates,
};
/** State of parameter -wp-variant-with-terminates */
export const wpVariantWithTerminates: State.State<boolean> = wpVariantWithTerminates_internal;

/** Signal for state [`wpPrecondWeakening`](#wpprecondweakening)  */
export const signalWpPrecondWeakening: Server.Signal = {
  name: 'kernel.parameters.signalWpPrecondWeakening',
};

const getWpPrecondWeakening_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpPrecondWeakening',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpPrecondWeakening`](#wpprecondweakening)  */
export const getWpPrecondWeakening: Server.GetRequest<null,boolean>= getWpPrecondWeakening_internal;

const setWpPrecondWeakening_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpPrecondWeakening',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpPrecondWeakening`](#wpprecondweakening)  */
export const setWpPrecondWeakening: Server.SetRequest<boolean,null>= setWpPrecondWeakening_internal;

const wpPrecondWeakening_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpPrecondWeakening',
  signal: signalWpPrecondWeakening,
  getter: getWpPrecondWeakening,
  setter: setWpPrecondWeakening,
};
/** State of parameter -wp-precond-weakening */
export const wpPrecondWeakening: State.State<boolean> = wpPrecondWeakening_internal;

/** Signal for state [`wpUnfoldAssigns`](#wpunfoldassigns)  */
export const signalWpUnfoldAssigns: Server.Signal = {
  name: 'kernel.parameters.signalWpUnfoldAssigns',
};

const getWpUnfoldAssigns_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpUnfoldAssigns',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpUnfoldAssigns`](#wpunfoldassigns)  */
export const getWpUnfoldAssigns: Server.GetRequest<null,number>= getWpUnfoldAssigns_internal;

const setWpUnfoldAssigns_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpUnfoldAssigns',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpUnfoldAssigns`](#wpunfoldassigns)  */
export const setWpUnfoldAssigns: Server.SetRequest<number,null>= setWpUnfoldAssigns_internal;

const wpUnfoldAssigns_internal: State.State<number> = {
  name: 'kernel.parameters.wpUnfoldAssigns',
  signal: signalWpUnfoldAssigns,
  getter: getWpUnfoldAssigns,
  setter: setWpUnfoldAssigns,
};
/** State of parameter -wp-unfold-assigns */
export const wpUnfoldAssigns: State.State<number> = wpUnfoldAssigns_internal;

/** Signal for state [`wpMaxSplit`](#wpmaxsplit)  */
export const signalWpMaxSplit: Server.Signal = {
  name: 'kernel.parameters.signalWpMaxSplit',
};

const getWpMaxSplit_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpMaxSplit',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpMaxSplit`](#wpmaxsplit)  */
export const getWpMaxSplit: Server.GetRequest<null,number>= getWpMaxSplit_internal;

const setWpMaxSplit_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpMaxSplit',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpMaxSplit`](#wpmaxsplit)  */
export const setWpMaxSplit: Server.SetRequest<number,null>= setWpMaxSplit_internal;

const wpMaxSplit_internal: State.State<number> = {
  name: 'kernel.parameters.wpMaxSplit',
  signal: signalWpMaxSplit,
  getter: getWpMaxSplit,
  setter: setWpMaxSplit,
};
/** State of parameter -wp-max-split */
export const wpMaxSplit: State.State<number> = wpMaxSplit_internal;

/** Signal for state [`wpSplitCnf`](#wpsplitcnf)  */
export const signalWpSplitCnf: Server.Signal = {
  name: 'kernel.parameters.signalWpSplitCnf',
};

const getWpSplitCnf_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSplitCnf',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpSplitCnf`](#wpsplitcnf)  */
export const getWpSplitCnf: Server.GetRequest<null,number>= getWpSplitCnf_internal;

const setWpSplitCnf_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSplitCnf',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSplitCnf`](#wpsplitcnf)  */
export const setWpSplitCnf: Server.SetRequest<number,null>= setWpSplitCnf_internal;

const wpSplitCnf_internal: State.State<number> = {
  name: 'kernel.parameters.wpSplitCnf',
  signal: signalWpSplitCnf,
  getter: getWpSplitCnf,
  setter: setWpSplitCnf,
};
/** State of parameter -wp-split-cnf */
export const wpSplitCnf: State.State<number> = wpSplitCnf_internal;

/** Signal for state [`wpSplitConj`](#wpsplitconj)  */
export const signalWpSplitConj: Server.Signal = {
  name: 'kernel.parameters.signalWpSplitConj',
};

const getWpSplitConj_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSplitConj',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSplitConj`](#wpsplitconj)  */
export const getWpSplitConj: Server.GetRequest<null,boolean>= getWpSplitConj_internal;

const setWpSplitConj_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSplitConj',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSplitConj`](#wpsplitconj)  */
export const setWpSplitConj: Server.SetRequest<boolean,null>= setWpSplitConj_internal;

const wpSplitConj_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSplitConj',
  signal: signalWpSplitConj,
  getter: getWpSplitConj,
  setter: setWpSplitConj,
};
/** State of parameter -wp-split-conj */
export const wpSplitConj: State.State<boolean> = wpSplitConj_internal;

/** Signal for state [`wpSplitSwitch`](#wpsplitswitch)  */
export const signalWpSplitSwitch: Server.Signal = {
  name: 'kernel.parameters.signalWpSplitSwitch',
};

const getWpSplitSwitch_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSplitSwitch',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSplitSwitch`](#wpsplitswitch)  */
export const getWpSplitSwitch: Server.GetRequest<null,boolean>= getWpSplitSwitch_internal;

const setWpSplitSwitch_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSplitSwitch',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSplitSwitch`](#wpsplitswitch)  */
export const setWpSplitSwitch: Server.SetRequest<boolean,null>= setWpSplitSwitch_internal;

const wpSplitSwitch_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSplitSwitch',
  signal: signalWpSplitSwitch,
  getter: getWpSplitSwitch,
  setter: setWpSplitSwitch,
};
/** State of parameter -wp-split-switch */
export const wpSplitSwitch: State.State<boolean> = wpSplitSwitch_internal;

/** Signal for state [`wpSplit`](#wpsplit)  */
export const signalWpSplit: Server.Signal = {
  name: 'kernel.parameters.signalWpSplit',
};

const getWpSplit_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSplit',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSplit`](#wpsplit)  */
export const getWpSplit: Server.GetRequest<null,boolean>= getWpSplit_internal;

const setWpSplit_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSplit',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSplit`](#wpsplit)  */
export const setWpSplit: Server.SetRequest<boolean,null>= setWpSplit_internal;

const wpSplit_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSplit',
  signal: signalWpSplit,
  getter: getWpSplit,
  setter: setWpSplit,
};
/** State of parameter -wp-split */
export const wpSplit: State.State<boolean> = wpSplit_internal;

/** Signal for state [`wpSmokeDeadLoop`](#wpsmokedeadloop)  */
export const signalWpSmokeDeadLoop: Server.Signal = {
  name: 'kernel.parameters.signalWpSmokeDeadLoop',
};

const getWpSmokeDeadLoop_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSmokeDeadLoop',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSmokeDeadLoop`](#wpsmokedeadloop)  */
export const getWpSmokeDeadLoop: Server.GetRequest<null,boolean>= getWpSmokeDeadLoop_internal;

const setWpSmokeDeadLoop_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSmokeDeadLoop',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSmokeDeadLoop`](#wpsmokedeadloop)  */
export const setWpSmokeDeadLoop: Server.SetRequest<boolean,null>= setWpSmokeDeadLoop_internal;

const wpSmokeDeadLoop_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSmokeDeadLoop',
  signal: signalWpSmokeDeadLoop,
  getter: getWpSmokeDeadLoop,
  setter: setWpSmokeDeadLoop,
};
/** State of parameter -wp-smoke-dead-loop */
export const wpSmokeDeadLoop: State.State<boolean> = wpSmokeDeadLoop_internal;

/** Signal for state [`wpSmokeDeadLocalInit`](#wpsmokedeadlocalinit)  */
export const signalWpSmokeDeadLocalInit: Server.Signal = {
  name: 'kernel.parameters.signalWpSmokeDeadLocalInit',
};

const getWpSmokeDeadLocalInit_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSmokeDeadLocalInit',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSmokeDeadLocalInit`](#wpsmokedeadlocalinit)  */
export const getWpSmokeDeadLocalInit: Server.GetRequest<null,boolean>= getWpSmokeDeadLocalInit_internal;

const setWpSmokeDeadLocalInit_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSmokeDeadLocalInit',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSmokeDeadLocalInit`](#wpsmokedeadlocalinit)  */
export const setWpSmokeDeadLocalInit: Server.SetRequest<boolean,null>= setWpSmokeDeadLocalInit_internal;

const wpSmokeDeadLocalInit_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSmokeDeadLocalInit',
  signal: signalWpSmokeDeadLocalInit,
  getter: getWpSmokeDeadLocalInit,
  setter: setWpSmokeDeadLocalInit,
};
/** State of parameter -wp-smoke-dead-local-init */
export const wpSmokeDeadLocalInit: State.State<boolean> = wpSmokeDeadLocalInit_internal;

/** Signal for state [`wpSmokeDeadCall`](#wpsmokedeadcall)  */
export const signalWpSmokeDeadCall: Server.Signal = {
  name: 'kernel.parameters.signalWpSmokeDeadCall',
};

const getWpSmokeDeadCall_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSmokeDeadCall',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSmokeDeadCall`](#wpsmokedeadcall)  */
export const getWpSmokeDeadCall: Server.GetRequest<null,boolean>= getWpSmokeDeadCall_internal;

const setWpSmokeDeadCall_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSmokeDeadCall',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSmokeDeadCall`](#wpsmokedeadcall)  */
export const setWpSmokeDeadCall: Server.SetRequest<boolean,null>= setWpSmokeDeadCall_internal;

const wpSmokeDeadCall_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSmokeDeadCall',
  signal: signalWpSmokeDeadCall,
  getter: getWpSmokeDeadCall,
  setter: setWpSmokeDeadCall,
};
/** State of parameter -wp-smoke-dead-call */
export const wpSmokeDeadCall: State.State<boolean> = wpSmokeDeadCall_internal;

/** Signal for state [`wpSmokeDeadCode`](#wpsmokedeadcode)  */
export const signalWpSmokeDeadCode: Server.Signal = {
  name: 'kernel.parameters.signalWpSmokeDeadCode',
};

const getWpSmokeDeadCode_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSmokeDeadCode',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSmokeDeadCode`](#wpsmokedeadcode)  */
export const getWpSmokeDeadCode: Server.GetRequest<null,boolean>= getWpSmokeDeadCode_internal;

const setWpSmokeDeadCode_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSmokeDeadCode',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSmokeDeadCode`](#wpsmokedeadcode)  */
export const setWpSmokeDeadCode: Server.SetRequest<boolean,null>= setWpSmokeDeadCode_internal;

const wpSmokeDeadCode_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSmokeDeadCode',
  signal: signalWpSmokeDeadCode,
  getter: getWpSmokeDeadCode,
  setter: setWpSmokeDeadCode,
};
/** State of parameter -wp-smoke-dead-code */
export const wpSmokeDeadCode: State.State<boolean> = wpSmokeDeadCode_internal;

/** Signal for state [`wpSmokeDeadAssumes`](#wpsmokedeadassumes)  */
export const signalWpSmokeDeadAssumes: Server.Signal = {
  name: 'kernel.parameters.signalWpSmokeDeadAssumes',
};

const getWpSmokeDeadAssumes_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSmokeDeadAssumes',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSmokeDeadAssumes`](#wpsmokedeadassumes)  */
export const getWpSmokeDeadAssumes: Server.GetRequest<null,boolean>= getWpSmokeDeadAssumes_internal;

const setWpSmokeDeadAssumes_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSmokeDeadAssumes',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSmokeDeadAssumes`](#wpsmokedeadassumes)  */
export const setWpSmokeDeadAssumes: Server.SetRequest<boolean,null>= setWpSmokeDeadAssumes_internal;

const wpSmokeDeadAssumes_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSmokeDeadAssumes',
  signal: signalWpSmokeDeadAssumes,
  getter: getWpSmokeDeadAssumes,
  setter: setWpSmokeDeadAssumes,
};
/** State of parameter -wp-smoke-dead-assumes */
export const wpSmokeDeadAssumes: State.State<boolean> = wpSmokeDeadAssumes_internal;

/** Signal for state [`wpSmokeTests`](#wpsmoketests)  */
export const signalWpSmokeTests: Server.Signal = {
  name: 'kernel.parameters.signalWpSmokeTests',
};

const getWpSmokeTests_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSmokeTests',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSmokeTests`](#wpsmoketests)  */
export const getWpSmokeTests: Server.GetRequest<null,boolean>= getWpSmokeTests_internal;

const setWpSmokeTests_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSmokeTests',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSmokeTests`](#wpsmoketests)  */
export const setWpSmokeTests: Server.SetRequest<boolean,null>= setWpSmokeTests_internal;

const wpSmokeTests_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSmokeTests',
  signal: signalWpSmokeTests,
  getter: getWpSmokeTests,
  setter: setWpSmokeTests,
};
/** State of parameter -wp-smoke-tests */
export const wpSmokeTests: State.State<boolean> = wpSmokeTests_internal;

/** Signal for state [`wpRte`](#wprte)  */
export const signalWpRte: Server.Signal = {
  name: 'kernel.parameters.signalWpRte',
};

const getWpRte_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpRte',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpRte`](#wprte)  */
export const getWpRte: Server.GetRequest<null,boolean>= getWpRte_internal;

const setWpRte_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpRte',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpRte`](#wprte)  */
export const setWpRte: Server.SetRequest<boolean,null>= setWpRte_internal;

const wpRte_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpRte',
  signal: signalWpRte,
  getter: getWpRte,
  setter: setWpRte,
};
/** State of parameter -wp-rte */
export const wpRte: State.State<boolean> = wpRte_internal;

/** Signal for state [`wpCalleePrecond`](#wpcalleeprecond)  */
export const signalWpCalleePrecond: Server.Signal = {
  name: 'kernel.parameters.signalWpCalleePrecond',
};

const getWpCalleePrecond_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpCalleePrecond',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpCalleePrecond`](#wpcalleeprecond)  */
export const getWpCalleePrecond: Server.GetRequest<null,boolean>= getWpCalleePrecond_internal;

const setWpCalleePrecond_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpCalleePrecond',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpCalleePrecond`](#wpcalleeprecond)  */
export const setWpCalleePrecond: Server.SetRequest<boolean,null>= setWpCalleePrecond_internal;

const wpCalleePrecond_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpCalleePrecond',
  signal: signalWpCalleePrecond,
  getter: getWpCalleePrecond,
  setter: setWpCalleePrecond,
};
/** State of parameter -wp-callee-precond */
export const wpCalleePrecond: State.State<boolean> = wpCalleePrecond_internal;

/** Signal for state [`wpInitConst`](#wpinitconst)  */
export const signalWpInitConst: Server.Signal = {
  name: 'kernel.parameters.signalWpInitConst',
};

const getWpInitConst_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpInitConst',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpInitConst`](#wpinitconst)  */
export const getWpInitConst: Server.GetRequest<null,boolean>= getWpInitConst_internal;

const setWpInitConst_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpInitConst',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpInitConst`](#wpinitconst)  */
export const setWpInitConst: Server.SetRequest<boolean,null>= setWpInitConst_internal;

const wpInitConst_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpInitConst',
  signal: signalWpInitConst,
  getter: getWpInitConst,
  setter: setWpInitConst,
};
/** State of parameter -wp-init-const */
export const wpInitConst: State.State<boolean> = wpInitConst_internal;

/** Signal for state [`wpBoundForallUnfolding`](#wpboundforallunfolding)  */
export const signalWpBoundForallUnfolding: Server.Signal = {
  name: 'kernel.parameters.signalWpBoundForallUnfolding',
};

const getWpBoundForallUnfolding_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpBoundForallUnfolding',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpBoundForallUnfolding`](#wpboundforallunfolding)  */
export const getWpBoundForallUnfolding: Server.GetRequest<null,number>= getWpBoundForallUnfolding_internal;

const setWpBoundForallUnfolding_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpBoundForallUnfolding',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpBoundForallUnfolding`](#wpboundforallunfolding)  */
export const setWpBoundForallUnfolding: Server.SetRequest<number,null>= setWpBoundForallUnfolding_internal;

const wpBoundForallUnfolding_internal: State.State<number> = {
  name: 'kernel.parameters.wpBoundForallUnfolding',
  signal: signalWpBoundForallUnfolding,
  getter: getWpBoundForallUnfolding,
  setter: setWpBoundForallUnfolding,
};
/** State of parameter -wp-bound-forall-unfolding */
export const wpBoundForallUnfolding: State.State<number> = wpBoundForallUnfolding_internal;

/** Signal for state [`wpInitSummarizeArray`](#wpinitsummarizearray)  */
export const signalWpInitSummarizeArray: Server.Signal = {
  name: 'kernel.parameters.signalWpInitSummarizeArray',
};

const getWpInitSummarizeArray_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpInitSummarizeArray',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpInitSummarizeArray`](#wpinitsummarizearray)  */
export const getWpInitSummarizeArray: Server.GetRequest<null,boolean>= getWpInitSummarizeArray_internal;

const setWpInitSummarizeArray_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpInitSummarizeArray',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpInitSummarizeArray`](#wpinitsummarizearray)  */
export const setWpInitSummarizeArray: Server.SetRequest<boolean,null>= setWpInitSummarizeArray_internal;

const wpInitSummarizeArray_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpInitSummarizeArray',
  signal: signalWpInitSummarizeArray,
  getter: getWpInitSummarizeArray,
  setter: setWpInitSummarizeArray,
};
/** State of parameter -wp-init-summarize-array */
export const wpInitSummarizeArray: State.State<boolean> = wpInitSummarizeArray_internal;

/** Signal for state [`wpSimplifyType`](#wpsimplifytype)  */
export const signalWpSimplifyType: Server.Signal = {
  name: 'kernel.parameters.signalWpSimplifyType',
};

const getWpSimplifyType_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSimplifyType',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSimplifyType`](#wpsimplifytype)  */
export const getWpSimplifyType: Server.GetRequest<null,boolean>= getWpSimplifyType_internal;

const setWpSimplifyType_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSimplifyType',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSimplifyType`](#wpsimplifytype)  */
export const setWpSimplifyType: Server.SetRequest<boolean,null>= setWpSimplifyType_internal;

const wpSimplifyType_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSimplifyType',
  signal: signalWpSimplifyType,
  getter: getWpSimplifyType,
  setter: setWpSimplifyType,
};
/** State of parameter -wp-simplify-type */
export const wpSimplifyType: State.State<boolean> = wpSimplifyType_internal;

/** Signal for state [`wpSimplifyForall`](#wpsimplifyforall)  */
export const signalWpSimplifyForall: Server.Signal = {
  name: 'kernel.parameters.signalWpSimplifyForall',
};

const getWpSimplifyForall_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSimplifyForall',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSimplifyForall`](#wpsimplifyforall)  */
export const getWpSimplifyForall: Server.GetRequest<null,boolean>= getWpSimplifyForall_internal;

const setWpSimplifyForall_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSimplifyForall',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSimplifyForall`](#wpsimplifyforall)  */
export const setWpSimplifyForall: Server.SetRequest<boolean,null>= setWpSimplifyForall_internal;

const wpSimplifyForall_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSimplifyForall',
  signal: signalWpSimplifyForall,
  getter: getWpSimplifyForall,
  setter: setWpSimplifyForall,
};
/** State of parameter -wp-simplify-forall */
export const wpSimplifyForall: State.State<boolean> = wpSimplifyForall_internal;

/** Signal for state [`wpSimplifyLandMask`](#wpsimplifylandmask)  */
export const signalWpSimplifyLandMask: Server.Signal = {
  name: 'kernel.parameters.signalWpSimplifyLandMask',
};

const getWpSimplifyLandMask_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSimplifyLandMask',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSimplifyLandMask`](#wpsimplifylandmask)  */
export const getWpSimplifyLandMask: Server.GetRequest<null,boolean>= getWpSimplifyLandMask_internal;

const setWpSimplifyLandMask_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSimplifyLandMask',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSimplifyLandMask`](#wpsimplifylandmask)  */
export const setWpSimplifyLandMask: Server.SetRequest<boolean,null>= setWpSimplifyLandMask_internal;

const wpSimplifyLandMask_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSimplifyLandMask',
  signal: signalWpSimplifyLandMask,
  getter: getWpSimplifyLandMask,
  setter: setWpSimplifyLandMask,
};
/** State of parameter -wp-simplify-land-mask */
export const wpSimplifyLandMask: State.State<boolean> = wpSimplifyLandMask_internal;

/** Signal for state [`wpSimplifyIsCint`](#wpsimplifyiscint)  */
export const signalWpSimplifyIsCint: Server.Signal = {
  name: 'kernel.parameters.signalWpSimplifyIsCint',
};

const getWpSimplifyIsCint_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSimplifyIsCint',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSimplifyIsCint`](#wpsimplifyiscint)  */
export const getWpSimplifyIsCint: Server.GetRequest<null,boolean>= getWpSimplifyIsCint_internal;

const setWpSimplifyIsCint_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSimplifyIsCint',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSimplifyIsCint`](#wpsimplifyiscint)  */
export const setWpSimplifyIsCint: Server.SetRequest<boolean,null>= setWpSimplifyIsCint_internal;

const wpSimplifyIsCint_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSimplifyIsCint',
  signal: signalWpSimplifyIsCint,
  getter: getWpSimplifyIsCint,
  setter: setWpSimplifyIsCint,
};
/** State of parameter -wp-simplify-is-cint */
export const wpSimplifyIsCint: State.State<boolean> = wpSimplifyIsCint_internal;

/** Signal for state [`wpPrenex`](#wpprenex)  */
export const signalWpPrenex: Server.Signal = {
  name: 'kernel.parameters.signalWpPrenex',
};

const getWpPrenex_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpPrenex',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpPrenex`](#wpprenex)  */
export const getWpPrenex: Server.GetRequest<null,boolean>= getWpPrenex_internal;

const setWpPrenex_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpPrenex',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpPrenex`](#wpprenex)  */
export const setWpPrenex: Server.SetRequest<boolean,null>= setWpPrenex_internal;

const wpPrenex_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpPrenex',
  signal: signalWpPrenex,
  getter: getWpPrenex,
  setter: setWpPrenex,
};
/** State of parameter -wp-prenex */
export const wpPrenex: State.State<boolean> = wpPrenex_internal;

/** Signal for state [`wpParasite`](#wpparasite)  */
export const signalWpParasite: Server.Signal = {
  name: 'kernel.parameters.signalWpParasite',
};

const getWpParasite_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpParasite',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpParasite`](#wpparasite)  */
export const getWpParasite: Server.GetRequest<null,boolean>= getWpParasite_internal;

const setWpParasite_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpParasite',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpParasite`](#wpparasite)  */
export const setWpParasite: Server.SetRequest<boolean,null>= setWpParasite_internal;

const wpParasite_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpParasite',
  signal: signalWpParasite,
  getter: getWpParasite,
  setter: setWpParasite,
};
/** State of parameter -wp-parasite */
export const wpParasite: State.State<boolean> = wpParasite_internal;

/** Signal for state [`wpFilter`](#wpfilter)  */
export const signalWpFilter: Server.Signal = {
  name: 'kernel.parameters.signalWpFilter',
};

const getWpFilter_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpFilter',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpFilter`](#wpfilter)  */
export const getWpFilter: Server.GetRequest<null,boolean>= getWpFilter_internal;

const setWpFilter_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpFilter',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpFilter`](#wpfilter)  */
export const setWpFilter: Server.SetRequest<boolean,null>= setWpFilter_internal;

const wpFilter_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpFilter',
  signal: signalWpFilter,
  getter: getWpFilter,
  setter: setWpFilter,
};
/** State of parameter -wp-filter */
export const wpFilter: State.State<boolean> = wpFilter_internal;

/** Signal for state [`wpExtensional`](#wpextensional)  */
export const signalWpExtensional: Server.Signal = {
  name: 'kernel.parameters.signalWpExtensional',
};

const getWpExtensional_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpExtensional',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpExtensional`](#wpextensional)  */
export const getWpExtensional: Server.GetRequest<null,boolean>= getWpExtensional_internal;

const setWpExtensional_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpExtensional',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpExtensional`](#wpextensional)  */
export const setWpExtensional: Server.SetRequest<boolean,null>= setWpExtensional_internal;

const wpExtensional_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpExtensional',
  signal: signalWpExtensional,
  getter: getWpExtensional,
  setter: setWpExtensional,
};
/** State of parameter -wp-extensional */
export const wpExtensional: State.State<boolean> = wpExtensional_internal;

/** Signal for state [`wpReduce`](#wpreduce)  */
export const signalWpReduce: Server.Signal = {
  name: 'kernel.parameters.signalWpReduce',
};

const getWpReduce_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpReduce',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpReduce`](#wpreduce)  */
export const getWpReduce: Server.GetRequest<null,boolean>= getWpReduce_internal;

const setWpReduce_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpReduce',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpReduce`](#wpreduce)  */
export const setWpReduce: Server.SetRequest<boolean,null>= setWpReduce_internal;

const wpReduce_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpReduce',
  signal: signalWpReduce,
  getter: getWpReduce,
  setter: setWpReduce,
};
/** State of parameter -wp-reduce */
export const wpReduce: State.State<boolean> = wpReduce_internal;

/** Signal for state [`wpGround`](#wpground)  */
export const signalWpGround: Server.Signal = {
  name: 'kernel.parameters.signalWpGround',
};

const getWpGround_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpGround',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpGround`](#wpground)  */
export const getWpGround: Server.GetRequest<null,boolean>= getWpGround_internal;

const setWpGround_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpGround',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpGround`](#wpground)  */
export const setWpGround: Server.SetRequest<boolean,null>= setWpGround_internal;

const wpGround_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpGround',
  signal: signalWpGround,
  getter: getWpGround,
  setter: setWpGround,
};
/** State of parameter -wp-ground */
export const wpGround: State.State<boolean> = wpGround_internal;

/** Signal for state [`wpClean`](#wpclean)  */
export const signalWpClean: Server.Signal = {
  name: 'kernel.parameters.signalWpClean',
};

const getWpClean_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpClean',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpClean`](#wpclean)  */
export const getWpClean: Server.GetRequest<null,boolean>= getWpClean_internal;

const setWpClean_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpClean',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpClean`](#wpclean)  */
export const setWpClean: Server.SetRequest<boolean,null>= setWpClean_internal;

const wpClean_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpClean',
  signal: signalWpClean,
  getter: getWpClean,
  setter: setWpClean,
};
/** State of parameter -wp-clean */
export const wpClean: State.State<boolean> = wpClean_internal;

/** Signal for state [`wpFilterInit`](#wpfilterinit)  */
export const signalWpFilterInit: Server.Signal = {
  name: 'kernel.parameters.signalWpFilterInit',
};

const getWpFilterInit_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpFilterInit',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpFilterInit`](#wpfilterinit)  */
export const getWpFilterInit: Server.GetRequest<null,boolean>= getWpFilterInit_internal;

const setWpFilterInit_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpFilterInit',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpFilterInit`](#wpfilterinit)  */
export const setWpFilterInit: Server.SetRequest<boolean,null>= setWpFilterInit_internal;

const wpFilterInit_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpFilterInit',
  signal: signalWpFilterInit,
  getter: getWpFilterInit,
  setter: setWpFilterInit,
};
/** State of parameter -wp-filter-init */
export const wpFilterInit: State.State<boolean> = wpFilterInit_internal;

/** Signal for state [`wpPruning`](#wppruning)  */
export const signalWpPruning: Server.Signal = {
  name: 'kernel.parameters.signalWpPruning',
};

const getWpPruning_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpPruning',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpPruning`](#wppruning)  */
export const getWpPruning: Server.GetRequest<null,boolean>= getWpPruning_internal;

const setWpPruning_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpPruning',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpPruning`](#wppruning)  */
export const setWpPruning: Server.SetRequest<boolean,null>= setWpPruning_internal;

const wpPruning_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpPruning',
  signal: signalWpPruning,
  getter: getWpPruning,
  setter: setWpPruning,
};
/** State of parameter -wp-pruning */
export const wpPruning: State.State<boolean> = wpPruning_internal;

/** Signal for state [`wpCore`](#wpcore)  */
export const signalWpCore: Server.Signal = {
  name: 'kernel.parameters.signalWpCore',
};

const getWpCore_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpCore',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpCore`](#wpcore)  */
export const getWpCore: Server.GetRequest<null,boolean>= getWpCore_internal;

const setWpCore_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpCore',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpCore`](#wpcore)  */
export const setWpCore: Server.SetRequest<boolean,null>= setWpCore_internal;

const wpCore_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpCore',
  signal: signalWpCore,
  getter: getWpCore,
  setter: setWpCore,
};
/** State of parameter -wp-core */
export const wpCore: State.State<boolean> = wpCore_internal;

/** Signal for state [`wpLet`](#wplet)  */
export const signalWpLet: Server.Signal = {
  name: 'kernel.parameters.signalWpLet',
};

const getWpLet_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpLet',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpLet`](#wplet)  */
export const getWpLet: Server.GetRequest<null,boolean>= getWpLet_internal;

const setWpLet_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpLet',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpLet`](#wplet)  */
export const setWpLet: Server.SetRequest<boolean,null>= setWpLet_internal;

const wpLet_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpLet',
  signal: signalWpLet,
  getter: getWpLet,
  setter: setWpLet,
};
/** State of parameter -wp-let */
export const wpLet: State.State<boolean> = wpLet_internal;

/** Signal for state [`wpSimpl`](#wpsimpl)  */
export const signalWpSimpl: Server.Signal = {
  name: 'kernel.parameters.signalWpSimpl',
};

const getWpSimpl_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSimpl',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpSimpl`](#wpsimpl)  */
export const getWpSimpl: Server.GetRequest<null,boolean>= getWpSimpl_internal;

const setWpSimpl_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSimpl',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSimpl`](#wpsimpl)  */
export const setWpSimpl: Server.SetRequest<boolean,null>= setWpSimpl_internal;

const wpSimpl_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpSimpl',
  signal: signalWpSimpl,
  getter: getWpSimpl,
  setter: setWpSimpl,
};
/** State of parameter -wp-simpl */
export const wpSimpl: State.State<boolean> = wpSimpl_internal;

/** Signal for state [`wpWarnKey`](#wpwarnkey)  */
export const signalWpWarnKey: Server.Signal = {
  name: 'kernel.parameters.signalWpWarnKey',
};

const getWpWarnKey_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpWarnKey',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpWarnKey`](#wpwarnkey)  */
export const getWpWarnKey: Server.GetRequest<null,string>= getWpWarnKey_internal;

const setWpWarnKey_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpWarnKey',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpWarnKey`](#wpwarnkey)  */
export const setWpWarnKey: Server.SetRequest<string,null>= setWpWarnKey_internal;

const wpWarnKey_internal: State.State<string> = {
  name: 'kernel.parameters.wpWarnKey',
  signal: signalWpWarnKey,
  getter: getWpWarnKey,
  setter: setWpWarnKey,
};
/** State of parameter -wp-warn-key */
export const wpWarnKey: State.State<string> = wpWarnKey_internal;

/** Signal for state [`wpMsgKey`](#wpmsgkey)  */
export const signalWpMsgKey: Server.Signal = {
  name: 'kernel.parameters.signalWpMsgKey',
};

const getWpMsgKey_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpMsgKey',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpMsgKey`](#wpmsgkey)  */
export const getWpMsgKey: Server.GetRequest<null,string>= getWpMsgKey_internal;

const setWpMsgKey_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpMsgKey',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpMsgKey`](#wpmsgkey)  */
export const setWpMsgKey: Server.SetRequest<string,null>= setWpMsgKey_internal;

const wpMsgKey_internal: State.State<string> = {
  name: 'kernel.parameters.wpMsgKey',
  signal: signalWpMsgKey,
  getter: getWpMsgKey,
  setter: setWpMsgKey,
};
/** State of parameter -wp-msg-key */
export const wpMsgKey: State.State<string> = wpMsgKey_internal;

/** Signal for state [`wpDebug`](#wpdebug)  */
export const signalWpDebug: Server.Signal = {
  name: 'kernel.parameters.signalWpDebug',
};

const getWpDebug_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpDebug',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpDebug`](#wpdebug)  */
export const getWpDebug: Server.GetRequest<null,number>= getWpDebug_internal;

const setWpDebug_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpDebug',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpDebug`](#wpdebug)  */
export const setWpDebug: Server.SetRequest<number,null>= setWpDebug_internal;

const wpDebug_internal: State.State<number> = {
  name: 'kernel.parameters.wpDebug',
  signal: signalWpDebug,
  getter: getWpDebug,
  setter: setWpDebug,
};
/** State of parameter -wp-debug */
export const wpDebug: State.State<number> = wpDebug_internal;

/** Signal for state [`wpVerbose`](#wpverbose)  */
export const signalWpVerbose: Server.Signal = {
  name: 'kernel.parameters.signalWpVerbose',
};

const getWpVerbose_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpVerbose',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpVerbose`](#wpverbose)  */
export const getWpVerbose: Server.GetRequest<null,number>= getWpVerbose_internal;

const setWpVerbose_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpVerbose',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpVerbose`](#wpverbose)  */
export const setWpVerbose: Server.SetRequest<number,null>= setWpVerbose_internal;

const wpVerbose_internal: State.State<number> = {
  name: 'kernel.parameters.wpVerbose',
  signal: signalWpVerbose,
  getter: getWpVerbose,
  setter: setWpVerbose,
};
/** State of parameter -wp-verbose */
export const wpVerbose: State.State<number> = wpVerbose_internal;

/** Signal for state [`wpLog`](#wplog)  */
export const signalWpLog: Server.Signal = {
  name: 'kernel.parameters.signalWpLog',
};

const getWpLog_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpLog',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpLog`](#wplog)  */
export const getWpLog: Server.GetRequest<null,string>= getWpLog_internal;

const setWpLog_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpLog',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpLog`](#wplog)  */
export const setWpLog: Server.SetRequest<string,null>= setWpLog_internal;

const wpLog_internal: State.State<string> = {
  name: 'kernel.parameters.wpLog',
  signal: signalWpLog,
  getter: getWpLog,
  setter: setWpLog,
};
/** State of parameter -wp-log */
export const wpLog: State.State<string> = wpLog_internal;

/** Signal for state [`wpVolatile`](#wpvolatile)  */
export const signalWpVolatile: Server.Signal = {
  name: 'kernel.parameters.signalWpVolatile',
};

const getWpVolatile_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpVolatile',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpVolatile`](#wpvolatile)  */
export const getWpVolatile: Server.GetRequest<null,boolean>= getWpVolatile_internal;

const setWpVolatile_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpVolatile',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpVolatile`](#wpvolatile)  */
export const setWpVolatile: Server.SetRequest<boolean,null>= setWpVolatile_internal;

const wpVolatile_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpVolatile',
  signal: signalWpVolatile,
  getter: getWpVolatile,
  setter: setWpVolatile,
};
/** State of parameter -wp-volatile */
export const wpVolatile: State.State<boolean> = wpVolatile_internal;

/** Signal for state [`wpLiterals`](#wpliterals)  */
export const signalWpLiterals: Server.Signal = {
  name: 'kernel.parameters.signalWpLiterals',
};

const getWpLiterals_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpLiterals',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpLiterals`](#wpliterals)  */
export const getWpLiterals: Server.GetRequest<null,boolean>= getWpLiterals_internal;

const setWpLiterals_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpLiterals',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpLiterals`](#wpliterals)  */
export const setWpLiterals: Server.SetRequest<boolean,null>= setWpLiterals_internal;

const wpLiterals_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpLiterals',
  signal: signalWpLiterals,
  getter: getWpLiterals,
  setter: setWpLiterals,
};
/** State of parameter -wp-literals */
export const wpLiterals: State.State<boolean> = wpLiterals_internal;

/** Signal for state [`wpWeakIntModel`](#wpweakintmodel)  */
export const signalWpWeakIntModel: Server.Signal = {
  name: 'kernel.parameters.signalWpWeakIntModel',
};

const getWpWeakIntModel_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpWeakIntModel',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpWeakIntModel`](#wpweakintmodel)  */
export const getWpWeakIntModel: Server.GetRequest<null,boolean>= getWpWeakIntModel_internal;

const setWpWeakIntModel_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpWeakIntModel',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpWeakIntModel`](#wpweakintmodel)  */
export const setWpWeakIntModel: Server.SetRequest<boolean,null>= setWpWeakIntModel_internal;

const wpWeakIntModel_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpWeakIntModel',
  signal: signalWpWeakIntModel,
  getter: getWpWeakIntModel,
  setter: setWpWeakIntModel,
};
/** State of parameter -wp-weak-int-model */
export const wpWeakIntModel: State.State<boolean> = wpWeakIntModel_internal;

/** Signal for state [`wpExternArrays`](#wpexternarrays)  */
export const signalWpExternArrays: Server.Signal = {
  name: 'kernel.parameters.signalWpExternArrays',
};

const getWpExternArrays_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpExternArrays',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpExternArrays`](#wpexternarrays)  */
export const getWpExternArrays: Server.GetRequest<null,boolean>= getWpExternArrays_internal;

const setWpExternArrays_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpExternArrays',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpExternArrays`](#wpexternarrays)  */
export const setWpExternArrays: Server.SetRequest<boolean,null>= setWpExternArrays_internal;

const wpExternArrays_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpExternArrays',
  signal: signalWpExternArrays,
  getter: getWpExternArrays,
  setter: setWpExternArrays,
};
/** State of parameter -wp-extern-arrays */
export const wpExternArrays: State.State<boolean> = wpExternArrays_internal;

/** Signal for state [`wpContextVars`](#wpcontextvars)  */
export const signalWpContextVars: Server.Signal = {
  name: 'kernel.parameters.signalWpContextVars',
};

const getWpContextVars_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpContextVars',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpContextVars`](#wpcontextvars)  */
export const getWpContextVars: Server.GetRequest<null,string>= getWpContextVars_internal;

const setWpContextVars_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpContextVars',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpContextVars`](#wpcontextvars)  */
export const setWpContextVars: Server.SetRequest<string,null>= setWpContextVars_internal;

const wpContextVars_internal: State.State<string> = {
  name: 'kernel.parameters.wpContextVars',
  signal: signalWpContextVars,
  getter: getWpContextVars,
  setter: setWpContextVars,
};
/** State of parameter -wp-context-vars */
export const wpContextVars: State.State<string> = wpContextVars_internal;

/** Signal for state [`wpAliasInit`](#wpaliasinit)  */
export const signalWpAliasInit: Server.Signal = {
  name: 'kernel.parameters.signalWpAliasInit',
};

const getWpAliasInit_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpAliasInit',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpAliasInit`](#wpaliasinit)  */
export const getWpAliasInit: Server.GetRequest<null,boolean>= getWpAliasInit_internal;

const setWpAliasInit_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpAliasInit',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpAliasInit`](#wpaliasinit)  */
export const setWpAliasInit: Server.SetRequest<boolean,null>= setWpAliasInit_internal;

const wpAliasInit_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpAliasInit',
  signal: signalWpAliasInit,
  getter: getWpAliasInit,
  setter: setWpAliasInit,
};
/** State of parameter -wp-alias-init */
export const wpAliasInit: State.State<boolean> = wpAliasInit_internal;

/** Signal for state [`wpAliasVars`](#wpaliasvars)  */
export const signalWpAliasVars: Server.Signal = {
  name: 'kernel.parameters.signalWpAliasVars',
};

const getWpAliasVars_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpAliasVars',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpAliasVars`](#wpaliasvars)  */
export const getWpAliasVars: Server.GetRequest<null,string>= getWpAliasVars_internal;

const setWpAliasVars_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpAliasVars',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpAliasVars`](#wpaliasvars)  */
export const setWpAliasVars: Server.SetRequest<string,null>= setWpAliasVars_internal;

const wpAliasVars_internal: State.State<string> = {
  name: 'kernel.parameters.wpAliasVars',
  signal: signalWpAliasVars,
  getter: getWpAliasVars,
  setter: setWpAliasVars,
};
/** State of parameter -wp-alias-vars */
export const wpAliasVars: State.State<string> = wpAliasVars_internal;

/** Signal for state [`wpRefVars`](#wprefvars)  */
export const signalWpRefVars: Server.Signal = {
  name: 'kernel.parameters.signalWpRefVars',
};

const getWpRefVars_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpRefVars',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpRefVars`](#wprefvars)  */
export const getWpRefVars: Server.GetRequest<null,string>= getWpRefVars_internal;

const setWpRefVars_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpRefVars',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpRefVars`](#wprefvars)  */
export const setWpRefVars: Server.SetRequest<string,null>= setWpRefVars_internal;

const wpRefVars_internal: State.State<string> = {
  name: 'kernel.parameters.wpRefVars',
  signal: signalWpRefVars,
  getter: getWpRefVars,
  setter: setWpRefVars,
};
/** State of parameter -wp-ref-vars */
export const wpRefVars: State.State<string> = wpRefVars_internal;

/** Signal for state [`wpUnaliasVars`](#wpunaliasvars)  */
export const signalWpUnaliasVars: Server.Signal = {
  name: 'kernel.parameters.signalWpUnaliasVars',
};

const getWpUnaliasVars_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpUnaliasVars',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpUnaliasVars`](#wpunaliasvars)  */
export const getWpUnaliasVars: Server.GetRequest<null,string>= getWpUnaliasVars_internal;

const setWpUnaliasVars_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpUnaliasVars',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpUnaliasVars`](#wpunaliasvars)  */
export const setWpUnaliasVars: Server.SetRequest<string,null>= setWpUnaliasVars_internal;

const wpUnaliasVars_internal: State.State<string> = {
  name: 'kernel.parameters.wpUnaliasVars',
  signal: signalWpUnaliasVars,
  getter: getWpUnaliasVars,
  setter: setWpUnaliasVars,
};
/** State of parameter -wp-unalias-vars */
export const wpUnaliasVars: State.State<string> = wpUnaliasVars_internal;

/** Signal for state [`wpModel`](#wpmodel)  */
export const signalWpModel: Server.Signal = {
  name: 'kernel.parameters.signalWpModel',
};

const getWpModel_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpModel',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpModel`](#wpmodel)  */
export const getWpModel: Server.GetRequest<null,string>= getWpModel_internal;

const setWpModel_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpModel',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpModel`](#wpmodel)  */
export const setWpModel: Server.SetRequest<string,null>= setWpModel_internal;

const wpModel_internal: State.State<string> = {
  name: 'kernel.parameters.wpModel',
  signal: signalWpModel,
  getter: getWpModel,
  setter: setWpModel,
};
/** State of parameter -wp-model */
export const wpModel: State.State<string> = wpModel_internal;

/** Signal for state [`wpWhy3ExtraConfig`](#wpwhy3extraconfig)  */
export const signalWpWhy3ExtraConfig: Server.Signal = {
  name: 'kernel.parameters.signalWpWhy3ExtraConfig',
};

const getWpWhy3ExtraConfig_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpWhy3ExtraConfig',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpWhy3ExtraConfig`](#wpwhy3extraconfig)  */
export const getWpWhy3ExtraConfig: Server.GetRequest<null,string>= getWpWhy3ExtraConfig_internal;

const setWpWhy3ExtraConfig_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpWhy3ExtraConfig',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpWhy3ExtraConfig`](#wpwhy3extraconfig)  */
export const setWpWhy3ExtraConfig: Server.SetRequest<string,null>= setWpWhy3ExtraConfig_internal;

const wpWhy3ExtraConfig_internal: State.State<string> = {
  name: 'kernel.parameters.wpWhy3ExtraConfig',
  signal: signalWpWhy3ExtraConfig,
  getter: getWpWhy3ExtraConfig,
  setter: setWpWhy3ExtraConfig,
};
/** State of parameter -wp-why3-extra-config */
export const wpWhy3ExtraConfig: State.State<string> = wpWhy3ExtraConfig_internal;

/** Signal for state [`wpWhy3Opt`](#wpwhy3opt)  */
export const signalWpWhy3Opt: Server.Signal = {
  name: 'kernel.parameters.signalWpWhy3Opt',
};

const getWpWhy3Opt_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpWhy3Opt',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpWhy3Opt`](#wpwhy3opt)  */
export const getWpWhy3Opt: Server.GetRequest<null,string>= getWpWhy3Opt_internal;

const setWpWhy3Opt_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpWhy3Opt',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpWhy3Opt`](#wpwhy3opt)  */
export const setWpWhy3Opt: Server.SetRequest<string,null>= setWpWhy3Opt_internal;

const wpWhy3Opt_internal: State.State<string> = {
  name: 'kernel.parameters.wpWhy3Opt',
  signal: signalWpWhy3Opt,
  getter: getWpWhy3Opt,
  setter: setWpWhy3Opt,
};
/** State of parameter -wp-why3-opt */
export const wpWhy3Opt: State.State<string> = wpWhy3Opt_internal;

/** Signal for state [`wpAutoBacktrack`](#wpautobacktrack)  */
export const signalWpAutoBacktrack: Server.Signal = {
  name: 'kernel.parameters.signalWpAutoBacktrack',
};

const getWpAutoBacktrack_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpAutoBacktrack',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpAutoBacktrack`](#wpautobacktrack)  */
export const getWpAutoBacktrack: Server.GetRequest<null,number>= getWpAutoBacktrack_internal;

const setWpAutoBacktrack_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpAutoBacktrack',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpAutoBacktrack`](#wpautobacktrack)  */
export const setWpAutoBacktrack: Server.SetRequest<number,null>= setWpAutoBacktrack_internal;

const wpAutoBacktrack_internal: State.State<number> = {
  name: 'kernel.parameters.wpAutoBacktrack',
  signal: signalWpAutoBacktrack,
  getter: getWpAutoBacktrack,
  setter: setWpAutoBacktrack,
};
/** State of parameter -wp-auto-backtrack */
export const wpAutoBacktrack: State.State<number> = wpAutoBacktrack_internal;

/** Signal for state [`wpAutoWidth`](#wpautowidth)  */
export const signalWpAutoWidth: Server.Signal = {
  name: 'kernel.parameters.signalWpAutoWidth',
};

const getWpAutoWidth_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpAutoWidth',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpAutoWidth`](#wpautowidth)  */
export const getWpAutoWidth: Server.GetRequest<null,number>= getWpAutoWidth_internal;

const setWpAutoWidth_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpAutoWidth',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpAutoWidth`](#wpautowidth)  */
export const setWpAutoWidth: Server.SetRequest<number,null>= setWpAutoWidth_internal;

const wpAutoWidth_internal: State.State<number> = {
  name: 'kernel.parameters.wpAutoWidth',
  signal: signalWpAutoWidth,
  getter: getWpAutoWidth,
  setter: setWpAutoWidth,
};
/** State of parameter -wp-auto-width */
export const wpAutoWidth: State.State<number> = wpAutoWidth_internal;

/** Signal for state [`wpAutoDepth`](#wpautodepth)  */
export const signalWpAutoDepth: Server.Signal = {
  name: 'kernel.parameters.signalWpAutoDepth',
};

const getWpAutoDepth_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpAutoDepth',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpAutoDepth`](#wpautodepth)  */
export const getWpAutoDepth: Server.GetRequest<null,number>= getWpAutoDepth_internal;

const setWpAutoDepth_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpAutoDepth',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpAutoDepth`](#wpautodepth)  */
export const setWpAutoDepth: Server.SetRequest<number,null>= setWpAutoDepth_internal;

const wpAutoDepth_internal: State.State<number> = {
  name: 'kernel.parameters.wpAutoDepth',
  signal: signalWpAutoDepth,
  getter: getWpAutoDepth,
  setter: setWpAutoDepth,
};
/** State of parameter -wp-auto-depth */
export const wpAutoDepth: State.State<number> = wpAutoDepth_internal;

/** Signal for state [`wpAuto`](#wpauto)  */
export const signalWpAuto: Server.Signal = {
  name: 'kernel.parameters.signalWpAuto',
};

const getWpAuto_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpAuto',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpAuto`](#wpauto)  */
export const getWpAuto: Server.GetRequest<null,string>= getWpAuto_internal;

const setWpAuto_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpAuto',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpAuto`](#wpauto)  */
export const setWpAuto: Server.SetRequest<string,null>= setWpAuto_internal;

const wpAuto_internal: State.State<string> = {
  name: 'kernel.parameters.wpAuto',
  signal: signalWpAuto,
  getter: getWpAuto,
  setter: setWpAuto,
};
/** State of parameter -wp-auto */
export const wpAuto: State.State<string> = wpAuto_internal;

/** Signal for state [`wpProofTrace`](#wpprooftrace)  */
export const signalWpProofTrace: Server.Signal = {
  name: 'kernel.parameters.signalWpProofTrace',
};

const getWpProofTrace_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpProofTrace',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpProofTrace`](#wpprooftrace)  */
export const getWpProofTrace: Server.GetRequest<null,boolean>= getWpProofTrace_internal;

const setWpProofTrace_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpProofTrace',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpProofTrace`](#wpprooftrace)  */
export const setWpProofTrace: Server.SetRequest<boolean,null>= setWpProofTrace_internal;

const wpProofTrace_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpProofTrace',
  signal: signalWpProofTrace,
  getter: getWpProofTrace,
  setter: setWpProofTrace,
};
/** State of parameter -wp-proof-trace */
export const wpProofTrace: State.State<boolean> = wpProofTrace_internal;

/** Signal for state [`wpPar`](#wppar)  */
export const signalWpPar: Server.Signal = {
  name: 'kernel.parameters.signalWpPar',
};

const getWpPar_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpPar',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpPar`](#wppar)  */
export const getWpPar: Server.GetRequest<null,number>= getWpPar_internal;

const setWpPar_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpPar',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpPar`](#wppar)  */
export const setWpPar: Server.SetRequest<number,null>= setWpPar_internal;

const wpPar_internal: State.State<number> = {
  name: 'kernel.parameters.wpPar',
  signal: signalWpPar,
  getter: getWpPar,
  setter: setWpPar,
};
/** State of parameter -wp-par */
export const wpPar: State.State<number> = wpPar_internal;

/** Signal for state [`wpTimeMargin`](#wptimemargin)  */
export const signalWpTimeMargin: Server.Signal = {
  name: 'kernel.parameters.signalWpTimeMargin',
};

const getWpTimeMargin_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpTimeMargin',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpTimeMargin`](#wptimemargin)  */
export const getWpTimeMargin: Server.GetRequest<null,string>= getWpTimeMargin_internal;

const setWpTimeMargin_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpTimeMargin',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpTimeMargin`](#wptimemargin)  */
export const setWpTimeMargin: Server.SetRequest<string,null>= setWpTimeMargin_internal;

const wpTimeMargin_internal: State.State<string> = {
  name: 'kernel.parameters.wpTimeMargin',
  signal: signalWpTimeMargin,
  getter: getWpTimeMargin,
  setter: setWpTimeMargin,
};
/** State of parameter -wp-time-margin */
export const wpTimeMargin: State.State<string> = wpTimeMargin_internal;

/** Signal for state [`wpTimeExtra`](#wptimeextra)  */
export const signalWpTimeExtra: Server.Signal = {
  name: 'kernel.parameters.signalWpTimeExtra',
};

const getWpTimeExtra_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpTimeExtra',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpTimeExtra`](#wptimeextra)  */
export const getWpTimeExtra: Server.GetRequest<null,number>= getWpTimeExtra_internal;

const setWpTimeExtra_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpTimeExtra',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpTimeExtra`](#wptimeextra)  */
export const setWpTimeExtra: Server.SetRequest<number,null>= setWpTimeExtra_internal;

const wpTimeExtra_internal: State.State<number> = {
  name: 'kernel.parameters.wpTimeExtra',
  signal: signalWpTimeExtra,
  getter: getWpTimeExtra,
  setter: setWpTimeExtra,
};
/** State of parameter -wp-time-extra */
export const wpTimeExtra: State.State<number> = wpTimeExtra_internal;

/** Signal for state [`wpInteractiveTimeout`](#wpinteractivetimeout)  */
export const signalWpInteractiveTimeout: Server.Signal = {
  name: 'kernel.parameters.signalWpInteractiveTimeout',
};

const getWpInteractiveTimeout_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpInteractiveTimeout',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpInteractiveTimeout`](#wpinteractivetimeout)  */
export const getWpInteractiveTimeout: Server.GetRequest<null,number>= getWpInteractiveTimeout_internal;

const setWpInteractiveTimeout_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpInteractiveTimeout',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpInteractiveTimeout`](#wpinteractivetimeout)  */
export const setWpInteractiveTimeout: Server.SetRequest<number,null>= setWpInteractiveTimeout_internal;

const wpInteractiveTimeout_internal: State.State<number> = {
  name: 'kernel.parameters.wpInteractiveTimeout',
  signal: signalWpInteractiveTimeout,
  getter: getWpInteractiveTimeout,
  setter: setWpInteractiveTimeout,
};
/** State of parameter -wp-interactive-timeout */
export const wpInteractiveTimeout: State.State<number> = wpInteractiveTimeout_internal;

/** Signal for state [`wpSmokeTimeout`](#wpsmoketimeout)  */
export const signalWpSmokeTimeout: Server.Signal = {
  name: 'kernel.parameters.signalWpSmokeTimeout',
};

const getWpSmokeTimeout_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSmokeTimeout',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpSmokeTimeout`](#wpsmoketimeout)  */
export const getWpSmokeTimeout: Server.GetRequest<null,number>= getWpSmokeTimeout_internal;

const setWpSmokeTimeout_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSmokeTimeout',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSmokeTimeout`](#wpsmoketimeout)  */
export const setWpSmokeTimeout: Server.SetRequest<number,null>= setWpSmokeTimeout_internal;

const wpSmokeTimeout_internal: State.State<number> = {
  name: 'kernel.parameters.wpSmokeTimeout',
  signal: signalWpSmokeTimeout,
  getter: getWpSmokeTimeout,
  setter: setWpSmokeTimeout,
};
/** State of parameter -wp-smoke-timeout */
export const wpSmokeTimeout: State.State<number> = wpSmokeTimeout_internal;

/** Signal for state [`wpFctTimeout`](#wpfcttimeout)  */
export const signalWpFctTimeout: Server.Signal = {
  name: 'kernel.parameters.signalWpFctTimeout',
};

const getWpFctTimeout_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpFctTimeout',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpFctTimeout`](#wpfcttimeout)  */
export const getWpFctTimeout: Server.GetRequest<null,string>= getWpFctTimeout_internal;

const setWpFctTimeout_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpFctTimeout',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpFctTimeout`](#wpfcttimeout)  */
export const setWpFctTimeout: Server.SetRequest<string,null>= setWpFctTimeout_internal;

const wpFctTimeout_internal: State.State<string> = {
  name: 'kernel.parameters.wpFctTimeout',
  signal: signalWpFctTimeout,
  getter: getWpFctTimeout,
  setter: setWpFctTimeout,
};
/** State of parameter -wp-fct-timeout */
export const wpFctTimeout: State.State<string> = wpFctTimeout_internal;

/** Signal for state [`wpMemlimit`](#wpmemlimit)  */
export const signalWpMemlimit: Server.Signal = {
  name: 'kernel.parameters.signalWpMemlimit',
};

const getWpMemlimit_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpMemlimit',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpMemlimit`](#wpmemlimit)  */
export const getWpMemlimit: Server.GetRequest<null,number>= getWpMemlimit_internal;

const setWpMemlimit_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpMemlimit',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpMemlimit`](#wpmemlimit)  */
export const setWpMemlimit: Server.SetRequest<number,null>= setWpMemlimit_internal;

const wpMemlimit_internal: State.State<number> = {
  name: 'kernel.parameters.wpMemlimit',
  signal: signalWpMemlimit,
  getter: getWpMemlimit,
  setter: setWpMemlimit,
};
/** State of parameter -wp-memlimit */
export const wpMemlimit: State.State<number> = wpMemlimit_internal;

/** Signal for state [`wpTimeout`](#wptimeout)  */
export const signalWpTimeout: Server.Signal = {
  name: 'kernel.parameters.signalWpTimeout',
};

const getWpTimeout_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpTimeout',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpTimeout`](#wptimeout)  */
export const getWpTimeout: Server.GetRequest<null,number>= getWpTimeout_internal;

const setWpTimeout_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpTimeout',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpTimeout`](#wptimeout)  */
export const setWpTimeout: Server.SetRequest<number,null>= setWpTimeout_internal;

const wpTimeout_internal: State.State<number> = {
  name: 'kernel.parameters.wpTimeout',
  signal: signalWpTimeout,
  getter: getWpTimeout,
  setter: setWpTimeout,
};
/** State of parameter -wp-timeout */
export const wpTimeout: State.State<number> = wpTimeout_internal;

/** Signal for state [`wpSteps`](#wpsteps)  */
export const signalWpSteps: Server.Signal = {
  name: 'kernel.parameters.signalWpSteps',
};

const getWpSteps_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSteps',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`wpSteps`](#wpsteps)  */
export const getWpSteps: Server.GetRequest<null,number>= getWpSteps_internal;

const setWpSteps_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSteps',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSteps`](#wpsteps)  */
export const setWpSteps: Server.SetRequest<number,null>= setWpSteps_internal;

const wpSteps_internal: State.State<number> = {
  name: 'kernel.parameters.wpSteps',
  signal: signalWpSteps,
  getter: getWpSteps,
  setter: setWpSteps,
};
/** State of parameter -wp-steps */
export const wpSteps: State.State<number> = wpSteps_internal;

/** Signal for state [`wpDriver`](#wpdriver)  */
export const signalWpDriver: Server.Signal = {
  name: 'kernel.parameters.signalWpDriver',
};

const getWpDriver_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpDriver',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpDriver`](#wpdriver)  */
export const getWpDriver: Server.GetRequest<null,string>= getWpDriver_internal;

const setWpDriver_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpDriver',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpDriver`](#wpdriver)  */
export const setWpDriver: Server.SetRequest<string,null>= setWpDriver_internal;

const wpDriver_internal: State.State<string> = {
  name: 'kernel.parameters.wpDriver',
  signal: signalWpDriver,
  getter: getWpDriver,
  setter: setWpDriver,
};
/** State of parameter -wp-driver */
export const wpDriver: State.State<string> = wpDriver_internal;

/** Signal for state [`wpDetect`](#wpdetect)  */
export const signalWpDetect: Server.Signal = {
  name: 'kernel.parameters.signalWpDetect',
};

const getWpDetect_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpDetect',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpDetect`](#wpdetect)  */
export const getWpDetect: Server.GetRequest<null,boolean>= getWpDetect_internal;

const setWpDetect_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpDetect',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpDetect`](#wpdetect)  */
export const setWpDetect: Server.SetRequest<boolean,null>= setWpDetect_internal;

const wpDetect_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpDetect',
  signal: signalWpDetect,
  getter: getWpDetect,
  setter: setWpDetect,
};
/** State of parameter -wp-detect */
export const wpDetect: State.State<boolean> = wpDetect_internal;

/** Signal for state [`wpDryFinalizeScripts`](#wpdryfinalizescripts)  */
export const signalWpDryFinalizeScripts: Server.Signal = {
  name: 'kernel.parameters.signalWpDryFinalizeScripts',
};

const getWpDryFinalizeScripts_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpDryFinalizeScripts',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpDryFinalizeScripts`](#wpdryfinalizescripts)  */
export const getWpDryFinalizeScripts: Server.GetRequest<null,boolean>= getWpDryFinalizeScripts_internal;

const setWpDryFinalizeScripts_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpDryFinalizeScripts',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpDryFinalizeScripts`](#wpdryfinalizescripts)  */
export const setWpDryFinalizeScripts: Server.SetRequest<boolean,null>= setWpDryFinalizeScripts_internal;

const wpDryFinalizeScripts_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpDryFinalizeScripts',
  signal: signalWpDryFinalizeScripts,
  getter: getWpDryFinalizeScripts,
  setter: setWpDryFinalizeScripts,
};
/** State of parameter -wp-dry-finalize-scripts */
export const wpDryFinalizeScripts: State.State<boolean> = wpDryFinalizeScripts_internal;

/** Signal for state [`wpFinalizeScripts`](#wpfinalizescripts)  */
export const signalWpFinalizeScripts: Server.Signal = {
  name: 'kernel.parameters.signalWpFinalizeScripts',
};

const getWpFinalizeScripts_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpFinalizeScripts',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpFinalizeScripts`](#wpfinalizescripts)  */
export const getWpFinalizeScripts: Server.GetRequest<null,boolean>= getWpFinalizeScripts_internal;

const setWpFinalizeScripts_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpFinalizeScripts',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpFinalizeScripts`](#wpfinalizescripts)  */
export const setWpFinalizeScripts: Server.SetRequest<boolean,null>= setWpFinalizeScripts_internal;

const wpFinalizeScripts_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpFinalizeScripts',
  signal: signalWpFinalizeScripts,
  getter: getWpFinalizeScripts,
  setter: setWpFinalizeScripts,
};
/** State of parameter -wp-finalize-scripts */
export const wpFinalizeScripts: State.State<boolean> = wpFinalizeScripts_internal;

/** Signal for state [`wpPrepareScripts`](#wppreparescripts)  */
export const signalWpPrepareScripts: Server.Signal = {
  name: 'kernel.parameters.signalWpPrepareScripts',
};

const getWpPrepareScripts_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpPrepareScripts',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpPrepareScripts`](#wppreparescripts)  */
export const getWpPrepareScripts: Server.GetRequest<null,boolean>= getWpPrepareScripts_internal;

const setWpPrepareScripts_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpPrepareScripts',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpPrepareScripts`](#wppreparescripts)  */
export const setWpPrepareScripts: Server.SetRequest<boolean,null>= setWpPrepareScripts_internal;

const wpPrepareScripts_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpPrepareScripts',
  signal: signalWpPrepareScripts,
  getter: getWpPrepareScripts,
  setter: setWpPrepareScripts,
};
/** State of parameter -wp-prepare-scripts */
export const wpPrepareScripts: State.State<boolean> = wpPrepareScripts_internal;

/** Signal for state [`wpScriptOnStdout`](#wpscriptonstdout)  */
export const signalWpScriptOnStdout: Server.Signal = {
  name: 'kernel.parameters.signalWpScriptOnStdout',
};

const getWpScriptOnStdout_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpScriptOnStdout',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpScriptOnStdout`](#wpscriptonstdout)  */
export const getWpScriptOnStdout: Server.GetRequest<null,boolean>= getWpScriptOnStdout_internal;

const setWpScriptOnStdout_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpScriptOnStdout',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpScriptOnStdout`](#wpscriptonstdout)  */
export const setWpScriptOnStdout: Server.SetRequest<boolean,null>= setWpScriptOnStdout_internal;

const wpScriptOnStdout_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpScriptOnStdout',
  signal: signalWpScriptOnStdout,
  getter: getWpScriptOnStdout,
  setter: setWpScriptOnStdout,
};
/** State of parameter -wp-script-on-stdout */
export const wpScriptOnStdout: State.State<boolean> = wpScriptOnStdout_internal;

/** Signal for state [`wpGen`](#wpgen)  */
export const signalWpGen: Server.Signal = {
  name: 'kernel.parameters.signalWpGen',
};

const getWpGen_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpGen',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpGen`](#wpgen)  */
export const getWpGen: Server.GetRequest<null,boolean>= getWpGen_internal;

const setWpGen_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpGen',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpGen`](#wpgen)  */
export const setWpGen: Server.SetRequest<boolean,null>= setWpGen_internal;

const wpGen_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpGen',
  signal: signalWpGen,
  getter: getWpGen,
  setter: setWpGen,
};
/** State of parameter -wp-gen */
export const wpGen: State.State<boolean> = wpGen_internal;

/** Signal for state [`wpCachePrint`](#wpcacheprint)  */
export const signalWpCachePrint: Server.Signal = {
  name: 'kernel.parameters.signalWpCachePrint',
};

const getWpCachePrint_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpCachePrint',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpCachePrint`](#wpcacheprint)  */
export const getWpCachePrint: Server.GetRequest<null,boolean>= getWpCachePrint_internal;

const setWpCachePrint_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpCachePrint',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpCachePrint`](#wpcacheprint)  */
export const setWpCachePrint: Server.SetRequest<boolean,null>= setWpCachePrint_internal;

const wpCachePrint_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpCachePrint',
  signal: signalWpCachePrint,
  getter: getWpCachePrint,
  setter: setWpCachePrint,
};
/** State of parameter -wp-cache-print */
export const wpCachePrint: State.State<boolean> = wpCachePrint_internal;

/** Signal for state [`wpCacheEnv`](#wpcacheenv)  */
export const signalWpCacheEnv: Server.Signal = {
  name: 'kernel.parameters.signalWpCacheEnv',
};

const getWpCacheEnv_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpCacheEnv',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpCacheEnv`](#wpcacheenv)  */
export const getWpCacheEnv: Server.GetRequest<null,boolean>= getWpCacheEnv_internal;

const setWpCacheEnv_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpCacheEnv',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpCacheEnv`](#wpcacheenv)  */
export const setWpCacheEnv: Server.SetRequest<boolean,null>= setWpCacheEnv_internal;

const wpCacheEnv_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpCacheEnv',
  signal: signalWpCacheEnv,
  getter: getWpCacheEnv,
  setter: setWpCacheEnv,
};
/** State of parameter -wp-cache-env */
export const wpCacheEnv: State.State<boolean> = wpCacheEnv_internal;

/** Signal for state [`wpCacheDir`](#wpcachedir)  */
export const signalWpCacheDir: Server.Signal = {
  name: 'kernel.parameters.signalWpCacheDir',
};

const getWpCacheDir_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpCacheDir',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpCacheDir`](#wpcachedir)  */
export const getWpCacheDir: Server.GetRequest<null,string>= getWpCacheDir_internal;

const setWpCacheDir_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpCacheDir',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpCacheDir`](#wpcachedir)  */
export const setWpCacheDir: Server.SetRequest<string,null>= setWpCacheDir_internal;

const wpCacheDir_internal: State.State<string> = {
  name: 'kernel.parameters.wpCacheDir',
  signal: signalWpCacheDir,
  getter: getWpCacheDir,
  setter: setWpCacheDir,
};
/** State of parameter -wp-cache-dir */
export const wpCacheDir: State.State<string> = wpCacheDir_internal;

/** Signal for state [`wpCache`](#wpcache)  */
export const signalWpCache: Server.Signal = {
  name: 'kernel.parameters.signalWpCache',
};

const getWpCache_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpCache',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpCache`](#wpcache)  */
export const getWpCache: Server.GetRequest<null,string>= getWpCache_internal;

const setWpCache_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpCache',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpCache`](#wpcache)  */
export const setWpCache: Server.SetRequest<string,null>= setWpCache_internal;

const wpCache_internal: State.State<string> = {
  name: 'kernel.parameters.wpCache',
  signal: signalWpCache,
  getter: getWpCache,
  setter: setWpCache,
};
/** State of parameter -wp-cache */
export const wpCache: State.State<string> = wpCache_internal;

/** Signal for state [`wpRunAllProvers`](#wprunallprovers)  */
export const signalWpRunAllProvers: Server.Signal = {
  name: 'kernel.parameters.signalWpRunAllProvers',
};

const getWpRunAllProvers_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpRunAllProvers',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpRunAllProvers`](#wprunallprovers)  */
export const getWpRunAllProvers: Server.GetRequest<null,boolean>= getWpRunAllProvers_internal;

const setWpRunAllProvers_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpRunAllProvers',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpRunAllProvers`](#wprunallprovers)  */
export const setWpRunAllProvers: Server.SetRequest<boolean,null>= setWpRunAllProvers_internal;

const wpRunAllProvers_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpRunAllProvers',
  signal: signalWpRunAllProvers,
  getter: getWpRunAllProvers,
  setter: setWpRunAllProvers,
};
/** State of parameter -wp-run-all-provers */
export const wpRunAllProvers: State.State<boolean> = wpRunAllProvers_internal;

/** Signal for state [`wpStrategy`](#wpstrategy)  */
export const signalWpStrategy: Server.Signal = {
  name: 'kernel.parameters.signalWpStrategy',
};

const getWpStrategy_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpStrategy',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpStrategy`](#wpstrategy)  */
export const getWpStrategy: Server.GetRequest<null,string>= getWpStrategy_internal;

const setWpStrategy_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpStrategy',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpStrategy`](#wpstrategy)  */
export const setWpStrategy: Server.SetRequest<string,null>= setWpStrategy_internal;

const wpStrategy_internal: State.State<string> = {
  name: 'kernel.parameters.wpStrategy',
  signal: signalWpStrategy,
  getter: getWpStrategy,
  setter: setWpStrategy,
};
/** State of parameter -wp-strategy */
export const wpStrategy: State.State<string> = wpStrategy_internal;

/** Signal for state [`wpStrategyEngine`](#wpstrategyengine)  */
export const signalWpStrategyEngine: Server.Signal = {
  name: 'kernel.parameters.signalWpStrategyEngine',
};

const getWpStrategyEngine_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpStrategyEngine',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpStrategyEngine`](#wpstrategyengine)  */
export const getWpStrategyEngine: Server.GetRequest<null,boolean>= getWpStrategyEngine_internal;

const setWpStrategyEngine_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpStrategyEngine',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpStrategyEngine`](#wpstrategyengine)  */
export const setWpStrategyEngine: Server.SetRequest<boolean,null>= setWpStrategyEngine_internal;

const wpStrategyEngine_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpStrategyEngine',
  signal: signalWpStrategyEngine,
  getter: getWpStrategyEngine,
  setter: setWpStrategyEngine,
};
/** State of parameter -wp-strategy-engine */
export const wpStrategyEngine: State.State<boolean> = wpStrategyEngine_internal;

/** Signal for state [`wpScript`](#wpscript)  */
export const signalWpScript: Server.Signal = {
  name: 'kernel.parameters.signalWpScript',
};

const getWpScript_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpScript',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpScript`](#wpscript)  */
export const getWpScript: Server.GetRequest<null,string>= getWpScript_internal;

const setWpScript_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpScript',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpScript`](#wpscript)  */
export const setWpScript: Server.SetRequest<string,null>= setWpScript_internal;

const wpScript_internal: State.State<string> = {
  name: 'kernel.parameters.wpScript',
  signal: signalWpScript,
  getter: getWpScript,
  setter: setWpScript,
};
/** State of parameter -wp-script */
export const wpScript: State.State<string> = wpScript_internal;

/** Signal for state [`wpInteractive`](#wpinteractive)  */
export const signalWpInteractive: Server.Signal = {
  name: 'kernel.parameters.signalWpInteractive',
};

const getWpInteractive_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpInteractive',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpInteractive`](#wpinteractive)  */
export const getWpInteractive: Server.GetRequest<null,string>= getWpInteractive_internal;

const setWpInteractive_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpInteractive',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpInteractive`](#wpinteractive)  */
export const setWpInteractive: Server.SetRequest<string,null>= setWpInteractive_internal;

const wpInteractive_internal: State.State<string> = {
  name: 'kernel.parameters.wpInteractive',
  signal: signalWpInteractive,
  getter: getWpInteractive,
  setter: setWpInteractive,
};
/** State of parameter -wp-interactive */
export const wpInteractive: State.State<string> = wpInteractive_internal;

/** Signal for state [`wpProver`](#wpprover)  */
export const signalWpProver: Server.Signal = {
  name: 'kernel.parameters.signalWpProver',
};

const getWpProver_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpProver',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpProver`](#wpprover)  */
export const getWpProver: Server.GetRequest<null,string>= getWpProver_internal;

const setWpProver_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpProver',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpProver`](#wpprover)  */
export const setWpProver: Server.SetRequest<string,null>= setWpProver_internal;

const wpProver_internal: State.State<string> = {
  name: 'kernel.parameters.wpProver',
  signal: signalWpProver,
  getter: getWpProver,
  setter: setWpProver,
};
/** State of parameter -wp-prover */
export const wpProver: State.State<string> = wpProver_internal;

/** Signal for state [`wpStatusMaybe`](#wpstatusmaybe)  */
export const signalWpStatusMaybe: Server.Signal = {
  name: 'kernel.parameters.signalWpStatusMaybe',
};

const getWpStatusMaybe_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpStatusMaybe',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpStatusMaybe`](#wpstatusmaybe)  */
export const getWpStatusMaybe: Server.GetRequest<null,boolean>= getWpStatusMaybe_internal;

const setWpStatusMaybe_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpStatusMaybe',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpStatusMaybe`](#wpstatusmaybe)  */
export const setWpStatusMaybe: Server.SetRequest<boolean,null>= setWpStatusMaybe_internal;

const wpStatusMaybe_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpStatusMaybe',
  signal: signalWpStatusMaybe,
  getter: getWpStatusMaybe,
  setter: setWpStatusMaybe,
};
/** State of parameter -wp-status-maybe */
export const wpStatusMaybe: State.State<boolean> = wpStatusMaybe_internal;

/** Signal for state [`wpStatusInvalid`](#wpstatusinvalid)  */
export const signalWpStatusInvalid: Server.Signal = {
  name: 'kernel.parameters.signalWpStatusInvalid',
};

const getWpStatusInvalid_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpStatusInvalid',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpStatusInvalid`](#wpstatusinvalid)  */
export const getWpStatusInvalid: Server.GetRequest<null,boolean>= getWpStatusInvalid_internal;

const setWpStatusInvalid_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpStatusInvalid',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpStatusInvalid`](#wpstatusinvalid)  */
export const setWpStatusInvalid: Server.SetRequest<boolean,null>= setWpStatusInvalid_internal;

const wpStatusInvalid_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpStatusInvalid',
  signal: signalWpStatusInvalid,
  getter: getWpStatusInvalid,
  setter: setWpStatusInvalid,
};
/** State of parameter -wp-status-invalid */
export const wpStatusInvalid: State.State<boolean> = wpStatusInvalid_internal;

/** Signal for state [`wpStatusValid`](#wpstatusvalid)  */
export const signalWpStatusValid: Server.Signal = {
  name: 'kernel.parameters.signalWpStatusValid',
};

const getWpStatusValid_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpStatusValid',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpStatusValid`](#wpstatusvalid)  */
export const getWpStatusValid: Server.GetRequest<null,boolean>= getWpStatusValid_internal;

const setWpStatusValid_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpStatusValid',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpStatusValid`](#wpstatusvalid)  */
export const setWpStatusValid: Server.SetRequest<boolean,null>= setWpStatusValid_internal;

const wpStatusValid_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpStatusValid',
  signal: signalWpStatusValid,
  getter: getWpStatusValid,
  setter: setWpStatusValid,
};
/** State of parameter -wp-status-valid */
export const wpStatusValid: State.State<boolean> = wpStatusValid_internal;

/** Signal for state [`wpStatusAll`](#wpstatusall)  */
export const signalWpStatusAll: Server.Signal = {
  name: 'kernel.parameters.signalWpStatusAll',
};

const getWpStatusAll_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpStatusAll',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpStatusAll`](#wpstatusall)  */
export const getWpStatusAll: Server.GetRequest<null,boolean>= getWpStatusAll_internal;

const setWpStatusAll_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpStatusAll',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpStatusAll`](#wpstatusall)  */
export const setWpStatusAll: Server.SetRequest<boolean,null>= setWpStatusAll_internal;

const wpStatusAll_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpStatusAll',
  signal: signalWpStatusAll,
  getter: getWpStatusAll,
  setter: setWpStatusAll,
};
/** State of parameter -wp-status-all */
export const wpStatusAll: State.State<boolean> = wpStatusAll_internal;

/** Signal for state [`wpProp`](#wpprop)  */
export const signalWpProp: Server.Signal = {
  name: 'kernel.parameters.signalWpProp',
};

const getWpProp_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpProp',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpProp`](#wpprop)  */
export const getWpProp: Server.GetRequest<null,string>= getWpProp_internal;

const setWpProp_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpProp',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpProp`](#wpprop)  */
export const setWpProp: Server.SetRequest<string,null>= setWpProp_internal;

const wpProp_internal: State.State<string> = {
  name: 'kernel.parameters.wpProp',
  signal: signalWpProp,
  getter: getWpProp,
  setter: setWpProp,
};
/** State of parameter -wp-prop */
export const wpProp: State.State<string> = wpProp_internal;

/** Signal for state [`wpBhv`](#wpbhv)  */
export const signalWpBhv: Server.Signal = {
  name: 'kernel.parameters.signalWpBhv',
};

const getWpBhv_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpBhv',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpBhv`](#wpbhv)  */
export const getWpBhv: Server.GetRequest<null,string>= getWpBhv_internal;

const setWpBhv_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpBhv',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpBhv`](#wpbhv)  */
export const setWpBhv: Server.SetRequest<string,null>= setWpBhv_internal;

const wpBhv_internal: State.State<string> = {
  name: 'kernel.parameters.wpBhv',
  signal: signalWpBhv,
  getter: getWpBhv,
  setter: setWpBhv,
};
/** State of parameter -wp-bhv */
export const wpBhv: State.State<string> = wpBhv_internal;

/** Signal for state [`wpSkipFct`](#wpskipfct)  */
export const signalWpSkipFct: Server.Signal = {
  name: 'kernel.parameters.signalWpSkipFct',
};

const getWpSkipFct_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpSkipFct',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpSkipFct`](#wpskipfct)  */
export const getWpSkipFct: Server.GetRequest<null,string>= getWpSkipFct_internal;

const setWpSkipFct_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpSkipFct',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpSkipFct`](#wpskipfct)  */
export const setWpSkipFct: Server.SetRequest<string,null>= setWpSkipFct_internal;

const wpSkipFct_internal: State.State<string> = {
  name: 'kernel.parameters.wpSkipFct',
  signal: signalWpSkipFct,
  getter: getWpSkipFct,
  setter: setWpSkipFct,
};
/** State of parameter -wp-skip-fct */
export const wpSkipFct: State.State<string> = wpSkipFct_internal;

/** Signal for state [`wpFct`](#wpfct)  */
export const signalWpFct: Server.Signal = {
  name: 'kernel.parameters.signalWpFct',
};

const getWpFct_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpFct',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`wpFct`](#wpfct)  */
export const getWpFct: Server.GetRequest<null,string>= getWpFct_internal;

const setWpFct_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpFct',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpFct`](#wpfct)  */
export const setWpFct: Server.SetRequest<string,null>= setWpFct_internal;

const wpFct_internal: State.State<string> = {
  name: 'kernel.parameters.wpFct',
  signal: signalWpFct,
  getter: getWpFct,
  setter: setWpFct,
};
/** State of parameter -wp-fct */
export const wpFct: State.State<string> = wpFct_internal;

/** Signal for state [`wpDump`](#wpdump)  */
export const signalWpDump: Server.Signal = {
  name: 'kernel.parameters.signalWpDump',
};

const getWpDump_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWpDump',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wpDump`](#wpdump)  */
export const getWpDump: Server.GetRequest<null,boolean>= getWpDump_internal;

const setWpDump_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWpDump',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wpDump`](#wpdump)  */
export const setWpDump: Server.SetRequest<boolean,null>= setWpDump_internal;

const wpDump_internal: State.State<boolean> = {
  name: 'kernel.parameters.wpDump',
  signal: signalWpDump,
  getter: getWpDump,
  setter: setWpDump,
};
/** State of parameter -wp-dump */
export const wpDump: State.State<boolean> = wpDump_internal;

/** Signal for state [`wp`](#wp)  */
export const signalWp: Server.Signal = {
  name: 'kernel.parameters.signalWp',
};

const getWp_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getWp',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`wp`](#wp)  */
export const getWp: Server.GetRequest<null,boolean>= getWp_internal;

const setWp_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setWp',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`wp`](#wp)  */
export const setWp: Server.SetRequest<boolean,null>= setWp_internal;

const wp_internal: State.State<boolean> = {
  name: 'kernel.parameters.wp',
  signal: signalWp,
  getter: getWp,
  setter: setWp,
};
/** State of parameter -wp */
export const wp: State.State<boolean> = wp_internal;

/** Signal for state [`rteSelect`](#rteselect)  */
export const signalRteSelect: Server.Signal = {
  name: 'kernel.parameters.signalRteSelect',
};

const getRteSelect_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteSelect',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`rteSelect`](#rteselect)  */
export const getRteSelect: Server.GetRequest<null,string>= getRteSelect_internal;

const setRteSelect_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteSelect',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteSelect`](#rteselect)  */
export const setRteSelect: Server.SetRequest<string,null>= setRteSelect_internal;

const rteSelect_internal: State.State<string> = {
  name: 'kernel.parameters.rteSelect',
  signal: signalRteSelect,
  getter: getRteSelect,
  setter: setRteSelect,
};
/** State of parameter -rte-select */
export const rteSelect: State.State<string> = rteSelect_internal;

/** Signal for state [`rteWarn`](#rtewarn)  */
export const signalRteWarn: Server.Signal = {
  name: 'kernel.parameters.signalRteWarn',
};

const getRteWarn_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteWarn',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`rteWarn`](#rtewarn)  */
export const getRteWarn: Server.GetRequest<null,boolean>= getRteWarn_internal;

const setRteWarn_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteWarn',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteWarn`](#rtewarn)  */
export const setRteWarn: Server.SetRequest<boolean,null>= setRteWarn_internal;

const rteWarn_internal: State.State<boolean> = {
  name: 'kernel.parameters.rteWarn',
  signal: signalRteWarn,
  getter: getRteWarn,
  setter: setRteWarn,
};
/** State of parameter -rte-warn */
export const rteWarn: State.State<boolean> = rteWarn_internal;

/** Signal for state [`rteTrivialAnnotations`](#rtetrivialannotations)  */
export const signalRteTrivialAnnotations: Server.Signal = {
  name: 'kernel.parameters.signalRteTrivialAnnotations',
};

const getRteTrivialAnnotations_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteTrivialAnnotations',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`rteTrivialAnnotations`](#rtetrivialannotations)  */
export const getRteTrivialAnnotations: Server.GetRequest<null,boolean>= getRteTrivialAnnotations_internal;

const setRteTrivialAnnotations_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteTrivialAnnotations',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteTrivialAnnotations`](#rtetrivialannotations)  */
export const setRteTrivialAnnotations: Server.SetRequest<boolean,null>= setRteTrivialAnnotations_internal;

const rteTrivialAnnotations_internal: State.State<boolean> = {
  name: 'kernel.parameters.rteTrivialAnnotations',
  signal: signalRteTrivialAnnotations,
  getter: getRteTrivialAnnotations,
  setter: setRteTrivialAnnotations,
};
/** State of parameter -rte-trivial-annotations */
export const rteTrivialAnnotations: State.State<boolean> = rteTrivialAnnotations_internal;

/** Signal for state [`rtePointerCall`](#rtepointercall)  */
export const signalRtePointerCall: Server.Signal = {
  name: 'kernel.parameters.signalRtePointerCall',
};

const getRtePointerCall_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRtePointerCall',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`rtePointerCall`](#rtepointercall)  */
export const getRtePointerCall: Server.GetRequest<null,boolean>= getRtePointerCall_internal;

const setRtePointerCall_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRtePointerCall',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rtePointerCall`](#rtepointercall)  */
export const setRtePointerCall: Server.SetRequest<boolean,null>= setRtePointerCall_internal;

const rtePointerCall_internal: State.State<boolean> = {
  name: 'kernel.parameters.rtePointerCall',
  signal: signalRtePointerCall,
  getter: getRtePointerCall,
  setter: setRtePointerCall,
};
/** State of parameter -rte-pointer-call */
export const rtePointerCall: State.State<boolean> = rtePointerCall_internal;

/** Signal for state [`rteMem`](#rtemem)  */
export const signalRteMem: Server.Signal = {
  name: 'kernel.parameters.signalRteMem',
};

const getRteMem_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteMem',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`rteMem`](#rtemem)  */
export const getRteMem: Server.GetRequest<null,boolean>= getRteMem_internal;

const setRteMem_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteMem',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteMem`](#rtemem)  */
export const setRteMem: Server.SetRequest<boolean,null>= setRteMem_internal;

const rteMem_internal: State.State<boolean> = {
  name: 'kernel.parameters.rteMem',
  signal: signalRteMem,
  getter: getRteMem,
  setter: setRteMem,
};
/** State of parameter -rte-mem */
export const rteMem: State.State<boolean> = rteMem_internal;

/** Signal for state [`rteInitialized`](#rteinitialized)  */
export const signalRteInitialized: Server.Signal = {
  name: 'kernel.parameters.signalRteInitialized',
};

const getRteInitialized_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteInitialized',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`rteInitialized`](#rteinitialized)  */
export const getRteInitialized: Server.GetRequest<null,string>= getRteInitialized_internal;

const setRteInitialized_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteInitialized',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteInitialized`](#rteinitialized)  */
export const setRteInitialized: Server.SetRequest<string,null>= setRteInitialized_internal;

const rteInitialized_internal: State.State<string> = {
  name: 'kernel.parameters.rteInitialized',
  signal: signalRteInitialized,
  getter: getRteInitialized,
  setter: setRteInitialized,
};
/** State of parameter -rte-initialized */
export const rteInitialized: State.State<string> = rteInitialized_internal;

/** Signal for state [`rteFloatToInt`](#rtefloattoint)  */
export const signalRteFloatToInt: Server.Signal = {
  name: 'kernel.parameters.signalRteFloatToInt',
};

const getRteFloatToInt_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteFloatToInt',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`rteFloatToInt`](#rtefloattoint)  */
export const getRteFloatToInt: Server.GetRequest<null,boolean>= getRteFloatToInt_internal;

const setRteFloatToInt_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteFloatToInt',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteFloatToInt`](#rtefloattoint)  */
export const setRteFloatToInt: Server.SetRequest<boolean,null>= setRteFloatToInt_internal;

const rteFloatToInt_internal: State.State<boolean> = {
  name: 'kernel.parameters.rteFloatToInt',
  signal: signalRteFloatToInt,
  getter: getRteFloatToInt,
  setter: setRteFloatToInt,
};
/** State of parameter -rte-float-to-int */
export const rteFloatToInt: State.State<boolean> = rteFloatToInt_internal;

/** Signal for state [`rteShift`](#rteshift)  */
export const signalRteShift: Server.Signal = {
  name: 'kernel.parameters.signalRteShift',
};

const getRteShift_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteShift',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`rteShift`](#rteshift)  */
export const getRteShift: Server.GetRequest<null,boolean>= getRteShift_internal;

const setRteShift_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteShift',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteShift`](#rteshift)  */
export const setRteShift: Server.SetRequest<boolean,null>= setRteShift_internal;

const rteShift_internal: State.State<boolean> = {
  name: 'kernel.parameters.rteShift',
  signal: signalRteShift,
  getter: getRteShift,
  setter: setRteShift,
};
/** State of parameter -rte-shift */
export const rteShift: State.State<boolean> = rteShift_internal;

/** Signal for state [`rteDiv`](#rtediv)  */
export const signalRteDiv: Server.Signal = {
  name: 'kernel.parameters.signalRteDiv',
};

const getRteDiv_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteDiv',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`rteDiv`](#rtediv)  */
export const getRteDiv: Server.GetRequest<null,boolean>= getRteDiv_internal;

const setRteDiv_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteDiv',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteDiv`](#rtediv)  */
export const setRteDiv: Server.SetRequest<boolean,null>= setRteDiv_internal;

const rteDiv_internal: State.State<boolean> = {
  name: 'kernel.parameters.rteDiv',
  signal: signalRteDiv,
  getter: getRteDiv,
  setter: setRteDiv,
};
/** State of parameter -rte-div */
export const rteDiv: State.State<boolean> = rteDiv_internal;

/** Signal for state [`rte`](#rte)  */
export const signalRte: Server.Signal = {
  name: 'kernel.parameters.signalRte',
};

const getRte_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRte',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`rte`](#rte)  */
export const getRte: Server.GetRequest<null,boolean>= getRte_internal;

const setRte_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRte',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rte`](#rte)  */
export const setRte: Server.SetRequest<boolean,null>= setRte_internal;

const rte_internal: State.State<boolean> = {
  name: 'kernel.parameters.rte',
  signal: signalRte,
  getter: getRte,
  setter: setRte,
};
/** State of parameter -rte */
export const rte: State.State<boolean> = rte_internal;

/** Signal for state [`rteWarnKey`](#rtewarnkey)  */
export const signalRteWarnKey: Server.Signal = {
  name: 'kernel.parameters.signalRteWarnKey',
};

const getRteWarnKey_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteWarnKey',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`rteWarnKey`](#rtewarnkey)  */
export const getRteWarnKey: Server.GetRequest<null,string>= getRteWarnKey_internal;

const setRteWarnKey_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteWarnKey',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteWarnKey`](#rtewarnkey)  */
export const setRteWarnKey: Server.SetRequest<string,null>= setRteWarnKey_internal;

const rteWarnKey_internal: State.State<string> = {
  name: 'kernel.parameters.rteWarnKey',
  signal: signalRteWarnKey,
  getter: getRteWarnKey,
  setter: setRteWarnKey,
};
/** State of parameter -rte-warn-key */
export const rteWarnKey: State.State<string> = rteWarnKey_internal;

/** Signal for state [`rteMsgKey`](#rtemsgkey)  */
export const signalRteMsgKey: Server.Signal = {
  name: 'kernel.parameters.signalRteMsgKey',
};

const getRteMsgKey_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteMsgKey',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`rteMsgKey`](#rtemsgkey)  */
export const getRteMsgKey: Server.GetRequest<null,string>= getRteMsgKey_internal;

const setRteMsgKey_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteMsgKey',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteMsgKey`](#rtemsgkey)  */
export const setRteMsgKey: Server.SetRequest<string,null>= setRteMsgKey_internal;

const rteMsgKey_internal: State.State<string> = {
  name: 'kernel.parameters.rteMsgKey',
  signal: signalRteMsgKey,
  getter: getRteMsgKey,
  setter: setRteMsgKey,
};
/** State of parameter -rte-msg-key */
export const rteMsgKey: State.State<string> = rteMsgKey_internal;

/** Signal for state [`rteDebug`](#rtedebug)  */
export const signalRteDebug: Server.Signal = {
  name: 'kernel.parameters.signalRteDebug',
};

const getRteDebug_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteDebug',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`rteDebug`](#rtedebug)  */
export const getRteDebug: Server.GetRequest<null,number>= getRteDebug_internal;

const setRteDebug_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteDebug',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteDebug`](#rtedebug)  */
export const setRteDebug: Server.SetRequest<number,null>= setRteDebug_internal;

const rteDebug_internal: State.State<number> = {
  name: 'kernel.parameters.rteDebug',
  signal: signalRteDebug,
  getter: getRteDebug,
  setter: setRteDebug,
};
/** State of parameter -rte-debug */
export const rteDebug: State.State<number> = rteDebug_internal;

/** Signal for state [`rteVerbose`](#rteverbose)  */
export const signalRteVerbose: Server.Signal = {
  name: 'kernel.parameters.signalRteVerbose',
};

const getRteVerbose_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteVerbose',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`rteVerbose`](#rteverbose)  */
export const getRteVerbose: Server.GetRequest<null,number>= getRteVerbose_internal;

const setRteVerbose_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteVerbose',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteVerbose`](#rteverbose)  */
export const setRteVerbose: Server.SetRequest<number,null>= setRteVerbose_internal;

const rteVerbose_internal: State.State<number> = {
  name: 'kernel.parameters.rteVerbose',
  signal: signalRteVerbose,
  getter: getRteVerbose,
  setter: setRteVerbose,
};
/** State of parameter -rte-verbose */
export const rteVerbose: State.State<number> = rteVerbose_internal;

/** Signal for state [`rteLog`](#rtelog)  */
export const signalRteLog: Server.Signal = {
  name: 'kernel.parameters.signalRteLog',
};

const getRteLog_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'kernel.parameters.getRteLog',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`rteLog`](#rtelog)  */
export const getRteLog: Server.GetRequest<null,string>= getRteLog_internal;

const setRteLog_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.parameters.setRteLog',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`rteLog`](#rtelog)  */
export const setRteLog: Server.SetRequest<string,null>= setRteLog_internal;

const rteLog_internal: State.State<string> = {
  name: 'kernel.parameters.rteLog',
  signal: signalRteLog,
  getter: getRteLog,
  setter: setRteLog,
};
/** State of parameter -rte-log */
export const rteLog: State.State<string> = rteLog_internal;

/* ------------------------------------- */
