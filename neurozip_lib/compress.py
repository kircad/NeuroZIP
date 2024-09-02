import os
import numpy as np
import scipy.io as sio
import spikeinterface as si
import spikeinterface.preprocessing as spre

from neurozip_lib.compress_helper import *
# Set paths
def main():
    fpath = 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/NeuroZIP-python/recording.dat'
    sampling_frequency = 20000
    num_channels = 4
    dtype = "int16"
    recording = si.read_binary(file_paths=fpath, sampling_frequency=sampling_frequency,
                            num_channels=num_channels, dtype=dtype)
    ops = {'method':'dynamic', 'spacing': 5, 'batch_size': (16 * 1024) + 64}
    get_batches(recording, ops)

def get_batches(recording, ops): # assumes input is SpikeInterface Extractor
    recording_f = spre.highpass_filter(recording=recording, freq_min=300)
    recording_cmr = spre.common_reference(recording=recording_f, operator="median") # TODO CHECK/OPTIMIZE PREPROCESSING
    #batch = spre.whiten(batch) TODO FIX
    preprocessed_batches = []
    for i in range(0, recording.get_num_samples(), ops['batch_size']):
        end = min(i + ops['batch_size'], recording.get_num_samples())
        batch = recording_cmr.frame_slice(start_frame=i, end_frame=end).get_traces()    
        preprocessed_batches.append(batch)

    compression_rez = compress_data(ops, preprocessed_batches)
    print(f'Done. Using {round(100*(len(compression_rez) / len(preprocessed_batches)), 2)}% of data')
    return compression_rez

def run_configurations(config_file, sample_config_file):
    pass

def setup_compression_ops():
    pass

if __name__ == '__main__':
    main()
