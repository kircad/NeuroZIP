import configparser
import spikeinterface.sorters as ss

def read_config(file_path='local_config.ini'):
    config = configparser.ConfigParser()
    config.read(file_path)
    return config

config = read_config()

# Paths
kilosort_path = config['PATHS']['KILOSORT_PATH']
neuroZIP_path = config['PATHS']['NEUROZIP_PATH']
analysis_path = config['PATHS']['ANALYSIS_PATH']
tmp_path = config['PATHS']['TMP_PATH']
local_recordings = config['PATHS']['LOCAL_RECORDINGS']

# Sorting settings
calc_sortings = config.getboolean('SORTING', 'CALC_SORTINGS')
run_offset_tests = config.getboolean('SORTING', 'RUN_OFFSET_TESTS')
run_hyperparameter_sweep = config.getboolean('SORTING', 'RUN_HYPERPARAMETER_SWEEP')

# Kilosort and NeuroZIP settings
ss.KilosortSorter.set_kilosort_path(kilosort_path)
ss.NeuroZIP_KilosortSorter.set_nzkilosort_path(neuroZIP_path)

params = {
    'kilosort': {},
    'neurozip_kilosort': {
        'method': config['NEUROZIP_KILOSORT']['METHOD'],
        'spacing': config.getint('NEUROZIP_KILOSORT', 'SPACING'),
        'batch_size': (config.getint('BATCH_SETTINGS', 'BASE_BATCH_SIZE') * 5) + config.getint('BATCH_SETTINGS', 'BUFFER_SIZE')
    }
}

overwrite = {
    'kilosort': config.getboolean('KILOSORT', 'OVERWRITE'),
    'neurozip_kilosort': config.getboolean('NEUROZIP_KILOSORT', 'OVERWRITE')
}

basepaths = {
    'kilosort': config['KILOSORT']['BASE_PATH'],
    'neurozip_kilosort': config['NEUROZIP_KILOSORT']['BASE_PATH']
}

# Datasets and extensions
datasets = config['DATASETS']['NAMES'].split(', ')
extensions_to_compute = config['EXTENSIONS']['COMPUTE'].split(', ')

extension_params = {
    "unit_locations": {"method": config['EXTENSION_PARAMS']['UNIT_LOCATIONS_METHOD']},
    "spike_locations": {"ms_before": config.getfloat('EXTENSION_PARAMS', 'SPIKE_LOCATIONS_MS_BEFORE')},
    "correlograms": {"bin_ms": config.getfloat('EXTENSION_PARAMS', 'CORRELOGRAMS_BIN_MS')},
    "template_similarity": {"method": config['EXTENSION_PARAMS']['TEMPLATE_SIMILARITY_METHOD']}
}

columns = config['COLUMNS']['NAMES'].split(', ')

# Batch settings
base_batch_size = config.getint('BATCH_SETTINGS', 'BASE_BATCH_SIZE')
buffer_size = config.getint('BATCH_SETTINGS', 'BUFFER_SIZE')
max_concurrent_jobs = config.getint('BATCH_SETTINGS', 'MAX_CONCURRENT_JOBS')

# Miscellaneous
use_downloaded = config.getboolean('MISC', 'USE_DOWNLOADED')
n_runs = config.getint('MISC', 'N_RUNS')