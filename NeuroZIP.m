pathToYourConfigFile = 'C:\Users\kirca\Desktop\NeuroZIP\testing';
useGPU = 1;

run(fullfile(pathToYourConfigFile, 'sampleConfig.m'))

if ~(exist(ops.outputPath, 'dir'))
    cd(ops.fpath)
    mkdir  results
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

%UMAP

%THEN kmeans

%then visualize

%graph template waveforms 
%DBSCAN
%increase PCs for clustering
%increase batch size
%see other TODOs
%RBF clustering