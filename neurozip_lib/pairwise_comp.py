import os
import matplotlib.pyplot as plt
import shutil
import pandas as pd
import seaborn as sns
import numpy as np 
from neurozip_lib.utils import *
from neurozip_lib.globals import *

import spikeforest as sf
import spikeinterface as si  # import core only
import spikeinterface.extractors as se
import spikeinterface.preprocessing as spre
import spikeinterface.sorters as ss
import spikeinterface.comparison as sc

def plot_templates(analyzer, save_path):
    ext_templates = analyzer.get_extension("templates")
    av_templates = ext_templates.get_data(operator="average")
    fig, ax = plt.subplots()
    for unit_index, unit_id in enumerate(analyzer.unit_ids[:3]):
        template = av_templates[unit_index]
        ax.plot(template)
        ax.set_title(f"{unit_id}")
    ax.set_title("Templates for Units")
    ax.set_xlabel("Sample Index")
    ax.set_ylabel("Amplitude")
    ax.legend()
    plt.savefig(save_path)

def compile_study_info(combined_comps, run_times, savepath): #  TODO FIX SCHEME OF GETTING DATA FROM COMBINED_COMPS, RUN_TIMES, SHOULD BE A LOT EASIER NOW
    # Create subplots
    metrics = combined_comps[list(combined_comps.keys())[0]].columns
    num_metrics = len(metrics)
    fig, axes = plt.subplots(1, num_metrics + 1, figsize=(6 * num_metrics, 6))
    if num_metrics == 1:
        axes = [axes]  # Ensure axes is always a list
    
    # Define color palette
    palette = sns.color_palette("husl", len(combined_comps['kilosort'].index))
    color_dict = {name: color for name, color in zip(combined_comps['kilosort'].index, palette)}
    
    legend_handles = []
    legend_labels = []
    
    for k in range(len(combined_comps)):
        sorter = list(combined_comps.keys())[k]
        comps = combined_comps[sorter]
        
        # Plot each metric individually
        for i, metric in enumerate(metrics):
            ax = axes[i]
            
            # Create box plot
            sns.boxplot(x=k, y=comps[metric], ax=ax, color='lightgray', fliersize=0)
            
            # Overlay individual data points with colors
            for _, recording in enumerate(comps.index):
                y = comps.loc[recording, metric]
                x = np.random.normal(k, 0.05)
                scatter = ax.plot(x, y, 'o', color=color_dict[recording], markersize=8, alpha=0.7)[0]
                
                if i == 0 and k == 0 and recording not in legend_labels:
                    legend_handles.append(scatter)
                    legend_labels.append(recording)
            
            # Customize plot
            ax.set_title(metric, fontsize=14)
            ax.set_xlabel("Spike Sorting Method")
            ax.set_ylabel('Value', fontsize=12)
            ax.tick_params(axis='both', which='major', labelsize=10)
            ax.set_xticks(range(len(list(combined_comps.keys()))))
            ax.set_xticklabels(list(combined_comps.keys()), rotation=45, ha='right')
    
        #  plot runtimes
        ax = axes[-1]
        run_times = pd.DataFrame(run_times)
        sns.boxplot(x=k, y=run_times[sorter], ax=ax, color='lightgray', fliersize=0)
        for _, recording in enumerate(run_times.index):
                y = run_times.loc[recording, sorter]
                x = np.random.normal(k, 0.05)
                scatter = ax.plot(x, y, 'o', color=color_dict[recording], markersize=8, alpha=0.7)[0]
        ax.set_title('Runtime', fontsize=14)
        ax.set_xlabel("Spike Sorting Method")
        ax.set_ylabel('Time(s)', fontsize=12)
        ax.tick_params(axis='both', which='major', labelsize=10)
        ax.set_xticks(range(len(list(combined_comps.keys()))))
        ax.set_xticklabels(list(combined_comps.keys()), rotation=45, ha='right')
    
    fig.legend(legend_handles, legend_labels, title='Recordings',
               loc='center left', bbox_to_anchor=(1, 0.5))
    
    # Adjust layout
    plt.subplots_adjust(right=0.85)  # Make room for the legend
    plt.tight_layout()
    
    # Save and show plot
    plt.savefig(savepath, bbox_inches='tight')

