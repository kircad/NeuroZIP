import os
import matplotlib.pyplot as plt
import shutil
import pandas as pd
import seaborn as sns
import numpy as np 
from neurozip_lib.utils import *
from neurozip_lib.globals import *
from neurozip_lib.pairwise_comp import *
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
def hyperparameter_sweep(outpaths):
    # TODO JUST SAVE PANDAS DATAFRAME IN ADDITION TO SORTINGS, GIVE OPTION TO JUST LOAD THAT
    Wr = 0.7
    Wa = 0.3
    outpath = outpaths['neurozip_kilosort']
    ks_outpath = outpaths['kilosort']
    batch_size_multipliers = [1, 2, 3, 4, 5]
    spacings = [1, 2, 3, 4, 5] # replace with batch factor for random
    hyperparam_columns = ['Dataset', 'Spacing', 'Batch Size Multiplier', 'Relative Accuracy', 'Relative Runtime', 'Composite Score'] # TODO NORMALIZE COMPOSITE SCORE?
    data = pd.DataFrame(columns=hyperparam_columns)
    #tmp_path = 'C:/nztmp'
    if not use_downloaded:
        recordings = sf.load_spikeforest_recordings()
    else:
        with open(f"{local_recordings}/master.json", 'r') as file:
            recordings = json.load(file)
    for i in batch_size_multipliers:
        batch_size = (base_batch_size * i) + buffer_size
        for j in spacings:
            if os.path.exists(tmp_path):
                shutil.rmtree(tmp_path)
            tmpdata = pd.DataFrame(columns=hyperparam_columns)
            print(f'Running sorting for hyperparameter configuration - {i} {j}')
            params = {'method': 'linspace', 'spacing' : j, 'batch_size' : batch_size}
            run_sorter_helper('neurozip_kilosort', outpath, params, False, n_runs)
        #     full_comps[i][j], full_runtimes[i][j], _, _ = get_sorter_results('kilosort', outpath, {}, n_runs)
        #     full_comps[i][j], full_runtimes[i][j], _, _ = get_sorter_results('neurozip_kilosort', outpath, params, n_runs)    
        #     if ks_accuracy == 0:
        #         relAccuracy = perf['accuracy'] # TODO HOW TO HANDLE KS FAILED RUNS?
        #     else:
        #         relAccuracy = perf['accuracy'] / ks_accuracy TODO FIGURE OUT HOW TO RUN THIS
        #     relRuntime = run_time / ks_runtime
        #     composite = 100*((Wr * (1 - relRuntime)) + (Wa * (min(1, relAccuracy))))
        #     entry =  pd.DataFrame([[R.study_set_name, j, i, relAccuracy, relRuntime, composite] ], columns=hyperparam_columns)
        #     tmpdata = pd.concat([tmpdata, entry], ignore_index=True)
        # if len(data) == 0:
        #     data = pd.DataFrame(tmpdata.groupby('Dataset').mean().reset_index(), columns=hyperparam_columns)
        # else:
        #     data = pd.concat([data, pd.DataFrame(tmpdata.groupby('Dataset').mean().reset_index(), columns=hyperparam_columns)], ignore_index=True)
    opt_params = plot_params(data, outpath)
    return opt_params

# TODO CREATE WIDGET THAT FINDS BEST LINEAR SUBSAMPLING PARAMETERS BASED ON DIFFERENT WEIGHTS
# TODO CREATE WIDGET THAT SUBSAMPLES USER-INPUTTED DATA AND SUGGESTS PARAMETERS BASED ON THOSE + WEIGHTS