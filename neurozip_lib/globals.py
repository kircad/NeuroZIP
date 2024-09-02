#use_saved = {'SORTER': True, 'ANALYZER': True}
#use_docker = {'kilosort': False, 'neurozip_kilosort': False}
datasets = ['PAIRED_CRCNS_HC1', 'PAIRED_ENGLISH', 'PAIRED_BOYDEN', 'PAIRED_KAMPFF'] #  TODO MAKE WORK FOR OTHER DATASETS!
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
columns = ['Accuracy', 'Precision', 'Recall', 'Miss_Rate', 'False_Discovery_Rate']
tmp_path = 'C:/Users/kirca_t5ih59c/Desktop/tmp'

base_batch_size = 16 * 1024
buffer_size = 64
max_concurrent_jobs = 2
local_recordings = 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/local_recordings'
use_downloaded = False
n_runs = 8