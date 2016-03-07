/L/ Copyright (c) 2011-2014 Exxeleron GmbH
/-/
/-/ Licensed under the Apache License, Version 2.0 (the "License");
/-/ you may not use this file except in compliance with the License.
/-/ You may obtain a copy of the License at
/-/
/-/   http://www.apache.org/licenses/LICENSE-2.0
/-/
/-/ Unless required by applicable law or agreed to in writing, software
/-/ distributed under the License is distributed on an "AS IS" BASIS,
/-/ WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/-/ See the License for the specific language governing permissions and
/-/ limitations under the License.

/A/ DEVnet: Joanna Jarmulska
/V/ 3.0

/S/ tickHF adapter library for feedCsv:
/-/ Responsible for:
/-/ - publishing data in tickLF protocol
/-/ Notes:
/-/ - parsed data is published to tickLF component using interface functions <.tickLF.pubUpd> and <.tickLF.pubImg> (<tickLF.q>)
/-/ - filenames that match defined patterns are handled in two ways (those actions match tickLF interface actions):
/-/ -- image - completely replaces content of destination table with current input, expected file name pattern is YYYY.DD.MMDhh.mm.ss.uuu.table.img.csv, e.g. 2012.01.01D07.00.00.000.universe.img.csv
/-/ -- update - updates content of destination with current input, expected file name pattern is YYYY.DD.MMDhh.mm.ss.uuu.table.upd.csv, e.g. 2012.01.01D07.00.00.000.universe.upd.csv

/------------------------------------------------------------------------------/
system"l ",getenv[`EC_QSL_PATH],"/sl.q";
.sl.init[`tickLFPublisher];

/------------------------------------------------------------------------------/
/G/ supported publishing functions
.fcsv.p.supportedFunc:`img`upd;

/------------------------------------------------------------------------------/
/F/ Parses and publishes data as updates and images in tickLF format.
/P/ files:LIST PATH   - list of files to be parsed
/P/ config:DICTIONARY - with fileFormat, destTab, separator
/R/ :DICTIONARY - with ok and corrupted files: `ok`corrupted!(enlist `:data/file1.csv;enlist `:data/file2.csv)
/E/ .fcsv.processData[`:data/file1.csv`:data/file2.csv;`fileFormat`destTab`separator!("TSD";`universe;";")]
.fcsv.processData:{[files;config]
  //    ff::files;cc::config;
  .log.info[`LFPub] "Start processing #files:",string[count files]," for table ", string config`destTab;
  status:();
  status:status,{[f;config] 
    .event.dot[`LFPub;`.fcsv.p.processOneFile;(f;config);`error;`info`debug`warn;
      "Process data from file ",string[f]]}[;config]each files;
  aa::status;
  pendingFiles:files where status ~\: pendingStatus:`$"can't open connection to ",string[.fcsv.cfg`serverDst],", error: hop: Connection refused";
  status:status where not status ~\: pendingStatus;
  corruptedFiles:(files except pendingFiles) where (status~\:`error) or (not status~\:(::));
  okFiles:files except corruptedFiles,pendingFiles;
  :`ok`corrupted`pending!(okFiles;corruptedFiles;pendingFiles);
  };

/------------------------------------------------------------------------------/
/F/ Processes one file.
/P/ file:SYMBOL - file name
/P/ config:DICT - row from .fcsv.cfg.files
.fcsv.p.processOneFile:{[file;config]
  //    f::file; c::config;
  format:config`fileFormat;separator:config`separator;destTab:config`destTab;
  func:first .fcsv.p.supportedFunc@where .fcsv.p.supportedFunc in `$"." vs string last ` vs file;
  if[`~func;
    m:"file: ",string[file]," is not matching supported pattern ", .Q.s1[.fcsv.p.supportedFunc];
    'm
    ];
  data:$[not format~"deprecated"; .fcsv.p.read[file;format;separator;destTab];.fcsv.p.read2[file;config]];
  if[not count data;
    '"Any data couldn't be parsed from file ",string file;
    ];
  // convert to tickPlus format - list
  data2pub:value flip data;
  // convert to tickPlus func
  fsnames:string func;
  fsnames:upper[fsnames[0]],1_fsnames;
  func2pub:`$".tickLF.pub",fsnames;
  status:.pe.dot[.fcsv.p.pub;(func2pub;destTab;data2pub);{[x] .log.warn[`LFPub]"Error during data publishing: ",x;`$x}];
  status
  };

/------------------------------------------------------------------------------/
