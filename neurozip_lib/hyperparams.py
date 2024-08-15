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
import spikeinterface.postprocessing as spost
import spikeinterface.qualitymetrics as sqm
import spikeinterface.comparison as sc
import spikeinterface.exporters as sexp
import spikeinterface.curation as scur
import spikeinterface.widgets as sw

def plot_params(data_full, outpath):
    datasets = data_full['Dataset'].unique()
    for recording in datasets:
        data = data_full.groupby('Dataset').get_group(recording)
        besttmp = data['Composite Score'].idxmax()
        opt_param =  {'spacing': int(data.loc[besttmp, 'Spacing']), 'batch_size': int(data.loc[besttmp, 'Batch Size Multiplier'])}
        make_heatmap(data, opt_param, recording, outpath)

    data = data_full.groupby(['Spacing', 'Batch Size Multiplier'])[data.columns[3:]].mean().reset_index()
    besttmp = data['Composite Score'].idxmax()
    opt_param =  {'spacing': int(data.loc[besttmp, 'Spacing']), 'batch_size': int(data.loc[besttmp, 'Batch Size Multiplier'])}
    data.insert(0, 'PlaceHolder', '')
    make_heatmap(data, opt_param, 'Mean', outpath)
    return opt_param

def make_heatmap(data, opt_param, recording, outpath):
    num_plots = len(data.columns[3:])
    num_cols = 3
    num_rows = 1
    fig, axes = plt.subplots(num_rows, num_cols, figsize=(12, 8 * num_rows))
    axes = axes.flatten()  # Flatten the 2D array of axes to make indexing easier

    for i, col in enumerate(data.columns[3:]):
        pivot_table = data.pivot_table(index='Spacing', columns='Batch Size Multiplier', values=col)
        ax = axes[i]
        sns.heatmap(pivot_table, annot=True, cmap='viridis', fmt='.2f', linewidths=0.5, ax=ax)
        rect_x = pivot_table.columns.get_loc(opt_param['batch_size']) + 0.5
        rect_y = pivot_table.index.get_loc(opt_param['spacing']) + 0.5
        ax.add_patch(plt.Rectangle(
            (rect_x - 0.5, rect_y - 0.5),
            1,
            1,
            fill=False,
            edgecolor='red',
            lw=2
        ))
        ax.set_title(f'Heatmap of NeuroZIP {col}')
        ax.set_xlabel('Batch Size Multiplier')
        ax.set_ylabel('Spacing')

    # Turn off unused subplots
    for j in range(num_plots, len(axes)):
        fig.delaxes(axes[j])

    plt.tight_layout()
    plt.savefig(f'{outpath}/{recording}_heatmaps_grid.png')

