function rez = mergeClusts(ops, rez)
    %creates an Nbatch x Nbatch consensus matrix containing combined
    %similarity matrices of all clustering assignment pairs
    %then runs clustering on these clusters to find merged cluster
    %assignments
    %then graphs against each PC (if plot.diagnostics enabled), just save
    %end result if it isnt
    consensusPairwise = zeros(ops.Nbatch,ops.Nbatch);
    for i = 1:size(rez.bestPCbins,2)
        consensusPairwise = consensusPairwise + rez.bestPCbins{i};
    end
    consensusPairwise = consensusPairwise / size(rez.bestPCbins,2);
    rez.consensusPairwise = consensusPairwise;
    if ops.pcmerge
        savePath = strcat("Final.csv");
        writematrix(cat(1, 1:ops.Nbatch,consensusPairwise), savePath);

        [reduction, umap, DBclusters, extras] = run_umap(char(savePath), 'cluster_detail', 'adaptive'); %TODO WHAT DOES CLUSTER DETAIL ACTUALLY MEAN?
        [Kclusters, kCentroids] = kmeans(reduction,max(DBclusters)); %TODO PLAY WITH OPTIONS/NUMBER OF CLUSTERS, 
        %TODO WHY IS CLUSTERING SO WACK
        
        rez.finalDBClusts = DBclusters;
        rez.finalKClusts = Kclusters;
    end
end