import os
import numpy as np
import scipy.io as sio
import spikeinterface as si
import spikeinterface.preprocessing as spre

# Set paths
fpath = 'C:/Users/kirca/Desktop/NeuroZIP'
outpath = os.path.join(fpath, 'results')


# PREPROCESS + LOAD PREPROCESSED DATA INTO ARRAY OF BATCHES
sampling_frequency = 30000 # TODO GET FROM CONFIG
num_channels = 32
dtype = "float64"
ops = {'method':'linear', 'spacing': 5, 'batch_size': (16 * 1024) + 64}

# TODO WRITE THIS BY STEPPING THROUGH CODE, USE SAMPLE DOWNLOADED DATASET FROM DOWNLOAD_RECORDING.PY
# Load data using SpikeInterface 
recording = si.read_binary(file_paths=fpath, sampling_frequency=sampling_frequency,
                           num_channels=num_channels, dtype=dtype)

# preprocess data
recording_cmr = recording
recording_f = spre.bandpass_filter(recording, freq_min=300, freq_max=6000)
recording_cmr = spre.common_reference(recording_f, reference='global', operator='median')

# break data into batches
recording_cmr = []
compression_rez = compress_data(ops, recording_cmr)

# Save results to output path
if not os.path.exists(outpath):
    os.makedirs(outpath)

# Save the results
np.save(os.path.join(outpath, 'rez.npy'), rez)
np.save(os.path.join(outpath, 'DATA.npy'), DATA)
np.save(os.path.join(outpath, 'uproj.npy'), uproj)
np.save(os.path.join(outpath, 'compression_rez.npy'), compression_rez)

def run_configurations(config_file, sample_config_file):
    pass

def setup_compression_ops():
    pass
