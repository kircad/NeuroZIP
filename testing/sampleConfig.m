clear ops

ops.GPU = 1;
ops.fpath = 'C:\Users\kirca\Desktop\NeuroZIP\testing'; %path to your PREPROCESSED .dat file folder
ops.fproc = fullfile(ops.fpath, "temp_wh.dat");
ops.outputPath = fullfile(ops.fpath, "results");
ops.plotPath = fullfile(ops.outputPath, "plots");

ops.Nchan = 32;
ops.NchanTOT = 34;
ops.batchSetting = 'dynamic';
ops.scaleproc = 200;
ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection		
ops.ForceMaxRAMforDat   = 20e9; % maximum RAM the algorithm will try to use; on Windows it will autodetect.
ops.NT                  = 128*1024+ ops.ntbuff;

%DYNAMIC SETTINGS
ops.maxK = 50;
ops.clusterThreshold = .5;
ops.batchPCS = 3;
ops.clustMin = 1;
ops.kmeansMaxIter = 150; % between maxK + maxK/2 and maxK + maxK/4
ops.plotDiagnostics = 1;
ops.plotTemplates = 1;
ops.pcmerge = 0;

%RANDOM SETTINGS
ops.batchFactor = 5;