function rez = compressData(ops)
    rng('default');
    rng(1);
    
    %figure out batch size according to size of file+memory allocated
    %(Pachitariu code)
    NT  	= ops.NT;
    fid = fopen(ops.fproc, 'r');
    d = dir(ops.fproc);
    ops.sampsToRead = floor(d.bytes/ops.Nchan/2);

    if ispc
        dmem         = memory;
        memfree      = dmem.MemAvailableAllArrays/8;
        memallocated = min(ops.ForceMaxRAMforDat, dmem.MemAvailableAllArrays) - memfree;
        memallocated = max(0, memallocated);
    else
        memallocated = ops.ForceMaxRAMforDat;
    end
    ops.easterEgg = 1; %if you found this, thank you for looking into my code so carefully :D TODO move this somewhere else lol i have too much time on my hands
    ops.easterEggPath = 'C:\Users\kirca\Desktop\NeuroZIP\assets'; 
    nint16s      = memallocated/2;
    NTbuff      = NT + 4*ops.ntbuff;
    Nbatch      = ceil(d.bytes/2/ops.Nchan /(NT));
    Nbatch_buff = floor(4/5 * nint16s/ops.Nchan /(NT)); % factor of 4/5 for storing PCs of spikes TODO use this?
    Nbatch_buff = min(Nbatch_buff, Nbatch);
    Nchan 	= ops.Nchan;
    batchstart = 0:NT:NT*Nbatch;
    ops.Nbatch = Nbatch;
    ops.NTbuff = NTbuff;
    fprintf("Beginning %s sampling...\n", ops.batchSetting)
    switch ops.batchSetting 
        case 'numSpikes'
            iperm = sortrows(ops.batchSpikes,2,'descend'); %TODO MAKE THIS WORK INDEPENDENTLY OF KS1
            iperm = iperm(1:round(Nbatch/ops.batchFactor));
        case 'linspace'
            iperm = 1:ops.spacing:Nbatch;
        case 'random'
            iperm = randperm(Nbatch, round(Nbatch/ops.batchFactor));
        case 'entropy' %use UMAP clusters?
            batchRanks = []; 
            for i = 1:Nbatch
                
                offset = max(0, 2*NchanTOT*((NT - ops.ntbuff) * (ibatch-1) - 2*ops.ntbuff));
                fseek(fid, offset, 'bof');
                dat = fread(fid, [NTbuff ops.Nchan], '*int16');
                if ops.GPU
                    dataRAW = gpuArray(dat);
                else
                    dataRAW = dat;
                end
                dataRAW = dataRAW';
                dataRAW = single(dataRAW);
                dataRAW = dataRAW(:, chanMapConn);
                %TODO IMPLEMENT
                %COULD TRY MUTUAL INFORMATION AS DESCRIBED IN BEGGS 2004 (CRITICALITY PAPER)
                %(k-means it or just do nested for loop comparing all) OR JUST HIGHEST ENTROPY (use eigenvalues?)

            end
            iperm = sortrows(batchRanks,2,'descend');
            iperm = iperm(1:round(Nbatch/ops.batchFactor));
        case 'variance' %THIS GIVES 28/30 CELLS FOR BATCH FACTOR OF 4 ON 1000 S OF SIMULATED DATA, COMPARED TO 26 FOR RANDOM
            iperm = sortByVar(ops, numBatch);
        case 'dynamic'
            batchUs = get_SVDs(ops, batchstart, fid); %TODO FIGURE OUT WHAT TO DO WITH BATCHVS
            fprintf("SVD Complete. Running UMAP + PC-level clustering algorithm...\n")
            rez.batchUs = batchUs;
            %rez.batchVs = batchVs;
            meanPCs = zeros(ops.Nbatch, ops.Nchan);
            for i = 1:ops.batchPCS
                meanPCs = meanPCs + permute(rez.batchUs(:,i,:), [1 3 2]);
            end
            meanPCs = meanPCs / ops.batchPCS;
            title = sprintf("Top %d PCs Averaged", ops.batchPCS); %THIS IS THE MAIN GRAPH + MAIN ASSIGNMENTS: UPDATE THESE IN LOOP
            [rez.mainAlg, rez.mainPCBestClustAssignments, rez.mainPCBestClustScores, rez.mainPCbestScoresIndividual, rez.mainPCbestBinary, rez.mainPCReduction] = clustering(ops, meanPCs, title);
            %TODO figure out way to take good clusters from
                %kmeans/DBSCAN and add those to the final clustering
                %(without adding all the other assignments of that
                %particular clustering algorithm) (both here and in loop)
            if ops.easterEgg
                img = imread(fullfile(ops.easterEggPath, 'ClusteringStrategy.jpg'));
                imshow(img);
            end
            if ops.iterativeOptimization
                unclusteredIdxs = {};
                badClusts = [];
                idx = 1;
                for i = 1:size(unique(rez.mainPCBestClustAssignments),2)
                    if (rez.mainPCBestClustScores(i) < ops.clustMin)
                        unclusteredIdxs{idx} = find(rez.mainPCBestClustAssignments == i); %ONLY EVER REMOVE, CHECK 1ST ELEMENT
                        badClusts(idx) = i;
                        idx = idx + 1;
                    end
                end
                while ~isempty(unclusteredIdxs) %now subcluster bad clusters by PC1, PC2, ... PCN (FIRST PC1/zoom in, then others)
                    currIdxs = unclusteredIdxs{1};
                    currClust = badClusts(1);
                    %took 1 representative batch from all n clusters obtained from kmeans (BEFORE THIS LOOP) -
                    %seemed to improve newspikes1 and newspikes2 up to
                    %level of random (...yay), but only did a very
                    %rudimentary sampling-- proceed with original plan and
                    %ONLY sample from clusters with good silhouette scores
                    %(do zoom + PC-level thing)

                    %TODO figure out way to take good clusters from
                    %kmeans/DBSCAN and add those to the final clustering
                    %(without adding all the other assignments of that
                    %particular clustering algorithm)

                    %ZOOM INTO BAD CLUSTERS (breadth first search for clusters
                    %< threshold)
                        %1ST- attempt to get good clusters using AVERAGES
                        %2ND- break down by PC level: start with 1, then 2, 3,
                        %etc.
                        %each pass: update clusters/assignments AT LEVEL OF
                        %AVERAGED PCS - update variables above
                        %update unclusteredIdxs
                    %stop when there are no (?) subclusters < ops.threshold 
                    %do final pass of good clusters?

                    title = sprintf("Bad Cluster %d", currClust);
                    currU = batchUs(currIdxs,:,:);
                    meanPCs = zeros(size(currIdxs,2), ops.Nchan);
                    for i = 1:ops.batchPCS
                        meanPCs = meanPCs + permute(currU(:,i,:), [1 3 2]);
                    end
                    meanPCs = meanPCs / ops.batchPCS;
                    [algo bestClusts, bestScores, bestPCbin, PCReduction] = clustering(ops, meanPCs, title);
                    rez = mergeClusts(ops, rez); %well that didnt work super well... graph across PCs could still be valuable though
                    PCReductions = arrayfun(@(x) [], 1:ops.batchPCS, 'UniformOutput', false);
                    rez.bestPCbins = arrayfun(@(x) [], 1:ops.batchPCS, 'UniformOutput', false);
                    %TODO maybe try clustering by PC1 first, THEN PC2 for
                    %remaining UNCLUSTERED REGIONS/SUBDIVIDE PC1 CLUSTERS
                    unclusteredIdxs = []; %TODO assign as number of elements in CLUSTERS of average silScorte < threshold (not individual point silScores)
                end %TODO have option to use my custom kmeans that doesnt rely on dimensionality reduction (STILL SEPARATE BY PC/MERGE THOUGH) (actually not sure if i should separate)
            end
            
            %TODO plot UMAP output as png or something-- currently wont load reliably
            
            %TODO PLOT TEMPLATES OF EACH CLUSTER

            fprintf("SVD Complete. Running k-means clustering algorithm...\n")
            
            if ops.NchanDimKmeans
                [assignments, silScores, clustSils] = kmeansCustom(ops, batchUs);
            
                %TODO try to implement DBSCAN with same custom method used as kmeans

                %TODO compare ALL clustering methods (PC-wise clustering
                %(already optimized configuration of DBSCAN vs. kmeans vs.
                %other)/full kmeans/full DBSCAN, graph all comparisons, pick
                %best silScore
                    %can get rid of custom function if results are consistently
                    %worse/exact same or just put a disclaimer

                %TODO allow user to select clusters themselves


                hold on
                iperm = [];
                unclustered = [];
                unclusteredIdx = 1;
                idx = 1;
                clusterIdx = 1;
                legendLabels = {};
                clusterIdxs = arrayfun(@(x) [], 1:size(assignments,1), 'UniformOutput', false);
                fprintf("Clustering complete. Picking representative batches...\n")
                for i = 1:size(clustSils,2) %pick representatives and graph
                    assignmentIdxs = find(assignments(i,:) == 1);
                    if (isempty(assignmentIdxs))
                        continue %should never be hit
                    end
                    clusterIdxs{clusterIdx} = assignmentIdxs;
                    assignmentSils = silScores(assignmentIdxs);
                    [assignmentSils, isort] = sort(assignmentSils, 'descend');
                    if (clustSils(i) > ops.clusterThreshold)
                        legendLabels(idx) = cellstr(sprintf('Cluster %i', i));
                        scatter(assignmentIdxs(isort), assignmentSils, 'MarkerFaceColor', rand(1,3), 'MarkerEdgeColor', 'black')
                        iperm(idx) = isort(1);  %TODO THIS IS WRONG!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                        idx = idx + 1;
                    else
                        for k = 1:size(assignmentIdxs,2)
                            unclustered(unclusteredIdx) = assignmentIdxs(k);
                            unclusteredIdx = unclusteredIdx + 1;
                        end
                    end
                    clusterIdx = clusterIdx + 1;
                end
                xlim([0 Nbatch])
                ylim([min(silScores) 1]) 
                xlabel("Batch Number");
                ylabel("Silhouette Score");
                title("Silhouette Score vs. Batch Number of Optimal Clustering")
                legend(legendLabels, 'Location', 'best')
                hold off
                savefig(fullfile(ops.plotPath, "kmeansFinalClusters.fig"));
                close();
                num = floor(size(unclustered,2) * size(iperm,2)) / (Nbatch - size(unclustered,2));
                temp = sortByVar(ops, num);
                iperm = cat(2, temp, iperm);
                rez.clustSils = clustSils;
                rez.silScores = silScores;
                rez.clusterIdxs = clusterIdxs; %TODO return arrays of Idxs
            else
                for i = 1:size(unique(rez.mainPCBestClustAssignments),2) %TODO improve selection
                    idx = find(rez.mainPCBestClustAssignments == i);
                    scores = rez.mainPCbestScoresIndividual(idx);
                    [~, isort] = sort(scores, 'descend');
                    iperm(i) = idx(isort(1));
                end
            end
        otherwise
            iperm = randperm(Nbatch); 
    end
    
    iperm = iperm(randperm(length(iperm)));
    rez.compressionFactor = (Nbatch/length(iperm));
    fprintf("%s subsampling complete. Compression Factor : %d \n",ops.batchSetting, ceil(rez.compressionFactor))
    rez.batchesToUse = gather_try(iperm);
    fclose(fid);
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

%IMPLEMENT ENTROPY CALCULATION