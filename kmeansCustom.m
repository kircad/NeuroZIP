function [assignments, silScores, clustSils] = kmeansCustom(ops, vectors)
        Nbatch = ops.Nbatch;
        
        silScores = zeros(1,Nbatch);
        if (Nbatch < ops.maxK * 2)
            limK = Nbatch / 2;
        else
            limK = ops.maxK;
        end
        bestAssignments = [];
        bestSilMean = 0;
        bestSilScores = [];
        bestClustSil = [];
        k = 2;
        maxIter = ops.kmeansMaxIter;
        Ks = zeros(1, maxIter);
        bestKcost = [];
        currIter = 1;
        while k <= limK %TODO MOVE ENTIRE LOOP TO GPU + VECTORIZE!!! CHANGE TO WHILE LOOP
            randIndices = randperm(Nbatch);
            centroids([1:k],:,:) = vectors(randIndices(1:k), :, :); %randomly initialize k clusters
            assignments = zeros(k,Nbatch);
            m = 1;
            prevCost = intmax('int64');
            while m < 100 
                costs = ones(k, Nbatch);
                costs = costs * double(intmax('int64'));
                for i = 1:Nbatch
                    for j = 1:k
                        cost = 0;
                        for n = 1:ops.batchPCS
                            cost = cost + sum((vectors(i, n, :) - centroids(j, n, :)) .^ 2); %euclidian method TODO SEPARATE KMEANS PER PC
                        end
                        costs(j, i) = cost;   
                    end
                end
                assignments = (costs == min(costs)); 
                smallClusts = find(sum(assignments,2) <= ops.clustMin)'; %CHECK IF ANY CLUSTERS ARE TOO SMALL -- smallclusts operates like a queue
                if ~isempty(smallClusts) %FOR NOW JUST HANDLE 1-UNIT CASE, deal with 0, n case later
                    while ~(isempty(smallClusts)) %FIND POINT(S) IN SMALL CLUSTER
                        batch = find(assignments(smallClusts(1),:));
                        if (isempty(batch))
                            k = k - 1;
                            assignments(smallClusts(1),:) = [];
                            centroids(smallClusts(1),:,:) = [];
                            costs(smallClusts(1),:) = [];
                            smallClusts = find(sum(assignments,2) <= ops.clustMin)'; %CHECK IF ANY CLUSTERS ARE TOO SMALL
                            continue;
                        end
                        centroidDists = ones(1,k);
                        centroidDists = centroidDists * 999;
                        for r = 1:size(assignments,1) %find closest cluster TODO FIND WAY TO REDUCE REDUNDANT CALCULATIONS TODO MAKE HELPER FUNCTIONS FOR GODS SAKE
                            if (r == smallClusts(1))
                                centroidDists(r) = 999;
                                continue
                            end
                            centroidDist = 0;
                            for n = 1:ops.batchPCS
                                centroidDist = centroidDist + sum((vectors(batch, n, :) - (centroids(r, n, :))) .^ 2); %euclidian method
                            end
                            centroidDists(r) = centroidDist;
                        end
                        closestCentroid = find(centroidDists == min(centroidDists)); %now merge with this centroid -- update assignments 
                        assignments(:, batch) = 0; %wipe old 
                        assignments(closestCentroid, batch) = 1; %replace with new one
                        assignments(smallClusts(1),:) = []; %now we are WIPING the clust we just emptied (1-case only)
                        centroids(smallClusts(1),:,:) = [];
                        costs(smallClusts(1),:) = [];
                        smallClusts = find(sum(assignments,2) <= ops.clustMin)'; %CHECK IF ANY CLUSTERS ARE TOO SMALL
                        k = k - 1;
                    end
                end
                for i =  1:k %get mean vector of each cluster
                    for n = 1:ops.batchPCS
                        centroids(i,n,:) = squeeze(mean(vectors(find(assignments(i,:) == 1), n, :),1)); %TODO GET RID OF FIND IF POSSIBLE;
                    end
                end
                currCost = sum(costs(assignments));
                if (currCost == prevCost) %convergence
                    break;
                end
                prevCost = currCost;
                m = m + 1;
            end
            currCost = sum(costs(assignments));
            bestKcost(k) = currCost;
            Ks(currIter) = k;
            for i = 1:size(assignments,2) %TODO PROBS MORE EFFICIENT TO DO THIS BY CLUSTER?
                clusterIdxs = find(assignments((assignments(:,i) == 1),:) == 1); %TODO TRY BUNDLING 3 VECTORS INTO ONE AVERAGE
                intraClust = 0;
                for z = 1:size(clusterIdxs,2)
                    for n = 1:ops.batchPCS
                        intraClust = intraClust + sum((vectors(i, n, :) - (vectors(clusterIdxs(z),n,:))) .^ 2); %euclidian method
                    end
                end
                intraClust = intraClust / size(clusterIdxs,2);
                centroidDists = [];
                for r = 1:size(assignments,1) %find closest cluster TODO FIND WAY TO REDUCE REDUNDANT CALCULATIONS 
                    if (r == find((assignments(:,i) == 1)))
                        centroidDists(r) = 999;
                        continue
                    end
                    centroidDist = 0;
                    for n = 1:ops.batchPCS
                        centroidDist = centroidDist + sum((vectors(i, n, :) - (centroids(r, n, :))) .^ 2); %euclidian method
                    end
                    centroidDists(r) = centroidDist;
                end
                closestCentroid = find(centroidDists == min(centroidDists));
                extraClusterIdxs = find(assignments(closestCentroid, :) == 1);
                extraClust = 0;
                for z = 1:size(extraClusterIdxs,2)
                    for n = 1:ops.batchPCS
                        extraClust = extraClust + sum((vectors(i, n, :) - vectors(extraClusterIdxs(z),n,:)) .^ 2); %euclidian method
                    end
                end
                extraClust = extraClust / size(extraClusterIdxs,2);
                silScores(i) = (extraClust - intraClust) / max(intraClust, extraClust);
            end
            clustSils = zeros(1, size(assignments,1));
            for i = 1:size(assignments,1) 
                clusterIdxs = find(assignments(i,:) == 1);
                clustSils(i) = sum(silScores(clusterIdxs)) / size(clusterIdxs,2);
            end     
            if (nanmean(clustSils) > bestSilMean)
                bestIter = currIter;
                bestClustSil = clustSils;
                bestSilScores = silScores;
                bestSilMean = nanmean(clustSils);
                bestAssignments = assignments;
                bestCost = currCost;
                diffs = diff(bestKcost);
                if (currIter == 1)
                    bestDiff = currCost;
                else
                    bestDiff = diffs(k-1); %TODO CHECK
                end
            end
            k = k + 1;
            currIter = currIter + 1;
            diffs = diff(bestKcost);
            if ((currIter > maxIter) && diffs(end) >= 0) %BOTH convergence AND maxIter hit : TODO add stdev condition for convergence?
                break;
            end
        end
        assignments = bestAssignments;
        if ops.plotDiagnostics
            hold on
            plot(1:max(Ks), bestKcost(1:max(Ks)), 'k')
            xlabel("Number of Clusters (k)");
            ylabel("Cost (Summed Euclidian Distance of Singular Vectors from k Selected Centroids)"); 
            title("Elbow Curve (k-means)");
            xline(size(assignments,1), 'r-.', 'LineWidth', 2);
            xlim([2 max(Ks)])
            text(size(assignments,1) + .25, max(bestKcost(1:max(Ks)))*0.6, 'Optimal K-value', 'Rotation', 90, 'FontWeight', 'bold');
            hold off
            savefig(fullfile(ops.plotPath, "kmeansElbowCurve.fig"));
            close();
            hold on
            plot(1:max(limK,currIter - 1), Ks);
            xlabel("K-means iteration");
            ylabel("Number of Clusters"); 
            title("Selected Clusters vs. Iteration (k-means)");
            xline(size(assignments,1), 'r-.', 'LineWidth', 2);
            text(bestIter + 0.25, max(Ks)*0.6, 'Optimal K-value', 'Rotation', 90, 'FontWeight', 'bold');
            hold off
            savefig(fullfile(ops.plotPath, "kMeansIterClusters.fig"))
            close();
            hold on
            bar(1:size(bestAssignments,1), bestClustSil, 'FaceColor', 'blue');
            xlabel("Cluster ID");
            ylabel("Silhouette Score"); 
            title("Cluster Silhouette Score (k-means)");
            yline(ops.clusterThreshold, 'r-.', 'LineWidth', 2);
            text(3, ops.clusterThreshold + 0.05, 'Cluster Silhouette Score Threshold', 'color','red','FontWeight','bold');
            savefig(fullfile(ops.plotPath, "clustSils.fig"))
            close();
        end
        
        clustSils = bestClustSil;
        silScores = bestSilScores;
        rez.bestCost = bestCost;
        rez.bestDiff = bestDiff;
end


%TODOS
%best method for picking unclustered representatives seems to be random or variance-- find others? 

%TODO IMPROVE METHOD BY WHICH REPRESENTATIVE BATCH IS SELECTED
    %TODO FOR SOME REASON PICKING WORST REPRESENTATIVE LEADS TO BETTER PERFORMANCE??? (may have hallucinated this)
  
%TODO MAKE SURE SELECTED BATCHES ARE REPRESENTATIVE (e.g. large
%clusters get more representatives than small ones)

%LOTS of ground truth testing

%ALSO DO KMEANS WITH AVERAGE BATCH NUMBER OF EACH REMAINING CLUSTER TO CONSIDER TEMPORALITY?

%TODO INCREASE YSPACING TO CUSTOM- IMPROVE VISUALIZATION QUALITY (highlight different clusters somehow)

%TODO FIX DYNAMIC - SHOULD AT LEAST MATCH PERFORMANCE OF ALL FOR NEWUNIT1 

%TODO TRY A HIERARCHICAL CLUSTERING ALGORITHM LIKE HDBSCANTODO TRY KMEANS++
