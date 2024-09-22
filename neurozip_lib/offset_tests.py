import spikeforest as sf
import spikeinterface.widgets as sw
from neurozip_lib.pairwise_comp import run_sorter_helper, get_sorter_results, compile_study_info
from parse_config import *
import json

def offset_tests(basepath, params, n_runs):
    full_comps = {}
    for i in range(params['spacing']):
        params['starting'] = i + 1 # account for matlab 1-indexing
        run_sorter_helper('neurozip_kilosort', f'{basepath}/starting_{i}', params, False, n_runs)
        full_comps[i], _ = get_sorter_results('neurozip_kilosort', basepath, params, n_runs)
             
    
    def plot_batches(perf, starting, spacing): # just visualize batches (relative to spike times?)
        pass
