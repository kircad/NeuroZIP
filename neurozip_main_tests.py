import os
import matplotlib.pyplot as plt
import shutil
import pandas as pd
import seaborn as sns
import numpy as np 

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

def main(): # currently only works with pairwise comparisons -- TODO make this work for multiple neurozip parameter configurations
    #TODO parallelize parameter sweep
    use_saved = {'SORTER': True, 'ANALYZER': True}
    use_docker = {'kilosort': False, 'neurozip_kilosort': False}
    full_comps = {'kilosort': {}, 'neurozip_kilosort': {}} # EXPAND THIS IF YOU WANT MORE GRAPHS
    tmp_folder = 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/tmp'
    #final_outpath = 'D:/Neurozip_Kilosort_Docker'
    final_outpath = 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/test'
    ss.KilosortSorter.set_kilosort_path('C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/KiloSort')
    ss.NeuroZIP_KilosortSorter.set_nzkilosort_path('C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/neurozip-kilosort')
    
    extensions_to_compute = [
        "random_spikes",
        "waveforms",
        "noise_levels",
        "templates",
        "spike_amplitudes",
        "unit_locations",
        "spike_locations",
        "correlograms",
        "template_similarity",
        "quality_metrics"
    ]
    extension_params = {
        "unit_locations": {"method": "center_of_mass"},
        "spike_locations": {"ms_before": 0.1},
        "correlograms": {"bin_ms": 0.1},
        "template_similarity": {"method": "cosine_similarity"}
    }
    
    run_times = {'kilosort': {}, 'neurozip_kilosort':{}}
    comps = {'kilosort': pd.DataFrame(columns=['Accuracy', 'Precision', 'Recall', 'Miss_Rate', 'False_Discovery_Rate']),
              'neurozip_kilosort': pd.DataFrame(columns=['Accuracy', 'Precision', 'Recall', 'Miss_Rate', 'False_Discovery_Rate'])}
    all_recordings = sf.load_spikeforest_recordings()

    #optimal_params = hyperparameter_sweep(all_recordings, final_outpath)
    study_set = all_recordings[0].study_set_name
    for R in all_recordings:
        if not (R.study_set_name == study_set):
            if not (run_times['kilosort'] == {}):
                compile_study_info(comps, run_times, f'{final_outpath}/{study_set}')
                for i in full_comps.keys():
                    comps[i].to_excel(f'{final_outpath}/{study_set}/{i}_ground_truth_comparison.xlsx', index=True, header=True, engine='openpyxl')
                    full_comps[i][study_set] = {}
                    full_comps[i][study_set]['results'] = comps[i]
                    full_comps[i][study_set]['runtime'] = run_times[i]

                    comps[i] = pd.DataFrame(columns=['Accuracy', 'Precision', 'Recall', 'Miss_Rate', 'False_Discovery_Rate'])
                    run_times[i] = {}
            study_set = R.study_set_name
        # if (R.study_set_name == 'PAIRED_CRCNS_HC1'): #  TODO FIGURE THIS OUT!
        #     print('bad recording. Skipping...')
        #     continue
        out_path = f'{final_outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}'
        print(f'{R.study_set_name}/{R.study_name}/{R.recording_name}')
        print(f'Num. channels: {R.num_channels}')
        print(f'Duration (sec): {R.duration_sec}')
        print(f'Sampling frequency (Hz): {R.sampling_frequency}')
        print(f'Num. true units: {R.num_true_units}')
        print('') # TODO test if just taking first xx minutes of recording = same accuracy as subsampling to do template generation on xx minutes
        #  TODO EVEN EASIER: just run on smaller and smaller recordings and see where it crashes
        recording = R.get_recording_extractor()
        sorting_true = R.get_sorting_true_extractor()

        # printing raster plots
        # w_ts = sw.plot_traces(recording, time_range=(100, 105))
        # w_rs = sw.plot_rasters(sorting_true, time_range=(100, 105))
        # w_rs.figure.savefig(os.path.join(fig_outpath, "true_raster_plot.png"))
        # w_ts.figure.savefig(os.path.join(fig_outpath,"traces.png"))

        for sorter in run_times.keys(): # TODO FIND WAY TO LOOK AT RECORDING SIZE/NUMBER OF BATCHES BEFORE RUNNING SPIKE SORTING ALGORITHM!!!
            sorting_outpath = f'{out_path}/{sorter}'
            analyzer_outpath =  f'{out_path}/{sorter}/analysis'
            fig_outpath =  f'{out_path}/{sorter}/figures'

            if os.path.exists(f'{sorting_outpath}/sorter_output'):
                if not use_saved['SORTER']:
                    shutil.rmtree(sorting_outpath)
                else:
                    sorting = se.read_phy(f'{sorting_outpath}/sorter_output')
                    run_time = read_runtime_from_file(f'{sorting_outpath}/run_time.txt')
            if not os.path.exists(sorting_outpath):
                if use_docker[sorter]:
                    run_time, sorting = ss.run_sorter(sorter_name=sorter, recording=recording, output_folder=tmp_folder, folder=tmp_folder, docker_image="kilosort:tag")
                    shutil.copytree(tmp_folder, sorting_outpath)
                    shutil.rmtree(tmp_folder)
                else:
                    run_time, sorting = ss.run_sorter(sorter_name=sorter, recording=recording, folder=sorting_outpath) # TODO HAVE SOMETHING FOR NEUROZIP PARAMS
                se.NpzSortingExtractor.write_sorting(sorting, sorting_outpath)
                write_runtime_to_file(run_time, f'{sorting_outpath}/run_time.txt')

            if os.path.exists(analyzer_outpath):
                if not use_saved['ANALYZER']:
                    shutil.rmtree(analyzer_outpath)
                else:
                    analyzer = si.load_sorting_analyzer(folder=analyzer_outpath)

            if not os.path.exists(analyzer_outpath):
                recording_cmr = recording
                recording_f = spre.bandpass_filter(recording, freq_min=300, freq_max=6000)
                recording_cmr = spre.common_reference(recording_f, reference='global', operator='median')

                analyzer = si.create_sorting_analyzer(sorting=sorting, recording=recording_cmr, format='binary_folder', folder=analyzer_outpath)
                analyzer.compute(extensions_to_compute, extension_params=extension_params)
                analyzer.save_as(folder=analyzer_outpath)

            #w1 = sw.plot_quality_metrics(analyzer, backend='matplotlib')
            #w2 = sw.plot_sorting_summary(analyzer, backend="sortingview")
            comp_gt = sc.compare_sorter_to_ground_truth(gt_sorting=sorting_true, tested_sorting=sorting)
            perf = comp_gt.get_performance(method='pooled_with_average')
            perf.columns = ['Accuracy', 'Precision', 'Recall', 'Miss_Rate', 'False_Discovery_Rate']
            comps[sorter].loc[f'{R.study_name}/{R.recording_name}'] = [perf['accuracy'], perf['precision'], perf['recall'], perf['miss_rate'], perf['false_discovery_rate']]
            run_times[sorter][f'{R.study_name}/{R.recording_name}'] = run_time

            if not (os.path.exists(fig_outpath)):
                os.mkdir(fig_outpath)
            plot_templates(analyzer, f'{fig_outpath}/templates.png')
            #w1.figure.savefig(f'{fig_outpath}/quality_metrics.png') TODO why does this look so bad
            #w2.figure.savefig(f'{fig_outpath}/sorting_summary.png') TODO FIGURE OUT HOW TO SAVE THIS/is it different from phy?
        # TODO play around with spikeinterface compare multiple sorters thing
        #w_conf = sw.plot_confusion_matrix(comp_gt)
        #w_conf.figure.savefig(f'{fig_outpath}/ground_truth_comparison.png') # only useful if we have > 1 unit lol - TODO plot this combining units across recordings?
    #compile_study_info(comps, out_path)
    print('done!')

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

