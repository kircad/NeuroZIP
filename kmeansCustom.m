function [assignments, silScores, clustSils] = kmeansCustom(ops, vectors)
        Nbatch = ops.Nbatch;
        
        silScores = zeros(1,Nbatch);
        if (Nbatch < ops.maxK * 2)
            limK = Nbatch / 2;
        else
            limK = ops.maxK;
        end
        mastCosts = ones(1, limK);
        mastCosts = mastCosts + 999;
        bestAssignments = [];
        bestSilMean = 0;
        bestSilScores = [];
        bestClustSil = [];
        for k = 2:limK %TODO MOVE ENTIRE LOOP TO GPU + VECTORIZE!!!
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
                            cost = cost + sum((vectors(i, n, :) - centroids(j, n, :)) .^ 2); %euclidian method
                        end
                        costs(j, i) = cost;   
                    end
                end
                assignments = (costs == min(costs)); 
                smallClusts = find(sum(assignments,2) <= ops.clustMin); %CHECK IF ANY CLUSTERS ARE TOO SMALL
                if ~isempty(smallClusts) %FOR NOW JUST HANDLE 1-UNIT CASE, deal with 0, n case later
                    for z = 1:size(smallClusts,2) %FIND POINT(S) IN SMALL CLUSTER
                        batch = find(assignments(smallClusts(z),:));
                        if (isempty(batch))
                            continue
                        end
                        centroidDists = [];
                        for r = 1:size(assignments,1) %find closest cluster TODO FIND WAY TO REDUCE REDUNDANT CALCULATIONS TODO MAKE HELPER FUNCTIONS FOR GODS SAKE
                            if (r == smallClusts(z))
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
            mastCosts(k-1) = sum(costs(assignments)); 
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
            clustSils = [];
            for i = 1:size(assignments,1) 
                clusterIdxs = find(assignments(i,:) == 1);
                clustSils(i) = sum(silScores(clusterIdxs)) / size(clusterIdxs,2);
            end
            if (nanmean(clustSils) > bestSilMean)
                bestClustSil = clustSils;
                bestSilScores = silScores;
                bestSilMean = nanmean(clustSils);
                bestAssignments = assignments;
            end
        end
        assignments = bestAssignments;
        clustSils = bestClustSil;
        silScores = bestSilScores;
        rez.assignments = assignments;
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
