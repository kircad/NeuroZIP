import os 
import shutil

from neurozip_lib.globals import *
from neurozip_lib.pairwise_comp import run_sorter_helper, get_sorter_results, compile_study_info
from neurozip_lib.offset_tests import offset_tests
from neurozip_lib.hyperparams import hyperparameter_sweep

import spikeinterface.sorters as ss
def main(): # compares neuroZIP with selected hyperparameters to kilosort baseline
    full_comps, full_runtimes, full_comp_variations, full_runtime_variations = {}, {}, {}, {} # TODO MIGHT BE BETTER TO JUST MAKE THIS ONE BIG PD DATAFRAME!
    if not os.path.exists(analysis_path):
        os.mkdir(analysis_path)
    if run_hyperparameter_sweep:
        hyperparameter_sweep(basepaths)
    if run_offset_tests:
        offset_tests('C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/offset_tests', params['neurozip_kilosort'], 1)
    if run_hyperparameter_sweep:
        params['neurozip_kilosort'] = hyperparameter_sweep(basepaths, calc_sortings)
    if os.path.exists(tmp_path):
        shutil.rmtree(tmp_path)
    for i in params.keys():
        if (calc_sortings):
            run_sorter_helper(i, basepaths[i], params[i], overwrite[i], n_runs)
        full_comps[i], full_runtimes[i], full_comp_variations[i], full_runtime_variations[i] = \
            get_sorter_results(i, basepaths[i], params[i], n_runs)
    compile_study_info(full_comps, full_runtimes, analysis_path, 'Value')
    compile_study_info(full_comp_variations, full_runtime_variations, analysis_path, 'Variance')
    print('done!')

if __name__ == '__main__':
    main()

# TODO MAKE SURE SAMPLING RATE IS HANDLED PROPERLY FOR NEUROZIP