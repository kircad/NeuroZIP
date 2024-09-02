# first line: 1482
    def _get_correlograms_rate(self, cluster_ids, bin_size):
        """Return the baseline firing rate of the cross- and auto-correlograms of clusters."""
        spike_ids = self.selector(self.n_spikes_correlograms, cluster_ids)
        sc = self.supervisor.clustering.spike_clusters[spike_ids]
        return firing_rate(
            sc, cluster_ids=cluster_ids, bin_size=bin_size, duration=self.model.duration)
