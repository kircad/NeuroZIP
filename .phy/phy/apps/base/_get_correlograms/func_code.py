# first line: 1473
    def _get_correlograms(self, cluster_ids, bin_size, window_size):
        """Return the cross- and auto-correlograms of a set of clusters."""
        spike_ids = self.selector(self.n_spikes_correlograms, cluster_ids)
        st = self.model.spike_times[spike_ids]
        sc = self.supervisor.clustering.spike_clusters[spike_ids]
        return correlograms(
            st, sc, sample_rate=self.model.sample_rate, cluster_ids=cluster_ids,
            bin_size=bin_size, window_size=window_size)
