
useGPU = 1; % do you have a GPU? Kilosorting 1000sec of 32chan simulated data takes 55 seconds on gtx 1080 + M2 SSD.

fpath    = 'C:\Users\kirca\Desktop\kilosortData\amplifierdat\';
if ~exist(fpath, 'dir'); mkdir(fpath); end

% This part adds paths
addpath(genpath('C:\Users\kirca\Desktop\Lab\Kilosort1original')) % path to kilosort folder
addpath(genpath('C:\Users\kirca\Desktop\Lab\Kilosort1original')) % path to npy-matlab scripts
pathToYourConfigFile = 'C:\Users\kirca\Desktop\kilosort1Edited\configFiles';

% Run the configuration file, it builds the structure of options (ops)
run(fullfile(pathToYourConfigFile, 'leventhalconfig.m'))

[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
rez                = compressData(rez, DATA, ops);
rez                = fitTemplates(rez, DATA, uproj);  % fit templates iteratively
rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

% save python results file for Phy

cd(fpath)
rezToPhy(rez, fpath);
fprintf('Kilosort took %2.2f seconds vs 72.77 seconds on GTX 1080 + M2 SSD \n', toc)


rez = merge_posthoc2(rez);

cd(fpath)

%% save and clean up
% save matlab results file for future use (although you should really only be using the manually validated spike_clusters.npy file)
save(fullfile(fpath,  'rez.mat'), 'rez', '-v7.3');

% remove temporary file
delete(ops.fproc);
%%
