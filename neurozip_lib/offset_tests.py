import spikeforest as sf
import spikeinterface.widgets as sw
from neurozip_lib.pairwise_comp import run_sorter_helper, get_sorter_results, compile_study_info

def offset_tests(basepath, params, n_runs):
    full_comps = {}
    for i in range(params['spacing']):
        params['starting'] = i
        run_sorter_helper('neurozip_kilosort', f'{basepath}/starting_{i}', params, False, n_runs)
        full_comps[i], _ = get_sorter_results('neurozip_kilosort', basepath, params, n_runs)
    
    for R in sf.load_spikeforest_recordings():
        w_rs = sw.plot_rasters(R.get_sorting_true_extractor())
        for i in range(params['spacing']):
            perf = full_comps[i].loc[R.recording_name] # TODO this is def wrong lol
            w_rs = plot_batches(perf, i, params['spacing'])# TODO MAKE GRAPH OF BATCHES SIDE BY SIDE TO RASTER PLOT, PUT ACCURACY LABEL NEXT TO EACH BATCH SPACING
        w_rs.figure.savefig(basepath, f'{R.study_set_name}_{R.study_name}_{R.recording_name}_true_raster_plot.png')

def plot_batches(perf, starting, spacing):
    pass
