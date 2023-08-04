pathToYourConfigFile = 'C:\Users\kirca\Desktop\NeuroZIP\testing';
useGPU = 1;

run(fullfile(pathToYourConfigFile, 'sampleConfig.m'))

if ~(exist(ops.outputPath, 'dir'))
    cd(ops.fpath)
    mkdir results
    cd results
    mkdir plots
else
    if ~(exist(ops.plotPath, 'dir'))
        cd results
        mkdir plots
    end
end
rez.ops = ops;
rez                = compressData(ops);

%% save and clean up
save(fullfile(ops.outputPath, 'rez.mat'), 'rez', '-v7.3');

%TODO: 

%UMAP/DBSCAN/visualization (3 birds 1 stone baby!!)
%figure out way to somehow compare sets of eigenvectors

%graph template waveforms 
%increase PCs for clustering
%increase batch size
%see other TODOs
%RBF clustering