# TODO REFACTOR
def hyperparameter_sweep(recordings, outpaths): # TODO PARALLELIZE
    # TODO JUST SAVE PANDAS DATAFRAME IN ADDITION TO SORTINGS, GIVE OPTION TO JUST LOAD THAT
    Wr = 0.7
    Wa = 0.3
    outpath = outpaths['neurozip_kilosort']
    ks_outpath = outpaths['kilosort']
    batch_size_multipliers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    spacings = [1, 2, 3, 4, 5,6 ,7 , 8, 9, 10] # replace with batch factor for random
    hyperparam_columns = ['Dataset', 'Spacing', 'Batch Size Multiplier', 'Relative Accuracy', 'Relative Runtime', 'Composite Score'] # TODO NORMALIZE COMPOSITE SCORE?
    data = pd.DataFrame(columns=hyperparam_columns)
    #tmp_path = 'C:/nztmp'
    job_list = []
    for i in batch_size_multipliers:
        batch_size = (base_batch_size * i) + buffer_size
        for j in spacings:
            tmpdata = pd.DataFrame(columns=hyperparam_columns)
            for R in recordings:
                if not ((R.study_set_name == 'PAIRED_BOYDEN') or (R.study_set_name == 'PAIRED_CRCNS_HC1') or (R.study_set_name == 'PAIRED_ENGLISH') or (R.study_set_name == 'PAIRED_KAMPFF')):
                    continue # TODO MAKE WORK FOR ALL!
                recording = R.get_recording_extractor()
                sorting_true = R.get_sorting_true_extractor()
                ks_runtime = read_runtime_from_file(f'{ks_outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/kilosort/run_time.txt')
                ks_sorting = se.read_npz_sorting(f'{ks_outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/kilosort.npz')
                comp_gt = sc.compare_sorter_to_ground_truth(gt_sorting=sorting_true, tested_sorting=ks_sorting)
                
                ks_accuracy = comp_gt.get_performance(method='pooled_with_average')['accuracy']

                out_path = f'{outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/mult_{i}/spacing_{j}/'
                if os.path.exists(f'{out_path}results.npz'):
                    sorting = se.read_npz_sorting(f'{out_path}results.npz')
                    run_time = read_runtime_from_file(f'{out_path}run_time.txt')
                    comp_gt = sc.compare_sorter_to_ground_truth(gt_sorting=sorting_true, tested_sorting=sorting)
                    perf = comp_gt.get_performance(method='pooled_with_average')
                    if ks_accuracy == 0:
                        relAccuracy = perf['accuracy'] # TODO HOW TO HANDLE KS FAILED RUNS?
                    else:
                        relAccuracy = perf['accuracy'] / ks_accuracy
                    relRuntime = run_time / ks_runtime
                    composite = 100*((Wr * (1 - relRuntime)) + (Wa * (min(1, relAccuracy))))
                    entry =  pd.DataFrame([[R.study_set_name, j, i, relAccuracy, relRuntime, composite] ], columns=hyperparam_columns)
                    tmpdata = pd.concat([tmpdata, entry], ignore_index=True)
                else:
                    # if not os.path.exists(out_path):
                    #     os.makedirs(out_path)
                    job_list.append({'sorter_name': 'neurozip_kilosort', 'recording': recording, 'folder':out_path, 'NT':batch_size, 'spacing':j})
                    #run_time, sorting = ss.run_sorter(sorter_name='neurozip_kilosort', recording=recording, folder=tmp_path, NT=batch_size, spacing=j)
                    # shutil.rmtree(tmp_path) # TODO WHAT SHOULD I SAVE?
                    # se.NpzSortingExtractor.write_sorting(sorting, f'{out_path}results')
                    # write_runtime_to_file(run_time, f'{out_path}/run_time.txt')
            if len(data) == 0:
                data = pd.DataFrame(tmpdata.groupby('Dataset').mean().reset_index(), columns=hyperparam_columns)
            else:
                data = pd.concat([data, pd.DataFrame(tmpdata.groupby('Dataset').mean().reset_index(), columns=hyperparam_columns)], ignore_index=True)
    for i in range(0, len(job_list) - 1, 3):
        end = min(i + 3, len(job_list))
        results = ss.run_sorter_jobs(job_list=job_list[i:end], engine='joblib', engine_kwargs={'n_jobs': len(job_list)}, return_output=True)
        for rez, job in zip(results, job_list[i:end]):
            run_time, sorting = rez[0], rez[1]
            out_path = job['folder']
            for filename in os.listdir(out_path):
                file_path = os.path.join(out_path, filename)
                if os.path.isfile(file_path):
                    os.remove(file_path)  # Remove a file
                elif os.path.isdir(file_path):
                    shutil.rmtree(file_path) 
            se.NpzSortingExtractor.write_sorting(sorting, f'{out_path}results')
            write_runtime_to_file(run_time, f'{out_path}/run_time.txt')
    for i in job_list:
        pass # load newly processed data into pandas dataframe TODO MOVE THIS UP/MAKE IT MORE FLEXIBLE!
    opt_params = plot_params(data, outpath)
    return opt_params

# TODO CREATE WIDGET THAT FINDS BEST LINEAR SUBSAMPLING PARAMETERS BASED ON DIFFERENT WEIGHTS
# TODO CREATE WIDGET THAT SUBSAMPLES USER-INPUTTED DATA AND SUGGESTS PARAMETERS BASED ON THOSE + WEIGHTS