def run_sorter_helper(sorter, outpath, params, overwrite):  # runs sorter on all spikeforest datasets and saves the full sorting to basepath, overwriting if specified to and file already exists
    # TODO PARALLELIZE!
    all_recordings = sf.load_spikeforest_recordings()
    for R in all_recordings:
        if (R.study_set_name not in datasets):
            print('Skipping...')
            continue
        print(f'{R.study_set_name}/{R.study_name}/{R.recording_name}')
        recording = R.get_recording_extractor()
        out_path = f'{outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/{sorter}'
        if params:
            out_path = f'{outpath}/mult_{params['batch_size']}/spacing_{params['spacing']}/'
        #analyzer_outpath =  f'{out_path}/analysis'
        if overwrite and os.path.exists(f'{out_path}/sorter_output'):
            shutil.rmtree(out_path)
            print(f'Overwriting files at {out_path}')
        if not os.path.exists(out_path):
            try:
                if (params):
                    run_time, sorting = ss.run_sorter(sorter_name=sorter, recording=recording, folder=out_path, NT=params['batch_size'], spacing=params['spacing']) # TODO HAVE SOMETHING FOR NEUROZIP PARAMS
                else:
                    run_time, sorting = ss.run_sorter(sorter_name=sorter, recording=recording, folder=out_path)
                se.NpzSortingExtractor.write_sorting(sorting, out_path)
                write_runtime_to_file(run_time, f'{out_path}/run_time.txt')
            except Exception:
                print(f'Failed sorting {R.study_set_name}/{R.study_name}/{R.recording_name}')
                continue

        # if os.path.exists(analyzer_outpath):
        #     if overwrite:
        #         shutil.rmtree(analyzer_outpath)
        #     else:
        #         analyzer = si.load_sorting_analyzer(folder=analyzer_outpath)

        # if not os.path.exists(analyzer_outpath):
        #     recording_cmr = recording
        #     recording_f = spre.bandpass_filter(recording, freq_min=300, freq_max=6000)
        #     recording_cmr = spre.common_reference(recording_f, reference='global', operator='median')

        #     analyzer = si.create_sorting_analyzer(sorting=sorting, recording=recording_cmr, format='binary_folder', folder=analyzer_outpath)
        #     analyzer.compute(extensions_to_compute, extension_params=extension_params)
        #     analyzer.save_as(folder=analyzer_outpath)

def get_sorter_results(sorter, outpath, params):
    all_recordings = sf.load_spikeforest_recordings()
    comps, run_times = pd.DataFrame(columns=(['Dataset'] + ['Recording'] + columns)), pd.DataFrame(columns=['Dataset', 'Recording', 'Run Time'])
    for R in all_recordings:
        if (R.study_set_name not in datasets):
            print('Skipping...')
            continue
        sorting_true = R.get_sorting_true_extractor()

        out_path = f'{outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/{sorter}'
        if sorter == 'neurozip_kilosort':
            out_path = f'{out_path}/mult_{params['batch_size']}/spacing_{params['spacing']}/'
        sorting_outpath = out_path
        #analyzer_outpath =  f'{out_path}/analysis'

        if os.path.exists(f'{sorting_outpath}/sorter_output'):
            try:
                sorting = se.read_phy(f'{sorting_outpath}/sorter_output')
                run_time = read_runtime_from_file(f'{sorting_outpath}/run_time.txt')
            except Exception:
                print(f'Failed collecting spike sorting results {R.study_set_name}/{R.study_name}/{R.recording_name}/{sorter}')

        # if os.path.exists(analyzer_outpath):
            #analyzer = si.load_sorting_analyzer(folder=analyzer_outpath)

        #plot_templates(analyzer, f'{fig_outpath}/templates.png')

        #w1 = sw.plot_quality_metrics(analyzer, backend='matplotlib')
        #w2 = sw.plot_sorting_summary(analyzer, backend="sortingview")
        #w1.figure.savefig(f'{fig_outpath}/quality_metrics.png') TODO why does this look so bad
        #w2.figure.savefig(f'{fig_outpath}/sorting_summary.png') TODO FIGURE OUT HOW TO SAVE THIS/is it different from phy?
        comp_gt = sc.compare_sorter_to_ground_truth(gt_sorting=sorting_true, tested_sorting=sorting)

        perf = comp_gt.get_performance(method='pooled_with_average')
        perf.columns = columns
        comps.loc[len(comps)] = [R.study_name, R.recording_name, perf['accuracy'], perf['precision'], perf['recall'], perf['miss_rate'], perf['false_discovery_rate']]
        run_times.loc[len(run_times)] = [R.study_name, R.recording_name, run_time]
    return comps, run_times

    # TODO play around with spikeinterface compare multiple sorters thing
        #w_conf = sw.plot_confusion_matrix(comp_gt)
        #w_conf.figure.savefig(f'{fig_outpath}/ground_truth_comparison.png') # only useful if we have > 1 unit lol - TODO plot this combining units across recordings?


# TODO ADD SOMETHING THAT STOPS WHOLE PIPELINE FROM CRASHING ON FAILED SORTING
# TODO GET WORKING ON SCATHA
# TODO RUN EACH SORTING 6-8 TIMES IN PARALLEL!
# TODO WHY ARE ACCURACY VALUES SO SPORADIC??