def compile_study_info(combined_comps, run_times, savepath):
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

def write_runtime_to_file(run_time, filepath):
    with open(filepath, 'w') as file:
        file.write(str(run_time))

def read_runtime_from_file(filepath):
    with open(filepath, 'r') as file:
        number = file.read()
    return float(number)

def find_best_params(accuracies, run_times, ks_runtimes):
    best_ratio = 0
    for i in run_times:
        for j in accuracies:
            
            pass
# TODO PLOT ACCURACY__NZ / ACCURACY_KS, METRIC BALANCING RUNTIME AND PERFORMANCE RATIO
# RATIO : Weight(performance) x (ks_accuracy / nz_accuracy) - Weight(runtime) x (ks_runtime / nz_runtime) #  TODO NORMALIZE?? 
def plot_params(accuracies, run_times, opt_params, outpath):
    weight_performance = opt_params.get('weight_performance', 1)
    weight_runtime = opt_params.get('weight_runtime', 1)

    # TODO CHANGE THIS    
    accuracies = np.array(accuracies)
    run_times = np.array(run_times)
    
    # TODO CHANGE THIS
    num_methods = len(accuracies)
    ratio_matrix = np.zeros((num_methods, num_methods))
    
    for i in range(num_methods):
        for j in range(num_methods):
            if i != j:
                ks_accuracy = accuracies[i]
                nz_accuracy = accuracies[j]
                ks_runtime = run_times[i]
                nz_runtime = run_times[j]
                
                performance_ratio = weight_performance * (ks_accuracy / nz_accuracy)
                runtime_ratio = weight_runtime * (ks_runtime / nz_runtime)
                ratio_matrix[i, j] = performance_ratio - runtime_ratio
    
    # Plotting the heatmap
    plt.figure(figsize=(8, 6))
    sns.heatmap(ratio_matrix, annot=True, cmap='coolwarm', fmt='.2f',
                xticklabels=['Method1', 'Method2'],  # TODO CHANGE THIS
                yticklabels=['Method1', 'Method2'])  # TODO CHANGE THIS
    
    plt.title('Performance vs Runtime Ratio Heatmap')
    plt.xlabel('Method') # TODO CHANGE THIS
    plt.ylabel('Method') # TODO CHANGE THIS
    
    # Save the plot
    plt.tight_layout()
    plt.savefig(outpath)
    plt.close()

