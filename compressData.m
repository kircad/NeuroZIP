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
            PCclustering(ops, rez);
            
            %TODO plot UMAP output as png or something-- currently wont
            %load reliably
            
            %TODO do further clustering on bad clusters - iteratively until
            %none left/hit max counter (PC-level (kmeans + DBSCAN), merged (kmeans + DBSCAN))
                %do PC-level stuff first as they seem more promising
                %try to get to point where you have no bad clusters and see
                %if spike sorting has improved
                
            %TODO PLOT TEMPLATES OF EACH CLUSTER
                
            %TODO ADD MORE CLUSTERING METHODS, DISTANCE METRICS, ETC ETC)
            %(try to see if you can improve kmeans)
            %somehow merge clusterings of all PCs (another clustering?). 

            fprintf("SVD Complete. Running k-means clustering algorithm...\n")
            [assignments, silScores, clustSils] = kmeansCustom(ops, batchUs);
            %TODO try to implement DBSCAN with same custom method used as kmeans
            
            %TODO compare ALL clustering methods (PC-wise clustering
            %(already optimized configuration of DBSCAN vs. kmeans vs.
            %other)/full kmeans/full DBSCAN, graph all comparisons, pick
            %best silScore
                %can get rid of custom function if results are consistently
                %worse/exact same or just put a disclaimer
            
            %END GOAL: no/basically no unclustered (<0.5 silScore) regions
            %left, one-two representatives from all (maybe try batch-level
            %UMAP/mutual information thing)
            %UMAP MUTUAL INFORMATION THING COULD BE IMPORTANT REGARDLESS
            
            %basically have two separate schemes-- merge top n PCs FIRST,
            %merge top n PCs SECOND (but do UMAP regardless), give user to just run all and pick best for
            %any given dataset
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
                    iperm(idx) = isort(1); 
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