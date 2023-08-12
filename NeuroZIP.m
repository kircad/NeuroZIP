pathToYourConfigFile = 'C:\Users\kirca\Desktop\NeuroZIP\testing';
useGPU = 1;

run(fullfile(pathToYourConfigFile, 'sampleConfig.m'))

%TODO INSERT OPTION TO PREPROCESS AND ONLY COMPRESS (W/O SPIKESORT)

if ~(exist(compressionOps.outputPath, 'dir'))
    cd(ops.fpath)
    mkdir results
    cd results
    mkdir plots
else
    if ~(exist(compressionOps.plotPath, 'dir'))
        cd results
        mkdir plots
    end
end
rez.compressionOps = compressionOps;
rez                = compressData(compressionOps);

%% save and clean up
save(fullfile(compressionOps.outputPath, 'rez.mat'), 'rez', '-v7.3');

%TODO: 

%graph template waveforms 
%increase PCs for clustering
%increase batch size
%see other TODOs
%RBF clustering

%USE MATLAB CLUSTER ENSEMBLE TOOLBOX-- LOTS OF GREAT FUNCTIONS
%UMAP @ batch level? Combine clusters across ALL batches? 
    %What (if any) iis the PC equivalent for UMAP?
    %what would a cluster mean? Use % overlap of clusters in 2D as metric
    %of unique information of batches? Try running clustering on results of
    %UMAP? 
    %RUN CLUSTERING ON BAD CLUSTERS-- FURTHER SUBDIVIDE
    %get rid of third PC?
    