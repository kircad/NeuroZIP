from ks4sim.simulation import create_simulation
from parse_config import local_recordings

def main():
    create_simulation(f'{local_recordings}/sim.dat', st, cl, wfs, wfs_x, contaminations, # TODO WHAT IS THIS SAVED AS?
                      n_sim=100, n_noise=1000, n_batches=500,
                      batch_size=60000, tsig=50, tpad=100, n_chan_bin=385, drift=True,
                      drift_range=5, drift_seed=0, fast=False, step=False,
                      ups=10, whiten_mat = None,
                             ) # TODO SET PARAMS

if __name__ == '__main__':
    main()
