# Javascript in SGN

## Modern JS
Modern (modularized) code is in the source folder. The code here uses import/export statements to keep the global scope clean. If your modern js relies on legacy js, you should access the legacy code via the `window` global scope object. (e.g. `var myList = new CXGN.List()` -> `var myList = new window.CXGN.List()`). Modern js will always be executed after legacy js. Code should be segregated into two types of files, script modules matching `js/source/*.js` or `js/scripts/**/*.js` and support modules matching `js/source/*/**/*.js`. 

## Legacy JS

Legacy (no-module) code is in the legacy folder. **Legacy code is executed in the global scope, and adding to it should be avoided.** To include legacy JS on a page, one should use the mason component `<& /util/import_legacy_javascript.mas, classes => ["CXGN.Effects", "CXGN.Phenome.Locus", "MochiKit.DOM"] &>` Where a file is specified by the relative path to a js file from the `$REPO/js/legacy` folder with slashes replaced by periods and no file extension (e.g. "$REPO/CXGN/Phenome/Locus.js" -> "CXGN.Phenome.Locus").