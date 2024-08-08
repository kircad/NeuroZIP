function [algo, bestClusts, bestMeanClustScores, bestScore, bestPCbin, PCReduction] = clustering(ops, currU, myTitle)
    cd(ops.outputPath);
    
    savePath = strcat(myTitle, ".csv");
    writematrix(cat(1, 1:ops.Nchan,currU), savePath);

    [reduction, ~, DBclusters, ~] = run_umap(char(savePath), 'cluster_detail', 'adaptive'); %TODO WHAT DOES CLUSTER DETAIL ACTUALLY MEAN?
    savefig(fullfile(ops.plotPath, strcat(myTitle, ".fig")));
    close("all") %TODO MAKE SURE BATCH ORDER ISNT SCREWED UP (highly doubt)
    
    if (size(currU,1) < ops.maxK * 4)
        limK = floor(size(currU,1) / 4);
    else
        limK = ops.maxK;
    end
    currIter = 1;
    bestscore = -1;
    bestAssignments = [];
    k = 2;
    while k <= limK
        [idx, C, ~, D] = kmeans(reduction,k, 'Start', 'plus'); %TODO OPTIMIZE/PARALLELIZE
        idx = idx';
        uniqueK = unique(idx);
        for j = 1:uniqueK
            idxs = find(idx == j);
            if (size(idxs,2) <= ops.clustMin)            
                [~, nearestCluster] = min(D(:, j));
                idx(j) = nearestCluster;
                k = k - 1;
                idx(idx > j) = idx(idx > j) - 1; %TODO CHECK- should just move push all assignments > than the one removed back to fill empty space
            end
        end
        currScore = silhouette(currU, idx,'euclidean');
        if (mean(currScore) > mean(bestscore))
            bestscore = currScore;
            bestAssignments = idx;
            kCentroids = C;
        end
        if (currIter >= ops.kmeansMaxIter) %TODO add convergence condition
            break;
        end
        k = k + 1;
        currIter = currIter + 1;
    end
    Kclusters = bestAssignments;
    
    hold on
    figure
    subplot(1, 2, 1);
    [kmeanScore, ~] = silhouette(currU, Kclusters,'euclidean'); %
    title(strcat(myTitle, " Kmeans Silhouette Scores"));

    subplot(1, 2, 2);
    [dbScore, ~] = silhouette(currU, DBclusters,'euclidean');
    title(strcat(myTitle, " DBSCAN Silhouette Scores"));

    savefig(fullfile(ops.plotPath, strcat("SilDBPC ", myTitle, ".fig")));
    hold off
    close("all")

    if ops.plotDiagnostics
        figure;
        DBclustsunique = sort(unique(DBclusters));
        kclustsunique = sort(unique(Kclusters));
        clustCols = arrayfun(@(x) [], 1:max(size(DBclustsunique,2), size(kclustsunique,2)), 'UniformOutput', false);
        clustLabels = arrayfun(@(x) [], 1:min(size(DBclustsunique,2), size(kclustsunique,2)), 'UniformOutput', false);

        subplot(1, 2, 1);

        hold on
        for n = 1:size(DBclustsunique, 2)
            col = rand(1, 3);
            clustCols{n} = col;
            clustLabels{n} = strcat("Cluster ", string(n));
            scatter(reduction(DBclusters == n,1)', reduction(DBclusters == n,2)','MarkerFaceColor', col);
            dbCentroid = mean(reduction(DBclusters == n,:),1);

            scatter(dbCentroid(1), dbCentroid(2), 100, 'filled', 'black', 'HandleVisibility', 'Off');
            text(dbCentroid(1) + 1, dbCentroid(2) - 1, string(mean(dbScore(DBclusters == n))), 'FontWeight','bold');
        end
        title(strcat("PC ", myTitle, " DBSCAN Cluster Assignments"));
        legend(clustLabels);
        hold off
        %TODO make sure cluster assignment colors stay
        %consistent (ex. label based on centroid not the
        %arbitrary cluster numbers the algorithm spits out
        subplot(1, 2, 2);
        hold on
        title(strcat("PC ", myTitle, " Kmeans Cluster Assignments"));
        for n = 1:size(kclustsunique, 2)
            if (n > size(DBclustsunique, 2))
                clustCols{n} = rand(1, 3);
                clustLabels{n} = strcat("Cluster ", string(n));
            end
            col = clustCols{n};

            scatter(reduction(Kclusters == n,1)', reduction(Kclusters == n,2)', 'MarkerFaceColor', col);
            scatter(kCentroids(n,1), kCentroids(n,2), 100, 'filled', 'black', 'HandleVisibility', 'Off');
            text(kCentroids(n,1) + 1, kCentroids(n,2) - 1, string(mean(kmeanScore(Kclusters == n))), 'FontWeight','bold');
        end
        legend(clustLabels);
        hold off

        savefig(fullfile(ops.plotPath, strcat("Cluster Assignments PC ", myTitle, ".fig")));
        close("all")
    end
    kscore = sum(kmeanScore > ops.clusterThreshold);
    dbscore = sum(dbScore > ops.clusterThreshold);
    if (kscore >= dbscore)
        algo = "KMEANS";
        bestPCbin = makeBinaryMats(Kclusters'); %TODO FIX - DOESNT WORK WHEN NUMCLUSTS IS LARGE
        bestClusts = Kclusters;
        bestScore = kmeanScore;
    else
        algo = "DBSCAN";
        bestPCbin = makeBinaryMats(DBclusters);
        bestClusts = DBclusters;
        bestScore = dbScore;
    end
    PCReduction = reduction;
    bestMeanClustScores = zeros(1,size(unique(bestClusts),2));
    for i = 1:size(unique(bestClusts), 2)
        bestMeanClustScores(i) = mean(kmeanScore(bestClusts == i));
    end
    %TODO DELETE CSVS
    %TODO ADD MORE CLUSTERING METHODS, DISTANCE METRICS, ETC ETC)
    %(try to see if you can improve kmeans)
end