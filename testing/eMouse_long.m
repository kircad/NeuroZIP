fpath = 'C:\Users\kirca\Desktop\NeuroZIP\testing';
pathToYourConfigFile = 'C:\Users\kirca\Desktop\NeuroZIP\testing\'; % for this example it's ok to leave this path inside the repo, but for your own config file you *must* put it somewhere else!  
testName = 'ampvarfrtest';
useGPU = 1;
gendata =  true;

if gendata
    make_eMouseChannelMap(fpath)
    longSimGen(fpath, useGPU, testName);
end

% Run the configuration file, it builds the structure of options (ops)
run(fullfile(pathToYourConfigFile, 'ksConfig.m'))
run(fullfile(pathToYourConfigFile, 'sampleConfig.m'))
outpath = fullfile(fpath, 'results');
 
[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
compressionRez                = compressData(compressionOps);
%savefig(fullfile(outpath, ops.batchSetting));
rez                = fitTemplates(rez, DATA, uproj, compressionRez.batchesToUse);  % fit templates iteratively
rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

rezToPhy(rez, outpath);
benchmark_simulationLong(rez, fullfile(fpath, 'eMouseGroundTruth.mat'))
%% save and clean up
% save matlab results file for future use (although you should really only be using the manually validated spike_clusters.npy file)
save(fullfile(outpath, 'rez.mat'), 'rez', '-v7.3');
savefig(fullfile(outpath));
% remove temporary file
delete(ops.fproc);