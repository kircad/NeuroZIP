%fpath    = 'D:\ksdata\';
%fpath = 'Z:\Brendon\SortingLongRecordings\LezioVolesACB10_J17\Vole_J17';
fpath = "C:\Users\kirca_t5ih59c\Desktop\NeuroZIP\local_recordings\paired_boyden32c\419_1_7\recording\traces_cached_seg0.raw";

pathToYourConfigFile = 'C:\Users\kirca_t5ih59c\Desktop\NeuroZIP\neurozip-kilosort\edited_kilosort\configFiles'; % for this example it's ok to leave this path inside the repo, but for your own config file you *must* put it somewhere else!  

% Run the configuration file, it builds the structure of options (ops)
run(fullfile(pathToYourConfigFile, 'standard_config.m'))
outpath = fullfile(fpath, 'results');
 

% This part runs the normal Kilosort processing on the simulated data
profile on -memory
[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
compressionRez                = compressData(ops, rez.temp);
rez                = fitTemplates(rez, DATA, uproj, compressionRez.batchesToUse);  % fit templates iteratively
rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

% save python results file for Phy
profile off;
profsave(profile('info'), fullfile('C:\Users\kirca_t5ih59c\Desktop\NeuroZIP\profile_results'));
rezToPhy(rez, fpath);

%% save and clean up
% save matlab results file for future use (although you should really only be using the manually validated spike_clusters.npy file)
save(fullfile(fpath,  'rez.mat'), 'rez', '-v7.3');

% remove temporary file
delete(ops.fproc);
%%
