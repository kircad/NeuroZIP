%TODOS (compare to original KS as ground truth after each step)
%see voice recording
%need to understand convolution and fft much better....
%lots of ground truth testing with established short + long datasets
%Take desired elements from KS1,2, and 3
%dynamic batch processing, chunking ,etc.
        
%https://towardsdatascience.com/17-clustering-algorithms-used-in-data-science-mining-49dbfa5bf69a
%https://www.geeksforgeeks.org/ml-determine-the-optimal-value-of-k-in-k-means-clustering/


%then do chunking thing + figure out how this affects postprocessing after seeing how well postprocessing works on long datasets(1st: write code that breaks up data and
%iterates through it, saving out merged clusters, then talk to nicolette
%about how she would go about manual merges, then recreate this (post-post-processing) in MATLAB
%Then implement parts of KS2/3 - some type of drift correction?
   
useGPU = 1; % do you have a GPU? Kilosorting 1000sec of 32chan simulated data takes 55 seconds on gtx 1080 + M2 SSD.

%fpath    = 'D:\ksdata\';
fpath = 'Z:\Brendon\SortingLongRecordings\LezioVolesACB10_J17\Vole_J17';
if ~exist(fpath, 'dir'); mkdir(fpath); end

% This part adds paths
addpath(genpath('C:\Users\kirca\Desktop\Kilosort1Edited')) % path to kilosort folder
addpath(genpath('C:\Users\kirca\Desktop\Kilosort1Edited\npy-matlab')) % path to npy-matlab scripts
pathToYourConfigFile = 'C:\Users\kirca\Desktop\Kilosort1Edited'; % for this example it's ok to leave this path inside the repo, but for your own config file you *must* put it somewhere else!  

% Run the configuration file, it builds the structure of options (ops)
run(fullfile(pathToYourConfigFile, 'config_Lezio.m'))

% This part runs the normal Kilosort processing on the simulated data
[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
rez                = compressData(rez, DATA, ops);
rez                = fitTemplates(rez, DATA, uproj);  % fit templates iteratively, TO DO ADD BATCH SELECTION STUFF FROM NOTEBOOK HERE
rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

% save python results file for Phy

rezToPhy(rez, fpath);

%% save and clean up
% save matlab results file for future use (although you should really only be using the manually validated spike_clusters.npy file)
save(fullfile(fpath,  'rez.mat'), 'rez', '-v7.3');

% remove temporary file
delete(ops.fproc);
%%
