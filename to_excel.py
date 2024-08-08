import pandas as pd
import os

inputs = ['C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/Magland Data/PAIRED_BOYDEN/',
          'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/Magland Data/PAIRED_CRCNS_HC1/',
          'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/Magland Data/PAIRED_ENGLISH/',
          'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/Magland Data/PAIRED_KAMPFF/']
for i in inputs:
    input_csv_file = f'{i}/kilosort_ground_truth_comparison.txt'
    df = pd.read_csv(input_csv_file, sep = ' ')

    # Define the output file name
    output_file = f'{i}/comparison.xlsx'
    if os.path.exists(output_file):
        os.remove(output_file)

    # Write the DataFrame to an Excel file
    df.to_excel(output_file, index=False, engine='openpyxl')