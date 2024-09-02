import configparser
import spikeinterface.sorters as ss

def read_config(file_path='config.ini'):
    config = configparser.ConfigParser()
    config.read(file_path)
    return config

config = read_config()

# Reading string values
log_level = config['DEFAULT']['LOG_LEVEL']
db_host = config['DATABASE']['HOST']

# Reading integer values
db_port = config.getint('DATABASE', 'PORT')
api_timeout = config.getint('API', 'TIMEOUT')

# Reading boolean values
debug_mode = config.getboolean('DEFAULT', 'DEBUG')
enable_caching = config.getboolean('FEATURES', 'ENABLE_CACHING')

# Reading float values (if you have any)
# some_float = config.getfloat('SECTION', 'FLOAT_KEY')

# Printing some values to verify
print(f"Log Level: {log_level}")
print(f"Database: {db_host}:{db_port}")
print(f"API Timeout: {api_timeout} seconds")
print(f"Debug Mode: {debug_mode}")
print(f"Caching Enabled: {enable_caching}")

# Accessing a value that might not exist (with a fallback)
fallback_value = config.get('FEATURES', 'UNKNOWN_SETTING', fallback='DefaultValue')
print(f"Unknown Setting: {fallback_value}")



ss.KilosortSorter.set_kilosort_path('/home/kirca/NeuroZIP/KiloSort/')
ss.NeuroZIP_KilosortSorter.set_nzkilosort_path('/home/kirca/NeuroZIP/neurozip-kilosort')
calc_sortings = True
run_offset_tests = False
run_hyperparameter_sweep = True
full_comps, full_runtimes, full_comp_variations, full_runtime_variations = {}, {}, {}, {} # TODO MIGHT BE BETTER TO JUST MAKE THIS ONE BIG PD DATAFRAME!
params = {'kilosort' : {} , 'neurozip_kilosort' : {'method': 'linspace', 'spacing' : 5, 'batch_size' : (base_batch_size * 5) + buffer_size}}
overwrite = {'kilosort': False, 'neurozip_kilosort': False}
basepaths = {'kilosort': '/home/kirca/NeuroZIP/kilosort_baseline', 'neurozip_kilosort': '/home/kirca/NeuroZIP/test'}
analysis_path = '/home/kirca/NeuroZIP/spikeforest_results'