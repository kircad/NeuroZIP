clear ops

ops.GPU = 1;
ops.fproc = "C:\Users\kirca\Desktop\NeuroSqueeze\testing\temp_wh.dat";

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
ops.kmeansMaxIter = 75; % between maxK + maxK/2 and maxK + maxK/4

%RANDOM SETTINGS
ops.batchFactor = 5;
