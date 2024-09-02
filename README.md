# NeuroZIP
A clustering-based approach to compression of neural timeseries data
Currently has no dependencies-- pull this repo and you're good to go
Designed to be compatible with Marius Pachitariu's kiloSort1 algorithm, and a sample processing pipeline involving kiloSort1 can be found in main_pipeline.mat-- just modify the paths
Please note that kiloSort must be very slightly modified to be compatible with NeuroZIP though, so I have provided a modified version of kiloSort1 as well. 
The work in the kiloSort1Modified folder is well-documented in Pachitariu 2016: https://www.biorxiv.org/content/10.1101/061481v1 

Also includes testing pipeline that generated all figures found in paper, which requires a modified version of spikeinterface with support for neurozip-kilosort to run. This will be added to the folder soon.