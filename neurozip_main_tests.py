from neurozip_lib.utils import *
from neurozip_lib.globals import *
from neurozip_lib.pairwise_comp import *

import spikeinterface.sorters as ss

def main(): # compares neuroZIP with selected hyperparameters to kilosort baseline
    ss.KilosortSorter.set_kilosort_path('C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/KiloSort')
    ss.NeuroZIP_KilosortSorter.set_nzkilosort_path('C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/neurozip-kilosort')
    calc_sortings = True
    full_comps, full_runtimes = {}, {}
    # params = {'kilosort' : {} , 'neurozip_kilosort' : {'spacing' : 5, 'batch_size' : 2}}
    # overwrite = {'kilosort': False, 'neurozip_kilosort': False}
    # basepaths = {'kilosort': 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/kilosort_baseline', 'neurozip_kilosort': 'D:/test'}
    params = {'kilosort' : {}}
    overwrite = {'kilosort': False}
    basepaths = {'kilosort': 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/kilosort_baseline'}
    analysis_path = 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP'
    for i in params.keys():
        if (calc_sortings):
            run_sorter_helper(i, basepaths[i], params[i], overwrite[i])
        full_comps[i], full_runtimes[i] = get_sorter_results(i, basepaths[i], params[i])
    compile_study_info(full_comps, full_runtimes, analysis_path)
    print('done!')

if __name__ == '__main__':
    main()
