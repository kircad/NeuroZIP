function [algo, bestClusts, bestScores, bestPCbin, PCReduction] = clustering(ops, currU, title)
    kscores = zeros(1, ops.batchPCS);
    dbscores = zeros(1, ops.batchPCS);
    cd(ops.outputPath);
    
    savePath = strcat(title, ".csv");
    writematrix(cat(1, 1:ops.Nchan,currU), savePath);

    [reduction, ~, DBclusters, ~] = run_umap(char(savePath), 'cluster_detail', 'adaptive'); %TODO WHAT DOES CLUSTER DETAIL ACTUALLY MEAN?
    savefig(fullfile(ops.plotPath, strcat(title, ".fig")));
    close("all") %TODO MAKE SURE BATCH ORDER ISNT SCREWED UP (highly doubt)

    [Kclusters, kCentroids] = kmeans(reduction,max(DBclusters)); %TODO PLAY WITH OPTIONS/NUMBER OF CLUSTERS, 

    hold on
    figure
    subplot(1, 2, 1);
    [kmeanScore, ~] = silhouette(currU, Kclusters,'euclidean');
    title(strcat(title, " Kmeans Silhouette Scores"));

    subplot(1, 2, 2);
    [dbScore, ~] = silhouette(currU, DBclusters,'euclidean');
    title(strcat(title, " DBSCAN Silhouette Scores"));

    savefig(fullfile(ops.plotPath, strcat("SilDBPC ", title, ".fig")));
    hold off
    close("all")

    if ops.plotDiagnostics
        figure;
        DBclustsunique = sort(unique(DBclusters));
        kclustsunique = sort(unique(Kclusters));
        clustCols = arrayfun(@(x) [], 1:max(size(DBclustsunique,2), size(kclustsunique,2)), 'UniformOutput', false);
        clustLabels = arrayfun(@(x) [], 1:max(size(DBclustsunique,2), size(kclustsunique,2)), 'UniformOutput', false);

        subplot(1, 2, 1);

        hold on
        for n = 1:size(DBclustsunique, 2)
            col = rand(1, 3);
            clustCols{n} = col;
            clustLabels{n} = strcat("Cluster ", string(n));
            scatter(reduction(DBclusters == n,1)', reduction(DBclusters == n,2)','MarkerFaceColor', col);
            dbCentroid = mean(reduction(DBclusters == n,:));

            scatter(dbCentroid(1), dbCentroid(2), 100, 'filled', 'black', 'HandleVisibility', 'Off');
            text(dbCentroid(1) + 1, dbCentroid(2) - 1, string(mean(dbScore(DBclusters == n))), 'FontWeight','bold');
        end
        title(strcat("PC ", title, " DBSCAN Cluster Assignments"));
        legend(clustLabels);
        hold off
        %TODO make sure cluster assignment colors stay
        %consistent (ex. label based on centroid not the
        %arbitrary cluster numbers the algorithm spits out
        subplot(1, 2, 2);
        hold on
        title(strcat("PC ", title, " Kmeans Cluster Assignments"));
        for n = 1:size(kclustsunique', 2)
            if (n > size(DBclustsunique, 2))
                clustCols{n} = rand(1);
                clustLabels{n} = strcat("Cluster ", string(n));
            end
            col = clustCols{n};

            scatter(reduction(Kclusters == n,1)', reduction(Kclusters == n,2)', 'MarkerFaceColor', col);
            scatter(kCentroids(n,1), kCentroids(n,2), 100, 'filled', 'black', 'HandleVisibility', 'Off');
            text(kCentroids(n,1) + 1, kCentroids(n,2) - 1, string(mean(kmeanScore(Kclusters == n))), 'FontWeight','bold');
        end
        legend(clustLabels);
        hold off

        savefig(fullfile(ops.plotPath, strcat("Cluster Assignments PC ", title, ".fig")));
        close("all")
    end
    kscore = sum(kmeanScore > ops.clusterThreshold);
    dbscore = sum(dbScore > ops.clusterThreshold);
    if (kscore > dbscore)
        bestPCbin = makeBinaryMats(Kclusters');
        bestClusts = DBclusters;
        bestScores = dbscores;
        algo = "kmeans";
    else
        bestPCbin = makeBinaryMats(DBclusters);
        bestClusts = Kclusters;
        bestScores = kscores;
        algo = "DBSCAN";
    end
    PCReduction = reduction;
    %TODO DELETE CSVS
    %TODO ADD MORE CLUSTERING METHODS, DISTANCE METRICS, ETC ETC)
    %(try to see if you can improve kmeans)
end