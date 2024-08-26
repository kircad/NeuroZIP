from scipy.sparse.linalg import svds
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score, silhouette_samples
import numpy as np

def compress_data(ops, preprocessed_batches):
    match (ops['method']):
        case 'linear':
            print("Starting linear subsampling")
            selected_batches = list(range(ops['starting'], len(preprocessed_batches), ops['spacing']))
        case 'numSpikes':
            pass
        case 'entropy':
            pass
        case 'variance':
            pass
        case 'dynamic': #  this is kmeans/clustering stuff
            preprocessed_batches = [np.asarray(matrix, dtype=float) for matrix in preprocessed_batches[0:-1]]
            out  = [svds(matrix, k=1) for matrix in preprocessed_batches[0:-1]]
            rank1s = [(decomp[0] @ np.diag(decomp[1]) @ decomp[2]) for decomp in out]
            X = np.vstack([U.reshape(1, -1) for U in rank1s])

            n_clusters = 20
            kmeans = KMeans(n_clusters=n_clusters, random_state=42)
            cluster_labels = kmeans.fit_predict(X)
            silhouette_avg_scores = []
            silhouette_cluster_scores = []

            for n_clusters in np.unique(cluster_labels):
                
                silhouette_avg = silhouette_score(X, cluster_labels)
                silhouette_avg_scores.append(silhouette_avg)
                
                sample_silhouette_values = silhouette_samples(X, cluster_labels)
                
                cluster_silhouette_scores = []
                for i in range(n_clusters):
                    cluster_silhouette_scores.append(
                        sample_silhouette_values[cluster_labels == i].mean())
                
                silhouette_cluster_scores.append(cluster_silhouette_scores)
            print("SVD")

    return selected_batches

# TODO probably a good idea to do lazy loading