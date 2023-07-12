import { join } from 'path';
import { getDirname } from 'cross-dirname';

const dirname = getDirname();

import { execSync } from 'child_process';

process.env.TEST = true;

let timeoutTest = process.env.DEBUG ? 999999999 : 30000;
timeoutTest = process.env.MONKEY ? 30000 : timeoutTest;

let specsTest = process.env.MONKEY ? ['./test/*.spec.js'] : ['./test/*.spec.ts']

execSync(join(dirname, 'scripts', 'before.sh'));

export const config = {
  services: [
    [
      'electron',
      {
        appPath: join(dirname, '..', '..', '..', 'ivette', 'dist'),
        appName: 'ivette',
        appArgs: ['command /home/user01/Documents/sources/frama-c/bin/frama-c'],
        chromedriver: {
          port: 9519,
          logFileName: 'wdio-chromedriver.log'
        },
        electronVersion: '16.2.8',
      },
    ],
  ],
  capabilities: [{}],
  port: 9519,
  waitforTimeout: 5000,
  connectionRetryCount: 10,
  connectionRetryTimeout: 30000,
  execArgv: [],
  logLevel: 'debug',
  runner: 'local',
  outputDir: 'wdio-logs',
  specs: specsTest,
  autoCompileOpts: {
    autoCompile: true,
    tsNodeOpts: {
      esm: true,
      transpileOnly: true,
      files: true,
      project: join(dirname, 'tsconfig.test.json'),
    },
  },
  framework: 'mocha',
  mochaOpts: {
    ui: 'bdd',
    timeout: timeoutTest,
  },
/*   beforeSuite: function () {
    console.log("beforeSuite");
 },
 before: function () {
    console.log("before");
 },
 beforeSession: function () {
    console.log("beforeSession");
 },
 beforeTest: function () {
    console.log("beforeTest");
 },
 beforeHook: function () {
    console.log("beforeHook");
 },
 onPrepare: function (config, capabilities) {
    console.log("onPrepare");
    console.log(config);
    console.log(capabilities);
 },
 onWorkerStart: function (cid, caps, specs, args, execArgv) {
    console.log("onWorkerStart");
    console.log(cid);
    console.log(caps);
    console.log(specs);
    console.log(args);
    console.log(execArgv);
    execFileSync(join(dirname, 'scripts', 'before.sh'));
 },
 onWorkerEnd: function (cid, exitCode, specs, retries) {
    console.log("onWorkerEnd");
    console.log(cid);
    console.log(exitCode);
    console.log(specs);
    console.log(retries);
 },  */
/*  beforeCommand: function () {
    console.log("beforeCommand");
 } */
};

