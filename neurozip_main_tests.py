import os 
import shutil

from neurozip_lib.globals import *
from neurozip_lib.pairwise_comp import run_sorter_helper, get_sorter_results, compile_study_info
from neurozip_lib.offset_tests import offset_tests
from neurozip_lib.hyperparams import hyperparameter_sweep

import spikeinterface.sorters as ss

def main(): # compares neuroZIP with selected hyperparameters to kilosort baseline
    ss.KilosortSorter.set_kilosort_path('C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/KiloSort')
    ss.NeuroZIP_KilosortSorter.set_nzkilosort_path('C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/neurozip-kilosort')
    calc_sortings = True
    offset_tests = True
    full_comps, full_runtimes = {}, {}
    params = {'kilosort' : {} , 'neurozip_kilosort' : {'spacing' : 5, 'batch_size' : (base_batch_size * 5) + buffer_size}, 'starting': 0}
    overwrite = {'kilosort': False, 'neurozip_kilosort': False}
    basepaths = {'kilosort': 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/kilosort_baseline', 'neurozip_kilosort': 'D:/test'}
    # params = {'kilosort' : {}}
    # overwrite = {'kilosort': False}
    # basepaths = {'kilosort': 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/kilosort_baseline'}
    analysis_path = 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/spikeforest_results'
    n_runs = 8
    if offset_tests:
        offset_tests('C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/offset_tests', params, 1)
    if os.path.exists(tmp_path):
        shutil.rmtree(tmp_path)
    for i in params.keys():
        if (calc_sortings):
            run_sorter_helper(i, basepaths[i], params[i], overwrite[i], n_runs)
        full_comps[i], full_runtimes[i] = get_sorter_results(i, basepaths[i], params[i], n_runs)
    compile_study_info(full_comps, full_runtimes, analysis_path)
    print('done!')

if __name__ == '__main__':
    main()

# TODO MAKE SURE SAMPLING RATE IS HANDLED PROPERLY FOR NEUROZIP