function [finalAssignments, finalCluScores, finalCluIndividual, unclusterable] = optimizeClusters(ops, rez, pc, batches)
    iter = 1;
    cluID = 1;
    unclusteredIdxs = {};
    unclusteredIdxs{1} = batches;
    finalAssignments = zeros(1, ops.Nbatch);
    finalCluScores = [];
    finalCluIndividual = {};
    unclusterable = [];
    while ~isempty(unclusteredIdxs) %now subcluster bad clusters by PC1 or meanPCs (TODO figure out method to use all PCs?) TODO add some kind of convergence condition
        currIdxs = unclusteredIdxs{1};
        if size(currIdxs,2) < ops.minOptimizationBatches
            unclusterable = [unclusterable, currIdxs];
            unclusteredIdxs = unclusteredIdxs(2:end);
            continue;
        end
        myTitle = sprintf("Bad Cluster. Iteration %d", iter);
        if (ops.meanPCs || pc == -1)
            currU = rez.batchUs(currIdxs,:,:);
            meanPCs = zeros(size(currIdxs,2), ops.Nchan);
            for i = 1:ops.batchPCS
                meanPCs = meanPCs + permute(currU(:,i,:), [1 3 2]);
            end
            meanPCs = meanPCs / ops.batchPCS;
            [~, currAssignments, currBestClustScores, currMainPCBestScoresIndividual, ~, ~] = clustering(ops, meanPCs, myTitle);                    
        else %JUST USES 1ST PC
            [~, currAssignments, currBestClustScores, currMainPCBestScoresIndividual, ~, ~] = clustering(ops, permute(rez.batchUs(currIdxs,pc,:), [1 3 2]), myTitle);                    
        end

        for i = 1:size(currBestClustScores, 2)
            if (isnan(currBestClustScores(i))|| currBestClustScores(i) < ops.clusterThreshold)
                unclusteredIdxs{end + 1} = currIdxs(currAssignments == i);
            else
                finalAssignments(currIdxs(currAssignments == i)) = cluID;
                finalCluScores(cluID) = currBestClustScores(i);
                finalCluIndividual{cluID} = currMainPCBestScoresIndividual(currAssignments == i);
                cluID = cluID + 1;
            end %TODO HOW TO HANDLE 1-CLUSTS? I THOUGHT K-MEANS WASNT SUPPOSED TO ALLOW!
        end
        unclusteredIdxs = unclusteredIdxs(2:end);
        iter = iter + 1;
    end
end