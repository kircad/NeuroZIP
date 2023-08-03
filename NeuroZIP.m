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
save(fullfile(ops.fpath, 'rez.mat'), 'rez', '-v7.3');
savefig(fpath);
% remove temporary file
delete(ops.fproc);

%TODO: 
%tSNE implementation
%graph template waveforms 
%DBSCAN
%increase PCs for clustering
%increase batch size
%see other TODOs