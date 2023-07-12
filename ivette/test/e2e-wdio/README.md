# How to execute e2e and monkey testing with WebdriverIO

WebdriverIO cannot natively handle electron apps. `wdio-electron-service` can. It is therefore added as a dependency in the e2e project's package.json.

WebdriverIO and its plugin `wdio-electron-service` require the Ivette electron binaries
- Therefore build Ivette binary first. From frama-c repertory : `make -C ivette dist` ;

WebdriverIO prefers pnpm
- install pnpm : `npm install -g pnpm` ;

Build `e2e-wdio` project : 
- in `e2e-wdio` repertory : `npm install` ;
- modify frama-c binary path in  `wdio.conf.js` (line 24) ;

Launch tests : 
- in `e2e-wdio` repertory, launch e2e test with `pnpm test` 
- in `e2e-wdio` repertory, launch monkey testing (gremlins.js) with `MONKEY=true pnpm test` ;