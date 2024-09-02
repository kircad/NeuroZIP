function customChanMap(fpath)

fpath = 'C:\Users\kirca\Desktop\NeuroZIP\';

chanMap = [16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 31 32 29 27 28 25 23 24 21 19 20 17 18 22 26 30 36 40 44 48 47 46 45 43 42 41 39 38 37 35 34 33 63 64 61 62 59 60 57 58 55 56 53 54 51 52 49 50];

xcoords = zeros(1,64);

ycoords = 0:22.5:(63*22.5);

kcoords = zeros(1,64);

% the first thing Kilosort does is reorder the data with data = data(chanMap, :).
% Now we declare which channels are "connected" in this normal ordering, 
% meaning not dead or used for non-ephys data

connected = true(64, 1);

% Often, multi-shank probes or tetrodes will be organized into groups of
% channels that cannot possibly share spikes with the rest of the probe. This helps
% the algorithm discard noisy templates shared across groups. In
% this case, we set kcoords to indicate which group the channel belongs to.
% In our case all channels are on the same shank in a single group so we
% assign them all to group 1. 


% at this point in Kilosort we do data = data(connected, :), ycoords =
% ycoords(connected), xcoords = xcoords(connected) and kcoords =
% kcoords(connected) and no more channel map information is needed (in particular
% no "adjacency graphs" like in KlustaKwik). 
% Now we can save our channel map for the eMouse. 

% would be good to also save the sampling frequency here
fs = 20000; 

save(fullfile(fpath, 'chanMap.mat'), 'chanMap', 'connected', 'xcoords', 'ycoords', 'kcoords', 'fs')