def hyperparameter_sweep(recordings, outpath):
    batch_size_multipliers = [1, 2, 3, 4, 5]
    spacings = [1, 2, 3, 4, 5] # replace with batch factor for random
    accuracies, run_times = {} # key = [spacing, multiplier], val = accuracy/runtime TODO CHANGE TO PANDAS DATAFRAME
    ks_runtimes = {}
    tmp_path = f'{outpath}/tmp'
    for R in recordings:
        ks_runtimes[R.study_set_name].append(read_runtime_from_file(f'{outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/run_time.txt'))
        for i in batch_size_multipliers:
            for j in spacings:
                recording = R.get_recording_extractor()
                sorting_true = R.get_sorting_true_extractor()
                out_path = f'{outpath}/{R.study_set_name}/{R.study_name}/{R.recording_name}/{i}/{j}/'
                if os.path.exists(f'{out_path}/sorter_output'):
                    sorting = se.read_phy(f'{out_path}/sorter_output')
                    run_time = read_runtime_from_file(f'{out_path}_run_time.txt')
                else:
                    run_time, sorting = ss.run_sorter(sorter_name='neurozip_kilosort', recording=recording, folder=tmp_path) # TODO HAVE SOMETHING FOR NEUROZIP PARAMS
                comp_gt = sc.compare_sorter_to_ground_truth(gt_sorting=sorting_true, tested_sorting=sorting)
                perf = comp_gt.get_performance(method='pooled_with_average')
                perf.columns = ['Accuracy', 'Precision', 'Recall', 'Miss_Rate', 'False_Discovery_Rate']
                accuracies[i][j].append(perf['accuracy'])
                run_times[i][j].append(run_time)
                shutil.rmtree(tmp_path) # dont need all of this, just summaries
                se.NpzSortingExtractor.write_sorting(sorting, out_path)
                write_runtime_to_file(run_time, f'{out_path}/run_time.txt')

    opt_params = find_best_params(accuracies, run_times, ks_runtimes) # TODO PASS AVERAGES OF ACCURACIES AND RUN TIMES!
    plot_params(accuracies, run_times, opt_params, outpath)

if __name__ == '__main__':
    main()

#  TODO WHY ARE THERE LESS BATCHES IN FINAL TEMPLATE MATCHING STEP???
#DONT DELETE DOCKERFILE