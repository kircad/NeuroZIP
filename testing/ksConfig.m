clear ops
ops.GPU                 = 1; % whether to run this code on an Nvidia GPU (much faster, mexGPUall first)		
ops.parfor              = 0; % whether to use parfor to accelerate some parts of the algorithm		
ops.verbose             = 0; % whether to print command line progress		
ops.showfigures         = 1; % whether to plot figures during optimization		
		
ops.datatype            = 'dat';  % binary ('dat', 'bin') or 'openEphys'		
ops.fbinary             = fullfile(fpath, 'amplifier.dat'); % will be created for 'openEphys'		
ops.fproc               = fullfile(fpath, 'temp_wh.dat'); % residual from RAM of preprocessed data		
ops.root                = fpath; % 'openEphys' only: where raw files are		
% define the channel map as a filename (string) or simply an array		
ops.chanMap             = fullfile(fpath, 'chanMap.mat'); % make this file using createChannelMapFile.m		
% ops.chanMap = 1:ops.Nchan; % treated as linear probe if unavailable chanMap file		

ops.Nfilt               = 64;  % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)     		
ops.nNeighPC            = 12; % visualization only (Phy): number of channnels to mask the PCs, leave empty to skip (12)		
ops.nNeigh              = 16; % visualization only (Phy): number of neighboring templates to retain projections of (16)		
		
% options for channel whitening		
ops.whitening           = 'full'; % type of whitening (default 'full', for 'noSpikes' set options for spike detection below)		
ops.nSkipCov            = 1; % compute whitening matrix from every N-th batch (1)		
ops.whiteningRange      = 32; % how many channels to whiten together (Inf for whole probe whitening, should be fine if Nchan<=32)		
ops.CAR = true;

ops.criterionNoiseChannels = 0.2; % fraction of "noise" templates allowed to span all channel groups (see createChannelMapFile for more info). 		

% other options for controlling the model and optimization		
ops.Nrank               = 3;    % matrix rank of spike template model (3)		
ops.nfullpasses         = 6;    % number of complete passes through data during optimization (6)		
ops.maxFR               = 20000;  % maximum number of spikes to extract per batch (20000)		
ops.fshigh              = 200;   % frequency for high pass filtering		
% ops.fslow             = 2000;   % frequency for low pass filtering (optional)
ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection		
ops.scaleproc           = 200;   % int16 scaling of whitened data		
ops.NT                  = 128*1024+ ops.ntbuff;% this is the batch size (try decreasing if out of memory) (TODO FIGURE OUT BATCH LENGTH IN SECONDS)		
% for GPU should be multiple of 32 + ntbuff		
		
% the following options can improve/deteriorate results. 		
% when multiple values are provided for an option, the first two are beginning and ending anneal values, 		
% the third is the value used in the final pass. 		
ops.Th               = [4 10 10];    % threshold for detecting spikes on template-filtered data ([6 12 12])		
ops.lam              = [5 5 5];      % large means amplitudes are forced around the mean ([10 30 30])		
ops.nannealpasses    = 4;            % should be less than nfullpasses (4)		
ops.momentum         = 1./[20 400];  % start with high momentum and anneal (1./[20 1000])		
ops.shuffle_clusters = 1;            % allow merges and splits during optimization (1)		
ops.mergeT           = .1;           % upper threshold for merging (.1)		
ops.splitT           = .1;           % lower threshold for splitting (.1)		
ops.batchSetting = 'dynamic'; %options are random, linspace, variance, entropy(using eigenvalues?), numSpikes, dynamic, anything else will just use all batches
ops.spacing = 5; %NEED TO ALSO SET THIS IF LINSPACE OPTION IS SET
ops.batchFactor =  26; %if not using spacing, take numBatch/ops.batchFactor batches for template matching
ops.batchPCS = 3;
ops.maxK = 50;
ops.clusterThreshold = 0.5; %minimum silhouette score of a cluster - TODO use stdev?
ops.clustMin = 1; %minimum cluster size
%TO DO ADD SLEEP STATE, SNR, PCA CRITERION

% options for initializing spikes from data		
ops.initialize      = 'fromData';    %'fromData' or 'no'		
ops.spkTh           = -6;      % spike threshold in standard deviations (4)		
ops.loc_range       = [3  1];  % ranges to detect peaks; plus/minus in time and channel ([3 1])		
ops.long_range      = [30  6]; % ranges to detect isolated peaks ([30 6])		
ops.maskMaxChannels = 5;       % how many channels to mask up/down ([5])		
ops.crit            = .65;     % upper criterion for discarding spike repeates (0.65)		
ops.nFiltMax        = 10000;   % maximum "unique" spikes to consider (10000)		
		
% load predefined principal components (visualization only (Phy): used for features)		
dd                  = load('PCspikes2.mat'); % you might want to recompute this from your own data		
ops.wPCA            = dd.Wi(:,1:7);   % PCs
		
% options for posthoc merges (under construction)		
ops.fracse  = 0.1; % binning step along discriminant axis for posthoc merges (in units of sd)		
ops.epu     = Inf;		
		
ops.ForceMaxRAMforDat   = 20e9; % maximum RAM the algorithm will try to use; on Windows it will autodetect.
ops.batchesToUse = 50; %number of subsamples to use for template generation