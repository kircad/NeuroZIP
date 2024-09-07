def write_runtime_to_file(run_time, filepath):
    with open(filepath, 'w') as file:
        file.write(str(run_time))

def read_runtime_from_file(filepath):
    with open(filepath, 'r') as file:
        number = file.read()
    return float(number)