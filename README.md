# NeuroZIP
A clustering-based approach to compression of neural timeseries data
Currently has no dependencies-- pull this repo and you're good to go
Designed to be compatible with Marius Pachitariu's kiloSort1 algorithm, and a sample processing pipeline involving kiloSort1 can be found in main_pipeline.mat-- just modify the paths
Please note that kiloSort must be very slightly modified to be compatible with NeuroZIP though, so I have provided a modified version of kiloSort1 as well. 
The work in the kiloSort1Modified folder is well-documented in Pachitariu 2016: https://www.biorxiv.org/content/10.1101/061481v1 

Also includes testing pipeline that generated all figures found in paper, which requires a slightly modified version of spikeinterface with support for neurozip-kilosort to run and runtime tracking.

Pachitariu M, Steinmetz NA, Kadir S, Carandini M and Harris KD (2016). Kilosort: realtime spike-sorting for extracellular electrophysiology with hundreds of channels. bioRxiv dx.doi.org/10.1101/061481

@article{buccino2020spikeinterface,
  title={SpikeInterface, a unified framework for spike sorting},
  author={Buccino, Alessio Paolo and Hurwitz, Cole Lincoln and Garcia, Samuel and Magland, Jeremy and Siegle, Joshua H and Hurwitz, Roger and Hennig, Matthias H},
  journal={Elife},
  volume={9},
  pages={e61834},
  year={2020},
  publisher={eLife Sciences Publications Limited}
}
