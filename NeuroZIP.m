fpath = 'C:\Users\kirca\Desktop\NeuroSqueeze\testing'; %path to your PREPROCESSED .dat file

pathToYourConfigFile = 'C:\Users\kirca\Desktop\NeuroSqueeze\testing';
useGPU = 1;

run(fullfile(pathToYourConfigFile, 'sampleConfig.m'))
rez.ops = ops;
rez                = compressData(ops);

%% save and clean up
save(fullfile(fpath, 'rez.mat'), 'rez', '-v7.3');
savefig(fpath);
% remove temporary file
delete(ops.fproc);

%TODO: 
%tSNE implementation
%graph mastcosts
%graph template waveforms 
%DBSCAN
%increase PCs for clustering
%increase batch size
%see other TODOs