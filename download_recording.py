#!/usr/bin/env python

# pip install --upgrade kachery

import json
import argparse
import numpy as np
import kachery_cloud as ka
import os
import shutil
import spikeforest as sf
import spikeinterface.extractors as se
from spikeforest.load_extractors.MdaRecordingExtractorV2.MdaRecordingExtractorV2 import readmda

def main():
    """
    This function reads all the recordings from spikeforest recording dataset.
    creates a directory tree that stores the data by study set name -> study name.
    it downloads each datasets parameters (fire rate, sample rate etc), and than each recording raw data.

    kachery_cloud downloads all the raw data to .kachery-cloud directory in your home directory.

    so we the download and copying of the data to the script generated directory tree, it deletes it from the .kachery-cloud,
    inorder to avoid duplication for files across your file system
    """
    parser = argparse.ArgumentParser(
        description="down load all the raw data recordings from spikeforest datasets")
    parser.add_argument('--output_dir', help='The output directory (e.g., recordings)')
    # parser.add_argument('--verbose', action='store_true', help='Turn on verbose output')

    basedir = 'C:/Users/kirca_t5ih59c/Desktop/NeuroZIP/local_recordings'
    all_recordings = sf.load_spikeforest_recordings()
    if not os.path.exists(basedir):
        os.mkdir(basedir)
    recordings = []
    for R in all_recordings:
        print('STUDY: {}'.format(R.study_name))
        studydir_local = os.path.join(basedir, R.study_name, R.recording_name)
        recpath = os.path.join(studydir_local, 'recording')
        recordings.append({'study_name' : R.study_name, 'study_set_name': R.study_set_name, 'recording_name': R.recording_name})
        if not os.path.exists(recpath):
            os.makedirs(recpath)
        else:
            continue
        rec = R.get_recording_extractor()
        rec.save_to_folder(recpath, overwrite=True)
        se.NpzSortingExtractor.write_sorting(R.get_sorting_true_extractor(), f'{studydir_local}/sorting_true')
    with open(f'{basedir}/master.json', 'w') as file:
            json.dump(recordings, file, indent=4)

if __name__ == '__main__':
    main()