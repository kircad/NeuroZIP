clear compressionOps

compressionOps.GPU = 1;
compressionOps.fpath = 'C:\Users\kirca\Desktop\NeuroZIP\testing'; %path to your PREPROCESSED .dat file folder
compressionOps.fproc = fullfile(compressionOps.fpath, "temp_wh.dat");
compressionOps.outputPath = fullfile(compressionOps.fpath, "results");
compressionOps.plotPath = fullfile(compressionOps.outputPath, "plots");

compressionOps.Nchan = 32;
compressionOps.NchanTOT = 34;
compressionOps.batchSetting = 'random';
compressionOps.scaleproc = 200;
compressionOps.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection		
compressionOps.ForceMaxRAMforDat   = 20e9; % maximum RAM the algorithm will try to use; on Windows it will autodetect.
compressionOps.NT                  = 128*1024+ compressionOps.ntbuff;

%DYNAMIC SETTINGS
compressionOps.maxK = 50;
compressionOps.clusterThreshold = .5;
compressionOps.batchPCS = 3;
compressionOps.clustMin = 1;
compressionOps.kmeansMaxIter = 150; % between maxK + maxK/2 and maxK + maxK/4
compressionOps.plotDiagnostics = 1;
compressionOps.plotTemplates = 1;
compressionOps.pcmerge = 0;
compressionOps.iterativeOptimization = 0;
compressionOps.NchanDimKmeans = 1;
compressionOps.meanPCs = 0;
compressionOps.minOptimizationBatches = 20;
compressionOps.profileClusters = 1;

%RANDOM SETTINGS
compressionOps.batchFactor = 5;