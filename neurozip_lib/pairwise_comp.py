import os
import matplotlib.pyplot as plt
import shutil
import pandas as pd
import seaborn as sns
import numpy as np 
from neurozip_lib.utils import *
from neurozip_lib.globals import *
from neurozip_lib.compress import *

import spikeforest as sf
#import spikeinterface as si  # import core only
import spikeinterface.extractors as se
#import spikeinterface.preprocessing as spre
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

def compile_study_info(full_comps, run_times, savepath):
    unique_cols = full_comps['kilosort'][full_comps['kilosort'].columns[0]].unique()
    for j in range(len(unique_cols) + 1):
        legend_handles = []
        legend_labels = []

        if j == len(unique_cols):
            dataset = 'AVERAGE'
        else:
            dataset = unique_cols[j]
            palette = sns.color_palette("husl", len(full_comps['kilosort'].loc[full_comps['kilosort']['Dataset'] == dataset]))
            color_dict = {name: color for name, color in zip(full_comps['kilosort'].loc[full_comps['kilosort']['Dataset'] == dataset]['Recording'], palette)}
        fig, axes = plt.subplots(1, len(columns) + 1, figsize=(6 * len(columns), 6))
        for k in range(len(full_comps.keys())):
            sorter = list(full_comps.keys())[k]
            if j == len(unique_cols):
                comps = full_comps[sorter].groupby('Dataset')[columns].mean().reset_index().rename(columns={'Dataset' : 'Recording'})
                runtimes = run_times[sorter].groupby('Dataset')["Run Time"].mean().reset_index().rename(columns={'Dataset' : 'Recording'})
                palette = sns.color_palette("husl", len(comps))
                color_dict = {name: color for name, color in zip(comps['Recording'], palette)}
            else:
                comps = full_comps[sorter].loc[full_comps[sorter]['Dataset'] == dataset]
                runtimes = run_times[sorter].loc[run_times[sorter]['Dataset'] == dataset]
            # Plot each metric individually
            for i, metric in enumerate(columns):
                ax = axes[i]
                
                sns.boxplot(x=k, y=comps[metric], ax=ax, color='lightgray', fliersize=0)
                
                # Overlay individual data points with colors

                for recording in comps['Recording']:
                    y = comps.loc[comps['Recording'] == recording][metric].iloc[0]
                    x = np.random.normal(k, 0.05)
                    scatter = ax.plot(x, y, 'o', color=color_dict[recording], markersize=8, alpha=0.7)[0]
                    
                    if i == 0 and k == 0 and recording not in legend_labels:
                        legend_handles.append(scatter)
                        legend_labels.append(recording)
                
                ax.set_title(metric, fontsize=14)
                ax.set_xlabel("Spike Sorting Method")
                ax.set_ylabel('Value', fontsize=12)
                ax.tick_params(axis='both', which='major', labelsize=10)
                ax.set_xticks(range(len(list(full_comps.keys()))))
                ax.set_xticklabels(list(full_comps.keys()), rotation=45, ha='right')
        
            #  plot runtimes
            ax = axes[-1]
            sns.boxplot(x=k, y=runtimes['Run Time'], ax=ax, color='lightgray', fliersize=0)
            for _, recording in enumerate(runtimes['Recording']):
                    y = runtimes.loc[comps['Recording'] == recording]['Run Time'].iloc[0]
                    x = np.random.normal(k, 0.05)
                    scatter = ax.plot(x, y, 'o', color=color_dict[recording], markersize=8, alpha=0.7)[0]
            ax.set_title('Runtime', fontsize=14)
            ax.set_xlabel("Spike Sorting Method")
            ax.set_ylabel('Time(s)', fontsize=12)
            ax.tick_params(axis='both', which='major', labelsize=10)
            ax.set_xticks(range(len(list(full_comps.keys()))))
            ax.set_xticklabels(list(full_comps.keys()), rotation=45, ha='right')
        
            fig.legend(legend_handles, legend_labels, title='Recordings', loc='center left', bbox_to_anchor=(1, 0.5))
                
        plt.subplots_adjust(right=0.85)  # Make room for the legend
        plt.tight_layout()
        
        plt.savefig(f'{savepath}/{dataset}_pairwise.png', bbox_inches='tight')

    for i in full_comps.keys():
        full_comps[i].to_excel(f'{savepath}/{i}_comps.xlsx', sheet_name='RESULTS', index=False, header=True)

