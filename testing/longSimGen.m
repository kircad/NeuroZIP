function longSimGen(fpath, useGPU, mode)
% this script makes binary file of simulated eMouse recording

%%RUN ONCE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% you can play with the parameters just below here to achieve a signal more similar to your own data!!! 
mu_mean   = 15; % mean of mean spike amplitudes. 15 should contain enough clustering errors to be instructive (in Phy). 20 is good quality data, 10 will miss half the neurons, 
t_record  = 1000;
fr_bounds = [1 10]; % min and max of firing rates ([1 10])
tsmooth   = 3; % gaussian smooth the noise with sig = this many samples (increase to make it harder) (3)
chsmooth  = 1; % smooth the noise across channels too, with this sig (increase to make it harder) (1)
amp_std   = .25; % standard deviation of single spike amplitude variability (increase to make it harder, technically std of gamma random variable of mean 1) (.25)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if (mode == "newunits3")
    numUnitsInit = 1;
elseif (mode == "oneUnit")
    numUnitsInit = 1;
elseif (mode == "zero")
    numUnitsInit = 0;
else
    numUnitsInit = 30;
end
if useGPU
    parallel.gpu.rng('default');
    parallel.gpu.rng(10191);  % set the seed of the random number generator
end
wavidxs = randperm(76,numUnitsInit); 

rng('default');
rng(101);  % set the seed of the random number generator


dat = load('simulation_parameters'); % these are inside Kilosort repo
fs  = dat.fs; % sampling rate
wav = dat.waves; % mean waveforms for all neurons
wav = wav(:,:, wavidxs); %picks 30 random waveforms from list (generated from real dataset in Pachitariu lab)

Nchan = numel(dat.xc) + 2; % we  add two fake dead channels
NN = size(wav,3); % number of neurons

chanMap = [33 34 8 10 12 14 16 18 20 22 24 26 28 30 32 ...
    7 9 11 13 15 17 19 21 23 25 27 29 31 1 2 3 4 5 6]; % this is the fake channel map I made

invChanMap(chanMap) = [1:34]; %invert the  channel map here (why? also doesnnt seem to be inverted)

%%
mu = mu_mean * (1 + (rand(NN,1) - 0.5)); % create variability in mean amplitude
fr = fr_bounds(1) + (fr_bounds(2)-fr_bounds(1)) * rand(NN,1); % create variability in firing rates FIRING RATE OF EACH NEURON

% totfr = sum(fr); % total firing rate

spk_times = [];
clu = [];
for j = 1:length(fr)
    dspks = int64(geornd(1/(fs/fr(j)), ceil(2*fr(j)*t_record),1)); %dspks are ISIs
    dspks(dspks<ceil(fs * 2/1000)) = [];  % remove ISIs below the refractory period
    res = cumsum(dspks); %res = actual spike times: summing up ISIs tells you what timepoint each spike was at
    spk_times = cat(1, spk_times, res);
    clu = cat(1, clu, j*ones(numel(res), 1)); %cluster IDs for each generated spike
