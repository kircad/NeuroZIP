function PCclustering(ops, rez)
    batchUs = rez.batchUs;
    kscores = zeros(1, ops.batchPCS);
    dbscores = zeros(1, ops.batchPCS);
    PCReductions = arrayfun(@(x) [], 1:ops.batchPCS, 'UniformOutput', false);
    cd(ops.outputPath); %TODO MAKE ALL THIS ITS OWN FUNCTION
    for i = 1:ops.batchPCS %save to csv then UMAP for each set of singular vectors
        savePath = strcat("PC ", string(i), ".csv");
        currU = permute(batchUs(:,i,:), [1 3 2]);
        writematrix(cat(1, 1:ops.Nchan,currU), savePath);
        [reduction, umap, DBclusters, extras] = run_umap(char(savePath), 'cluster_detail', 'adaptive'); %TODO WHAT DOES CLUSTER DETAIL ACTUALLY MEAN?
        savefig(fullfile(ops.plotPath, strcat("UMAP PC ", string(i), ".fig")));

        Kclusters = kmeans(currU,max(DBclusters)); %TODO PLAY WITH OPTIONS/NUMBER OF CLUSTERS
        close("all") %TODO MAKE SURE BATCH ORDER ISNT SCREWED UP (highly doubt)

        hold on
        figure
        subplot(1, 2, 1);
        [kmeanScore, ~] = silhouette(currU, Kclusters,'euclidean');
        title(strcat("PC ", string(i), " Kmeans Silhouette Scores"));

        subplot(1, 2, 2);
        [dbScore, ~] = silhouette(currU, DBclusters,'euclidean');
        title(strcat("PC ", string(i), " DBSCAN Silhouette Scores"));

        savefig(fullfile(ops.plotPath, strcat("SilDBPC ", string(i), ".fig")));
        hold off
        close("all")

        if ops.plotDiagnostics
            figure;

            subplot(1, 2, 1);
            DBclustsunique = sort(unique(DBclusters));
            kclustsunique = sort(unique(Kclusters));
            clustCols = arrayfun(@(x) [], 1:max(size(DBclustsunique,2), size(kclustsunique,2)), 'UniformOutput', false);
            clustLabels = arrayfun(@(x) [], 1:max(size(DBclustsunique,2), size(kclustsunique,2)), 'UniformOutput', false);
            hold on
            for n = 1:size(DBclustsunique, 2)
                col = rand(1, 3);
                clustCols{n} = col;
                clustLabels{n} = strcat("Cluster ", string(n));
                scatter(reduction(DBclusters == n,1)', reduction(DBclusters == n,2)','MarkerFaceColor', col);
            end
            title(strcat("PC ", string(i), " DBSCAN Cluster Assignments"));
            legend(clustLabels);
            hold off
            %TODO make sure cluster assignment colors stay
            %consistent (ex. label based on centroid not the
            %arbitrary cluster numbers the algorithm spits out
            subplot(1, 2, 2);
            hold on
            title(strcat("PC ", string(i), " Kmeans Cluster Assignments"));
            for n = 1:size(kclustsunique', 2)
                if (n > size(DBclustsunique, 2))
                    clustCols{n} = rand(1);
                    clustLabels{n} = strcat("Cluster ", string(n));
                end
                col = clustCols{n};
                scatter(reduction(Kclusters == n,1)', reduction(Kclusters == n,2)', 'MarkerFaceColor', col);
            end
            legend(clustLabels);
            hold off

            savefig(fullfile(ops.plotPath, strcat("Cluster Assignments PC ", string(i), ".fig")));
            close("all")
        end

        kscores(i) = sum(kmeanScore > ops.clusterThreshold);
        dbscores(i) = sum(dbScore > ops.clusterThreshold);
        PCReductions{i} = reduction;
    end
    rez.kscores = kscores;
    rez.dbscores = dbscores;
    rez.PCReductions = PCReductions;
    rez.DBClusters = DBclusters;
    rez.Kclusters = Kclusters;
    rez.umap = umap;
    rez.extras = extras;
end