def run_sorter_helper(sorter, outpath, params, overwrite, n_runs):  # runs sorter on all spikeforest datasets and saves the full sorting to basepath, overwriting if specified to and file already exists
    for R in sf.load_spikeforest_recordings():
        if (R.study_set_name not in datasets):
            print('Skipping...')
            continue
        print(f'{sorter} -- {R.study_set_name}/{R.study_name}/{R.recording_name}')
        out_path = f'{outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/{sorter}'
        if params:
            out_path = f'{outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/mult_{params['batch_size']}/spacing_{params['spacing']}/'
        #analyzer_outpath =  f'{out_path}/analysis'
        if overwrite and os.path.exists(f'{out_path}/sorter_output'):
            shutil.rmtree(out_path)
            print(f'Overwriting files at {out_path}')
        if not os.path.exists(out_path):
            try:
                job_list = []
                if params:
                    for i in range(n_runs):
                        job_list.append({'sorter_name': sorter, 'recording': R.get_recording_extractor(), 'folder':f'{tmp_path}/{i}', 'batchesToUse':get_batches(R.get_recording_extractor(), params)})
                else:
                    for i in range(n_runs):
                        job_list.append({'sorter_name': sorter, 'recording': R.get_recording_extractor(), 'folder':f'{tmp_path}/{i}'})
                minijobs = [job_list[i:min(i+max_concurrent_jobs, len(job_list))] for i in range(0, len(job_list), max_concurrent_jobs)] # TODO CHECK THIS
                for batch in minijobs:
                    results = ss.run_sorter_jobs(job_list=batch, 
                    engine='joblib', engine_kwargs={'n_jobs': len(batch)}, return_output=True)
                
                for rez, job, counter in zip(results, job_list, len(job_list)):
                    run_time, sorting = rez[0], rez[1]
                    shutil.rmtree(job['folder'])
                    if not os.path.exists(out_path):
                        os.makedirs(out_path)
                    se.NpzSortingExtractor.write_sorting(sorting, f'{out_path}/Run_{counter}.npz')
                    write_runtime_to_file(run_time, f'{out_path}/Run_{counter}_run_time.txt')

            except Exception as e:
                print(f'Failed sorting {R.study_set_name}/{R.study_name}/{R.recording_name} - {e}')
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

def get_sorter_results(sorter, outpath, params, n_runs):
    all_recordings = sf.load_spikeforest_recordings()
    comps, run_times = pd.DataFrame(columns=(['Dataset'] + ['Recording'] + columns)), pd.DataFrame(columns=['Dataset', 'Recording', 'Run Time'])
    for R in all_recordings:
        if (R.study_set_name not in datasets):
            print('Skipping...')
            continue
        perfs, runtimes = [], []
        for i in range(n_runs):
            out_path = f'{outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/{sorter}'
            if sorter == 'neurozip_kilosort':
                out_path = f'{outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/mult_{params['batch_size']}/spacing_{params['spacing']}'
            sorting_outpath = out_path
            #analyzer_outpath =  f'{out_path}/analysis'

            if os.path.exists(sorting_outpath) and len(os.listdir(sorting_outpath)) == (n_runs * 2):
                try:
                    sorting = se.read_npz_sorting(f'{out_path}/Run_{i}.npz')
                    run_time = read_runtime_from_file(f'{sorting_outpath}/Run_{i}_run_time.txt')
                except Exception:
                    print(f'Failed collecting spike sorting results {R.study_set_name}/{R.study_name}/{R.recording_name}/{sorter}')

            # if os.path.exists(analyzer_outpath):
                #analyzer = si.load_sorting_analyzer(folder=analyzer_outpath)

            #plot_templates(analyzer, f'{fig_outpath}/templates.png')

            #w1 = sw.plot_quality_metrics(analyzer, backend='matplotlib')
            #w2 = sw.plot_sorting_summary(analyzer, backend="sortingview")
            #w1.figure.savefig(f'{fig_outpath}/quality_metrics.png') TODO why does this look so bad
            #w2.figure.savefig(f'{fig_outpath}/sorting_summary.png') TODO FIGURE OUT HOW TO SAVE THIS/is it different from phy?
            comp_gt = sc.compare_sorter_to_ground_truth(gt_sorting=R.get_sorting_true_extractor(), tested_sorting=sorting) # TODO SAVE GET_SORTING_TRUE_EXTRACTOR FOLDER TO PERMANENT LOCATION IN DISK!!!

            perf = comp_gt.get_performance(method='pooled_with_average')
            perf.columns = columns
            perfs.append(perf)
            runtimes.append(run_time)
        perf = sum(perfs) / len(perfs)
        run_time = sum(runtimes) / len(runtimes)
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