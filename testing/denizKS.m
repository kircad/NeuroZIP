useGPU = 1; % do you have a GPU? Kilosorting 1000sec of 32chan simulated data takes 55 seconds on gtx 1080 + M2 SSD.

%fpath    = 'D:\ksdata\';
%fpath = 'Z:\Brendon\SortingLongRecordings\LezioVolesACB10_J17\Vole_J17';
fpath = 'C:\Users\kirca\Desktop\NeuroZIP';

pathToYourConfigFile = 'C:\Users\kirca\Desktop\NeuroZIP\testing\config'; % for this example it's ok to leave this path inside the repo, but for your own config file you *must* put it somewhere else!  

% Run the configuration file, it builds the structure of options (ops)
run(fullfile(pathToYourConfigFile, 'config_Lezio.m'))
run(fullfile(pathToYourConfigFile, 'sampleConfig.m'))
outpath = fullfile(fpath, 'results');
 

% This part runs the normal Kilosort processing on the simulated data
[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
compressionRez                = compressData(compressionOps, rez.temp);
rez                = fitTemplates(rez, DATA, uproj, compressionRez.batchesToUse);  % fit templates iteratively
rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

% save python results file for Phy

rezToPhy(rez, fpath);

%% save and clean up
% save matlab results file for future use (although you should really only be using the manually validated spike_clusters.npy file)
save(fullfile(fpath,  'rez.mat'), 'rez', '-v7.3');

% remove temporary file
delete(ops.fproc);
%%