end
[spk_times, isort] = sort(spk_times); %ALL spike times sorted chronologically, regardless of cluster
clu = clu(isort); %now align their associated clusters
clu       = clu(spk_times<t_record*fs);
spk_times = spk_times(spk_times<t_record*fs); %remove spike times out of range (why generate for 2 * time * frequency? -- has to do with fft?)
nspikes = numel(spk_times);
%basically the snippet above generates spike times by first simulating
%ISIs: geometric distribution (array of size ceil(2*fr(j)*t_record) where
%each element is the number of trials it would take for a success, defined
%by fr(j)/fs. This makes sense because fr(j)/fs is the chance neuron j will fire at a given sample, and thus the amount of samples it takes 
%to get there can be described using a bernuoli distribution. Size of distribution is determined by 2 * fr(j) * t_record because
%the NUMBER of neuron j ISIs in a recording will be determined by how often neuron j fires, thus generate full distribution and truncate later. Where does 2 come from?
amps = gamrnd(1/amp_std^2,amp_std^2, nspikes,1); % this generates single spike amplitude variability of mean 1 AMPLITUDE VARIANCE

%
buff = 128;
NT   = 4 * fs + buff; % batch size + buffer. data is basically generated (NT-buff)/fs seconds at a time (seems to be hardcoded to 4 though)
%now we have spike times, clusters, and templates, time to generate data 
fidW     = fopen(fullfile(fpath, 'amplifier.dat'), 'w');

t_all    = 0;
while t_all<t_record  %for each batch (hardcoded to 4s)
    if useGPU
        enoise = gpuArray.randn(NT, Nchan, 'single'); %literally random data of size Nchan x NT : noise
    else
        enoise = randn(NT, Nchan, 'single');
    end
    if t_all>0
        enoise(1:buff, :) = enoise_old(NT-buff + [1:buff], :);
    end

    dat = enoise; %first set data equal to noise
    dat = my_conv2(dat, [tsmooth chsmooth], [1 2]); %this is to smoothen noise across time and channels : uses convolution - higher is harder becuase smoothening suppresses the short-term fluctuations we care about
    dat = zscore(dat, 1, 1);
    dat = gather_try(dat);

    if t_all>0
        dat(1:buff/2, :) = dat_old(NT-buff/2 + [1:buff/2], :);
    end

    dat(:, [1 2]) = 0; % these are the "dead" channels

    % now we add spikes on non-dead channels. 
    ibatch = (spk_times >= t_all*fs) & (spk_times < t_all*fs+NT-buff); %spikes in this time range 
    ts = spk_times(ibatch) - t_all*fs; %put into range of batch
    ids = clu(ibatch); %which clusters are firing in this batch
    am = amps(ibatch); %amplitudes of spikes in this batch

    for i = 1:length(ts) %for all spikes in this batch
       dat(ts(i) + int64([1:82]), 2 + [1:32]) = dat(ts(i) + int64([1:82]), 2 + [1:32]) +...
           mu(ids(i)) * am(i) * wav(:,:,ids(i)); %for timepoints ts(i) + 1:82 and channels 1:32, add template waveform
    end

    dat_old    =  dat;    
    dat = int16(200 * dat); %scale to int16 range
    fwrite(fidW, dat(1:(NT-buff),invChanMap)', 'int16');
    t_all = t_all + (NT-buff)/fs;

    enoise_old = enoise;
end

%%
%NOW GENERATE MODIFIED DATA ON TOP-- NEW PARAMS, ETC. (add existing numSamps to all timepoints, make sure cluster assignments stay same, etc.)

if (mode == "frtest1") %TODO TEST DATA GEN HERE-- GETTING MUCH WORSE RESULTS THAN EXPECTED ACROSS THE BOARD
    t_record2  = 1000;
    tot_record = t_record + t_record2;
    fr_bounds = [20 30]; % this has effect of ALL neuron firing rates suddenly decreasing on average 
    fr = fr_bounds(1) + (fr_bounds(2)-fr_bounds(1)) * rand(NN,1); % create variability in firing rates FIRING RATE OF EACH NEURON
    spk_timesnew = [];
    clunew = [];
    for j = 1:length(fr)
        dspks = int64(geornd(1/(fs/fr(j)), ceil(2*fr(j)*t_record),1)); %dspks are ISIs
        dspks(dspks<ceil(fs * 2/1000)) = [];  % remove ISIs below the refractory period
        res = cumsum(dspks); %res = actual spike times: summing up ISIs tells you what timepoint each spike was at
        spk_times = cat(1, spk_times, res);
        clu = cat(1, clu, j*ones(numel(res), 1)); %cluster IDs for each generated spike
    end
    [spk_timesnew, isort] = sort(spk_timesnew); %ALL spike times sorted chronologically, regardless of cluster
    clunew = clunew(isort); %now align their associated clusters
    clunew       = clunew(spk_timesnew<t_record2*fs);
    spk_timesnew = spk_timesnew(spk_timesnew<t_record2*fs); %remove spike times out of range (why generate for 2 * time * frequency? -- has to do with fft?)
    nspikesnew = numel(spk_timesnew);
    %basically the snippet above generates spike times by first simulating
    %ISIs: geometric distribution (array of size ceil(2*fr(j)*t_record) where
    %each element is the number of trials it would take for a success, defined
    %by fr(j)/fs. This makes sense because fr(j)/fs is the chance neuron j will fire at a given sample, and thus the amount of samples it takes 
    %to get there can be described using a bernuoli distribution. Size of distribution is determined by 2 * fr(j) * t_record because
    %the NUMBER of neuron j ISIs in a recording will be determined by how often neuron j fires, thus generate full distribution and truncate later. Where does 2 come from?
    amps = gamrnd(1/amp_std^2,amp_std^2, nspikesnew,1); % this generates single spike amplitude variability of mean 1 AMPLITUDE VARIANCE
    spk_timesnew = spk_timesnew + (fs * t_record); %adjusting for existing data before it
    while t_all<tot_record  %for each batch (hardcoded to 4s) TODO change batch sizes?
        if useGPU
            enoise = gpuArray.randn(NT, Nchan, 'single'); %literally random data of size Nchan x NT : noise
        else
            enoise = randn(NT, Nchan, 'single');
        end
        if t_all>0
            enoise(1:buff, :) = enoise_old(NT-buff + [1:buff], :);
        end

        dat = enoise; %first set data equal to noise
        dat = my_conv2(dat, [tsmooth chsmooth], [1 2]); %this is to smoothen noise across time and channels : uses convolution - higher is harder becuase smoothening suppresses the short-term fluctuations we care about
        dat = zscore(dat, 1, 1);
        dat = gather_try(dat);

        if t_all>0
            dat(1:buff/2, :) = dat_old(NT-buff/2 + [1:buff/2], :);
        end

        dat(:, [1 2]) = 0; % these are the "dead" channels

        % now we add spikes on non-dead channels. 
        ibatch =(spk_timesnew >= t_all*fs) & (spk_timesnew < t_all*fs+NT-buff); %spikes in this time range 
        ts = spk_timesnew(ibatch) - t_all*fs; %put into range of batch
        ids = clunew(ibatch); %which clusters are firing in this batch
        am = amps(ibatch); %amplitudes of spikes in this batch

        for i = 1:length(ts) %for all spikes in this batch
           dat(ts(i) + int64([1:82]), 2 + [1:32]) = dat(ts(i) + int64([1:82]), 2 + [1:32]) +...
               mu(ids(i)) * am(i) * wav(:,:,ids(i)); %for timepoints ts(i) + 1:82 and channels 1:32, add template waveform TODO CHECK THIS
        end

        dat_old    =  dat;    
        dat = int16(200 * dat); %scale to int16 range
        fwrite(fidW, dat(1:(NT-buff),invChanMap)', 'int16');
        t_all = t_all + (NT-buff)/fs;

        enoise_old = enoise;
    end
    clu = cat(1,clu, clunew);
    spk_times = cat(1,spk_times, spk_timesnew);
end

if (mode == "ampvarfrtest")
    t_record2  = 1000;
    tot_record = t_record + t_record2;
    spk_timesnew = [];
    clunew = [];
    amp_std   = .5; % standard deviation of single spike amplitude variability (increase to make it harder, technically std of gamma random variable of mean 1) (.25)
    fr_bounds = [20 30]; % this has effect of ALL neuron firing rates suddenly decreasing on average 
    fr = fr_bounds(1) + (fr_bounds(2)-fr_bounds(1)) * rand(NN,1); % create variability in firing rates FIRING RATE OF EACH NEURON
    for j = 1:length(fr)
        dspks = int64(geornd(1/(fs/fr(j)), ceil(2*fr(j)*t_record),1)); %dspks are ISIs
        dspks(dspks<ceil(fs * 2/1000)) = [];  % remove ISIs below the refractory period
        res = cumsum(dspks); %res = actual spike times: summing up ISIs tells you what timepoint each spike was at
        spk_times = cat(1, spk_times, res);
        clu = cat(1, clu, j*ones(numel(res), 1)); %cluster IDs for each generated spike
    end
    [spk_timesnew, isort] = sort(spk_timesnew); %ALL spike times sorted chronologically, regardless of cluster
    clunew = clunew(isort); %now align their associated clusters
    clunew       = clunew(spk_timesnew<t_record2*fs);
    spk_timesnew = spk_timesnew(spk_timesnew<t_record2*fs); %remove spike times out of range (why generate for 2 * time * frequency? -- has to do with fft?)
    nspikesnew = numel(spk_timesnew);
    %basically the snippet above generates spike times by first simulating
    %ISIs: geometric distribution (array of size ceil(2*fr(j)*t_record) where
    %each element is the number of trials it would take for a success, defined
    %by fr(j)/fs. This makes sense because fr(j)/fs is the chance neuron j will fire at a given sample, and thus the amount of samples it takes 
    %to get there can be described using a bernuoli distribution. Size of distribution is determined by 2 * fr(j) * t_record because
    %the NUMBER of neuron j ISIs in a recording will be determined by how often neuron j fires, thus generate full distribution and truncate later. Where does 2 come from?
    amps = gamrnd(1/amp_std^2,amp_std^2, nspikesnew,1); % this generates single spike amplitude variability of mean 1 AMPLITUDE VARIANCE
    spk_timesnew = spk_timesnew + (fs * t_record); %adjusting for existing data before it
    while t_all<tot_record  %for each batch (hardcoded to 4s) TODO change batch sizes?
        if useGPU
            enoise = gpuArray.randn(NT, Nchan, 'single'); %literally random data of size Nchan x NT : noise
        else
            enoise = randn(NT, Nchan, 'single');
        end
        if t_all>0
            enoise(1:buff, :) = enoise_old(NT-buff + [1:buff], :);
        end

        dat = enoise; %first set data equal to noise
        dat = my_conv2(dat, [tsmooth chsmooth], [1 2]); %this is to smoothen noise across time and channels : uses convolution - higher is harder becuase smoothening suppresses the short-term fluctuations we care about
        dat = zscore(dat, 1, 1);
        dat = gather_try(dat);

        if t_all>0
            dat(1:buff/2, :) = dat_old(NT-buff/2 + [1:buff/2], :);
        end

        dat(:, [1 2]) = 0; % these are the "dead" channels

        % now we add spikes on non-dead channels. 
        ibatch =(spk_timesnew >= t_all*fs) & (spk_timesnew < t_all*fs+NT-buff); %spikes in this time range 
        ts = spk_timesnew(ibatch) - t_all*fs; %put into range of batch
        ids = clunew(ibatch); %which clusters are firing in this batch
        am = amps(ibatch); %amplitudes of spikes in this batch

        for i = 1:length(ts) %for all spikes in this batch
           dat(ts(i) + int64([1:82]), 2 + [1:32]) = dat(ts(i) + int64([1:82]), 2 + [1:32]) +...
               mu(ids(i)) * am(i) * wav(:,:,ids(i)); %for timepoints ts(i) + 1:82 and channels 1:32, add template waveform TODO CHECK THIS
        end

        dat_old    =  dat;    
        dat = int16(200 * dat); %scale to int16 range
        fwrite(fidW, dat(1:(NT-buff),invChanMap)', 'int16');
        t_all = t_all + (NT-buff)/fs;

        enoise_old = enoise;
    end
    clu = cat(1,clu, clunew);
    spk_times = cat(1,spk_times, spk_timesnew);
end

if (mode == "ampvartest")
    t_record2  = 1000;
    tot_record = t_record + t_record2;
    spk_timesnew = [];
    clunew = [];
    amp_std   = .5; % standard deviation of single spike amplitude variability (increase to make it harder, technically std of gamma random variable of mean 1) (.25)
    for j = 1:length(fr)
        dspks = int64(geornd(1/(fs/fr(j)), ceil(2*fr(j)*t_record),1)); %dspks are ISIs
        dspks(dspks<ceil(fs * 2/1000)) = [];  % remove ISIs below the refractory period
        res = cumsum(dspks); %res = actual spike times: summing up ISIs tells you what timepoint each spike was at
        spk_times = cat(1, spk_times, res);
        clu = cat(1, clu, j*ones(numel(res), 1)); %cluster IDs for each generated spike
    end
    [spk_timesnew, isort] = sort(spk_timesnew); %ALL spike times sorted chronologically, regardless of cluster
    clunew = clunew(isort); %now align their associated clusters
    clunew       = clunew(spk_timesnew<t_record2*fs);
    spk_timesnew = spk_timesnew(spk_timesnew<t_record2*fs); %remove spike times out of range (why generate for 2 * time * frequency? -- has to do with fft?)
    nspikesnew = numel(spk_timesnew);
    %basically the snippet above generates spike times by first simulating
    %ISIs: geometric distribution (array of size ceil(2*fr(j)*t_record) where
    %each element is the number of trials it would take for a success, defined
    %by fr(j)/fs. This makes sense because fr(j)/fs is the chance neuron j will fire at a given sample, and thus the amount of samples it takes 
    %to get there can be described using a bernuoli distribution. Size of distribution is determined by 2 * fr(j) * t_record because
    %the NUMBER of neuron j ISIs in a recording will be determined by how often neuron j fires, thus generate full distribution and truncate later. Where does 2 come from?
    amps = gamrnd(1/amp_std^2,amp_std^2, nspikesnew,1); % this generates single spike amplitude variability of mean 1 AMPLITUDE VARIANCE
    spk_timesnew = spk_timesnew + (fs * t_record); %adjusting for existing data before it
    while t_all<tot_record  %for each batch (hardcoded to 4s) TODO change batch sizes?
        if useGPU
            enoise = gpuArray.randn(NT, Nchan, 'single'); %literally random data of size Nchan x NT : noise
        else
            enoise = randn(NT, Nchan, 'single');
        end
        if t_all>0
            enoise(1:buff, :) = enoise_old(NT-buff + [1:buff], :);
        end

        dat = enoise; %first set data equal to noise
        dat = my_conv2(dat, [tsmooth chsmooth], [1 2]); %this is to smoothen noise across time and channels : uses convolution - higher is harder becuase smoothening suppresses the short-term fluctuations we care about
        dat = zscore(dat, 1, 1);
        dat = gather_try(dat);

        if t_all>0
            dat(1:buff/2, :) = dat_old(NT-buff/2 + [1:buff/2], :);
        end

        dat(:, [1 2]) = 0; % these are the "dead" channels

        % now we add spikes on non-dead channels. 
        ibatch =(spk_timesnew >= t_all*fs) & (spk_timesnew < t_all*fs+NT-buff); %spikes in this time range 
        ts = spk_timesnew(ibatch) - t_all*fs; %put into range of batch
        ids = clunew(ibatch); %which clusters are firing in this batch
        am = amps(ibatch); %amplitudes of spikes in this batch

        for i = 1:length(ts) %for all spikes in this batch
           dat(ts(i) + int64([1:82]), 2 + [1:32]) = dat(ts(i) + int64([1:82]), 2 + [1:32]) +...
               mu(ids(i)) * am(i) * wav(:,:,ids(i)); %for timepoints ts(i) + 1:82 and channels 1:32, add template waveform TODO CHECK THIS
        end

        dat_old    =  dat;    
        dat = int16(200 * dat); %scale to int16 range
        fwrite(fidW, dat(1:(NT-buff),invChanMap)', 'int16');
        t_all = t_all + (NT-buff)/fs;

        enoise_old = enoise;
    end
    clu = cat(1,clu, clunew);
    spk_times = cat(1,spk_times, spk_timesnew);
end

if (mode == "newunits1")
    newUnits = 5;
    t_record2  = 500;
    tot_record = t_record + t_record2;
    spk_timesnew = [];
    clunew = [];
    fr_boundsnew = [25 30]; % this has effect of ALL neuron firing rates suddenly decreasing on average 
    frnew = fr_boundsnew(1) + (fr_boundsnew(2)-fr_boundsnew(1)) * rand(newUnits,1); % create variability in firing rates of NEW NEURONS
    for j = 1:length(fr) 
        dspks = int64(geornd(1/(fs/fr(j)), ceil(2*fr(j)*t_record2),1)); %dspks are ISIs
        dspks(dspks<ceil(fs * 2/1000)) = [];  % remove ISIs below the refractory period
        res = cumsum(dspks); %res = actual spike times: summing up ISIs tells you what timepoint each spike was at
        spk_timesnew = cat(1, spk_timesnew, res);
        clunew = cat(1, clunew, j*ones(numel(res), 1)); %cluster IDs for each generated spike
    end
    for j = 1:length(frnew) %now adding in new units 
        dspks = int64(geornd(1/(fs/frnew(j)), ceil(2*frnew(j)*t_record2),1)); %dspks are ISIs
        dspks(dspks<ceil(fs * 2/1000)) = [];  % remove ISIs below the refractory period
        res = cumsum(dspks); %res = actual spike times: summing up ISIs tells you what timepoint each spike was at
        spk_timesnew = cat(1, spk_timesnew, res);
        clunew = cat(1, clunew, (j + NN)*ones(numel(res), 1)); %adding NN to account for new cluID
    end
    newidxrange = setdiff(1:60,wavidxs);
    dat = load('simulation_parameters');
    wavnew = dat.waves;
    wavnew = wavnew(:,:,newidxrange(randperm(size(newidxrange,2),5)));
    [spk_timesnew, isort] = sort(spk_timesnew); %ALL spike times sorted chronologically, regardless of cluster
    clunew = clunew(isort); %now align their associated clusters
    clunew       = clunew(spk_timesnew<t_record2*fs);
    spk_timesnew = spk_timesnew(spk_timesnew<t_record2*fs); %remove spike times out of range (why generate for 2 * time * frequency? -- has to do with fft?)
    nspikesnew = numel(spk_timesnew);
    amps = gamrnd(1/amp_std^2,amp_std^2, nspikesnew,1); % this generates single spike amplitude variability of mean 1 AMPLITUDE VARIANCE
    spk_timesnew = spk_timesnew + (fs * t_record); %adjusting for existing data before it
    munew = mu_mean * (1 + (rand(newUnits,1) - 0.5));
    while t_all<tot_record  %for each batch (hardcoded to 4s) TODO change batch sizes?
        if useGPU
            enoise = gpuArray.randn(NT, Nchan, 'single'); %literally random data of size Nchan x NT : noise
        else
            enoise = randn(NT, Nchan, 'single');
        end
        if t_all>0
            enoise(1:buff, :) = enoise_old(NT-buff + [1:buff], :);
        end

        dat = enoise; %first set data equal to noise
        dat = my_conv2(dat, [tsmooth chsmooth], [1 2]); %this is to smoothen noise across time and channels : uses convolution - higher is harder becuase smoothening suppresses the short-term fluctuations we care about
        dat = zscore(dat, 1, 1);
        dat = gather_try(dat);

        if t_all>0
            dat(1:buff/2, :) = dat_old(NT-buff/2 + [1:buff/2], :);
        end

        dat(:, [1 2]) = 0; % these are the "dead" channels

        % now we add spikes on non-dead channels. 
        ibatch =(spk_timesnew >= t_all*fs) & (spk_timesnew < t_all*fs+NT-buff); %spikes in this time range 
        ts = spk_timesnew(ibatch) - t_all*fs; %put into range of batch
        ids = clunew(ibatch); %which clusters are firing in this batch
        am = amps(ibatch); %amplitudes of spikes in this batch

        for i = 1:length(ts) %for all spikes in this batch
            if (ids(i) > 30)
                dat(ts(i) + int64([1:82]), 2 + [1:32]) = dat(ts(i) + int64([1:82]), 2 + [1:32]) +...
                munew((ids(i) - NN)) * am(i) * wavnew(:,:,(ids(i) - NN)); %for timepoints ts(i) + 1:82 and channels 1:32, add template waveform TODO CHECK THIS
            else
                dat(ts(i) + int64([1:82]), 2 + [1:32]) = dat(ts(i) + int64([1:82]), 2 + [1:32]) +...
               mu(ids(i)) * am(i) * wav(:,:,ids(i)); %for timepoints ts(i) + 1:82 and channels 1:32, add template waveform TODO CHECK THIS
            end
        end

        dat_old    =  dat;    
        dat = int16(200 * dat); %scale to int16 range
        fwrite(fidW, dat(1:(NT-buff),invChanMap)', 'int16');
        t_all = t_all + (NT-buff)/fs;

        enoise_old = enoise;
    end
    clu = cat(1,clu, clunew);
    spk_times = cat(1,spk_times, spk_timesnew);
end

if (mode == "newunits2")
    newUnits = 5;
    t_record2  = 1000;
    tot_record = t_record + t_record2;
    spk_timesnew = [];
    clunew = [];
    fr_boundsnew = [1 10];
    frnew = fr_boundsnew(1) + (fr_boundsnew(2)-fr_boundsnew(1)) * rand(newUnits,1); % create variability in firing rates of NEW NEURONS
    for j = 1:length(fr) 
        dspks = int64(geornd(1/(fs/fr(j)), ceil(2*fr(j)*t_record2),1)); %dspks are ISIs
        dspks(dspks<ceil(fs * 2/1000)) = [];  % remove ISIs below the refractory period
        res = cumsum(dspks); %res = actual spike times: summing up ISIs tells you what timepoint each spike was at
        spk_timesnew = cat(1, spk_timesnew, res);
        clunew = cat(1, clunew, j*ones(numel(res), 1)); %cluster IDs for each generated spike
    end
    for j = 1:length(frnew) %now adding in new units 
        dspks = int64(geornd(1/(fs/frnew(j)), ceil(2*frnew(j)*t_record2),1)); %dspks are ISIs
        dspks(dspks<ceil(fs * 2/1000)) = [];  % remove ISIs below the refractory period
        res = cumsum(dspks); %res = actual spike times: summing up ISIs tells you what timepoint each spike was at
        spk_timesnew = cat(1, spk_timesnew, res);
        clunew = cat(1, clunew, (j + NN)*ones(numel(res), 1)); %adding NN to account for new cluID
    end
    newidxrange = setdiff(1:60,wavidxs);
    dat = load('simulation_parameters');
    wavnew = dat.waves;
    wavnew = wavnew(:,:,newidxrange(randperm(size(newidxrange,2),5)));
    [spk_timesnew, isort] = sort(spk_timesnew); %ALL spike times sorted chronologically, regardless of cluster
    clunew = clunew(isort); %now align their associated clusters
    clunew       = clunew(spk_timesnew<t_record2*fs);
    spk_timesnew = spk_timesnew(spk_timesnew<t_record2*fs); %remove spike times out of range (why generate for 2 * time * frequency? -- has to do with fft?)
    nspikesnew = numel(spk_timesnew);
    amps = gamrnd(1/amp_std^2,amp_std^2, nspikesnew,1); % this generates single spike amplitude variability of mean 1 AMPLITUDE VARIANCE
    spk_timesnew = spk_timesnew + (fs * t_record); %adjusting for existing data before it
    munew = mu_mean * (1 + (rand(newUnits,1) - 0.5));
    while t_all<tot_record  %for each batch (hardcoded to 4s) TODO change batch sizes?
        if useGPU
            enoise = gpuArray.randn(NT, Nchan, 'single'); %literally random data of size Nchan x NT : noise
        else
            enoise = randn(NT, Nchan, 'single');
        end
        if t_all>0
            enoise(1:buff, :) = enoise_old(NT-buff + [1:buff], :);
        end

        dat = enoise; %first set data equal to noise
        dat = my_conv2(dat, [tsmooth chsmooth], [1 2]); %this is to smoothen noise across time and channels : uses convolution - higher is harder becuase smoothening suppresses the short-term fluctuations we care about
        dat = zscore(dat, 1, 1);
        dat = gather_try(dat);

        if t_all>0
            dat(1:buff/2, :) = dat_old(NT-buff/2 + [1:buff/2], :);
        end

        dat(:, [1 2]) = 0; % these are the "dead" channels

        % now we add spikes on non-dead channels. 
        ibatch =(spk_timesnew >= t_all*fs) & (spk_timesnew < t_all*fs+NT-buff); %spikes in this time range 
        ts = spk_timesnew(ibatch) - t_all*fs; %put into range of batch
        ids = clunew(ibatch); %which clusters are firing in this batch
        am = amps(ibatch); %amplitudes of spikes in this batch

        for i = 1:length(ts) %for all spikes in this batch
            if (ids(i) > 30)
                dat(ts(i) + int64([1:82]), 2 + [1:32]) = dat(ts(i) + int64([1:82]), 2 + [1:32]) +...
                munew((ids(i) - NN)) * am(i) * wavnew(:,:,(ids(i) - NN)); %for timepoints ts(i) + 1:82 and channels 1:32, add template waveform TODO CHECK THIS
            else
                dat(ts(i) + int64([1:82]), 2 + [1:32]) = dat(ts(i) + int64([1:82]), 2 + [1:32]) +...
               mu(ids(i)) * am(i) * wav(:,:,ids(i)); %for timepoints ts(i) + 1:82 and channels 1:32, add template waveform TODO CHECK THIS
            end
        end

        dat_old    =  dat;    
        dat = int16(200 * dat); %scale to int16 range
        fwrite(fidW, dat(1:(NT-buff),invChanMap)', 'int16');
        t_all = t_all + (NT-buff)/fs;

        enoise_old = enoise;
    end
    clu = cat(1,clu, clunew);
    spk_times = cat(1,spk_times, spk_timesnew);
end

if (mode == "newunits3")
    newUnits = 1;
    t_record2  = 1000;
    tot_record = t_record + t_record2;
    spk_timesnew = [];
    clunew = [];
    fr_boundsnew = [1 10];
    frnew = fr_boundsnew(1) + (fr_boundsnew(2)-fr_boundsnew(1)) * rand(newUnits,1); % create variability in firing rates of NEW NEURONS
    for j = 1:length(frnew) %now adding in new units 
        dspks = int64(geornd(1/(fs/frnew(j)), ceil(2*frnew(j)*t_record2),1)); %dspks are ISIs
        dspks(dspks<ceil(fs * 2/1000)) = [];  % remove ISIs below the refractory period
        res = cumsum(dspks); %res = actual spike times: summing up ISIs tells you what timepoint each spike was at
        spk_timesnew = cat(1, spk_timesnew, res);
        clunew = cat(1, clunew, (j + NN)*ones(numel(res), 1)); %adding NN to account for new cluID
    end
    newidxrange = setdiff(1:60,wavidxs);
    dat = load('simulation_parameters');
    wavnew = dat.waves;
    wavnew = wavnew(:,:,newidxrange(randperm(size(newidxrange,2),5)));
    [spk_timesnew, isort] = sort(spk_timesnew); %ALL spike times sorted chronologically, regardless of cluster
    clunew = clunew(isort); %now align their associated clusters
    clunew       = clunew(spk_timesnew<t_record2*fs);
    spk_timesnew = spk_timesnew(spk_timesnew<t_record2*fs); %remove spike times out of range (why generate for 2 * time * frequency? -- has to do with fft?)
    nspikesnew = numel(spk_timesnew);
    amps = gamrnd(1/amp_std^2,amp_std^2, nspikesnew,1); % this generates single spike amplitude variability of mean 1 AMPLITUDE VARIANCE
    spk_timesnew = spk_timesnew + (fs * t_record); %adjusting for existing data before it
    munew = mu_mean * (1 + (rand(newUnits,1) - 0.5));
    while t_all<tot_record  %for each batch (hardcoded to 4s) TODO change batch sizes?
        if useGPU
            enoise = gpuArray.randn(NT, Nchan, 'single'); %literally random data of size Nchan x NT : noise
        else
            enoise = randn(NT, Nchan, 'single');
        end
        if t_all>0
            enoise(1:buff, :) = enoise_old(NT-buff + [1:buff], :);
        end

        dat = enoise; %first set data equal to noise
        dat = my_conv2(dat, [tsmooth chsmooth], [1 2]); %this is to smoothen noise across time and channels : uses convolution - higher is harder becuase smoothening suppresses the short-term fluctuations we care about
        dat = zscore(dat, 1, 1);
        dat = gather_try(dat);

        if t_all>0
            dat(1:buff/2, :) = dat_old(NT-buff/2 + [1:buff/2], :);
        end

        dat(:, [1 2]) = 0; % these are the "dead" channels

        % now we add spikes on non-dead channels. 
        ibatch =(spk_timesnew >= t_all*fs) & (spk_timesnew < t_all*fs+NT-buff); %spikes in this time range 
        ts = spk_timesnew(ibatch) - t_all*fs; %put into range of batch
        ids = clunew(ibatch); %which clusters are firing in this batch
        am = amps(ibatch); %amplitudes of spikes in this batch

        for i = 1:length(ts) %for all spikes in this batch
            if (ids(i) > numUnitsInit)
                dat(ts(i) + int64([1:82]), 2 + [1:32]) = dat(ts(i) + int64([1:82]), 2 + [1:32]) +...
                munew((ids(i) - NN)) * am(i) * wavnew(:,:,(ids(i) - NN)); %for timepoints ts(i) + 1:82 and channels 1:32, add template waveform TODO CHECK THIS
            end
        end

        dat_old    =  dat;    
        dat = int16(200 * dat); %scale to int16 range
        fwrite(fidW, dat(1:(NT-buff),invChanMap)', 'int16');
        t_all = t_all + (NT-buff)/fs;

        enoise_old = enoise;
    end
    clu = cat(1,clu, clunew);
    spk_times = cat(1,spk_times, spk_timesnew);
end

fclose(fidW); % all done
 
gtRes = spk_times + 42; % add back the time of the peak for the templates (answer to life and everything) MARIUS JOKE MARIUS JOKE MARIUS JOKE MARIUS JOKE
gtClu = clu;

save(fullfile(fpath, 'eMouseGroundTruth'), 'gtRes', 'gtClu')

%STRUCTURE FOR LONG DATA SIM

%don't concatenate files as this makes ground truth/benchmarking more
%complicated- instead vary params within file

%run data generation loop for one set of params, modify desired params
%(leaving EVERYTHING else the same)
    %change firing rate bounds for SOME or for ALL clusters
    %change mean amplitudes for SOME or for ALL clusters
    %change amplitude variation for SOME or for ALL clusters
    %add/remove clusters
    %change noise
    %ask about other common long-term variations that you can simulate
   
%make testing suite w/ 3 hour (?) simulated datasets looking at all of these variations individually and together--
%intended to mimic changes often seen in long term recordings
    %start w/ normal, 3 hour recording generated using KS1's defaults, then
    %make variations above and run/benchmark each time

%then import ground truth datasets and run those too -- this script will
%ultimately produce figures/stats that serve as proof-of-concept


%can test/visualize by removing noise/other clus and literally creating a dataset with a single
%cluster




