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
            
            currU = rez.batchUs(:,:,:);
            meanPCs = zeros(size(currU,1), ops.Nchan);
            for i = 1:ops.batchPCS
                meanPCs = meanPCs + permute(currU(:,i,:), [1 3 2]);
            end
            meanPCs = meanPCs / ops.batchPCS;
            [~, ~, ~, ~, ~, rez.mainPCReduction] = clustering(ops, meanPCs, "Mean PC Reduction"); %GENERATING REDUCTION FOR AVERAGE PCS
            
            if ops.iterativeOptimization
                fprintf("SVD Complete. Running iterative cluster optimization algorithm...\n")
                [finalAssignments, finalCluScores, finalCluIndividual, unclusterable] = optimizeClusters(ops, rez, 1, 1:ops.Nbatch);
                fprintf("PC 1 Clustering Completed. Detected Clusters: %d , Remaining Batches: %d... \n", size(finalCluScores,2), size(unclusterable,2))
                %originalUnclusterable = unclusterable;
                %[meanAssignments, meanCluScores, meanCluIndividual, unclusterable] = optimizeClusters(ops, rez, 1, unclusterable); %TODO ADD BACK IN  
            end
            
            if ops.NchanDimKmeans
                fprintf("SVD Complete. Running full-dimensional k-means clustering algorithm...\n")
                [finalAssignments, finalCluScores, finalCluIndividual] = kmeansCustom(ops, batchUs); %TODO MAKE IT MATCH RETURN TYPE OF ABOVE OPTION FOR FINALASSIGNMENTS 
            end
            
            fprintf("Clustering complete. Picking representative batches...\n")                   
            
            figure;
            subplot(1, 2, 1);
            hold on
            n = 1;
            for i = 1:size(unique(finalCluScores),2) %TODO improve selection
                clustCols{i} = rand(1, 3);
                clustLabels{i} = strcat("Cluster ", string(i));
                
                idx = find(finalAssignments == i);
                scores = finalCluIndividual(i); %TODO FIX BRACE VS PARENTHESIS SHIT
                [~, isort] = sort(scores, 'descend');
                iperm(n) = idx(isort(end));
                n = n + 1;
                               
                scatter(rez.mainPCReduction(finalAssignments == i,1)', rez.mainPCReduction(finalAssignments == i,2)','MarkerFaceColor', clustCols{i});
                dbCentroid = mean(rez.mainPCReduction(finalAssignments == i,:),1);

                scatter(dbCentroid(1), dbCentroid(2), 100, 'filled', 'black', 'HandleVisibility', 'Off');
                text(dbCentroid(1) + 1, dbCentroid(2) - 1, string(finalCluScores(i)), 'FontWeight','bold');
            end
            clustCols{i + 1} = rand(1,3);
            clustLabels(i + 1) = cellstr("Unclustered");
            scatter(rez.mainPCReduction(unclusterable,1)', rez.mainPCReduction(unclusterable,2)', 'MarkerEdgeColor', clustCols{i+1});
            title("Final Batch Clusters")
            legend(clustLabels, 'Location', 'best')
            hold off
            
            subplot(1, 2, 2);
            hold on
            for i = 1:size(unique(finalCluScores),2)
                idx = find(finalAssignments == i);
                scores = finalCluIndividual(i);
                [scoresSorted, isort] = sort(scores, 'descend');
                scatter(idx(isort), scoresSorted, 'MarkerFaceColor', clustCols{i}, 'MarkerEdgeColor', 'black')
            end
            scatter(unclusterable, zeros(size(unclusterable,2),1)', 'MarkerEdgeColor', clustCols{i+1})
            xlim([0 Nbatch])
            ylim([0 1])
            xlabel("Batch Number");
            ylabel("Silhouette Score");
            title("Silhouette Score vs. Batch Number of Optimal Clustering") %TODO plot selected batches on both subgraphs
            legend(clustLabels, 'Location', 'best')
            hold off
            savefig(fullfile(ops.plotPath, "finalClusts.fig"))
            
            %TODO exclude shitty cluster members?
            %FIGURE OUT HOW TO HANDLE HUGE UNCLUSTERABLE REGIONS
            
            if ops.profileClusters
                plotRows = ceil(sqrt(ops.batchPCS));
                plotCols = ceil(ops.batchPCS / plotRows);
                for i = 0:max(finalAssignments) %TODO show representative templates, numSpikes (est. numUnits?), other measures of variance, etc.
                    idx = find(finalAssignments == i);
                    figure;
                    for k = 1:ops.batchPCS
                        subplot(plotRows, plotCols, k)
                        hold on
                        for j = 1:size(idx,2)
                            if (k == 1)
                                batchCols{j} = rand(1, 3); %TODO MAKE MORE EFFICIENT by preallocating
                            end
                            plot(squeeze(batchUs(idx(j),k,:))', 'Color', batchCols{j})
                        end
                        hold off
                    end
                    batchCols = {};
                    savefig(fullfile(ops.plotPath, strcat("Cluster ", string(i), " Profile.fig")))
                    close("all")
                end
                hold on
                for i = 0:size(unique(finalCluScores),2) %TODO show representative templates, numSpikes (est. numUnits?), other measures of variance, etc.
                    idx = find(finalAssignments == i);
                    batchCols{i+1} = rand(1, 3); %TODO MAKE MORE EFFICIENT by preallocating
                    for j = 1:size(idx,2)                          
                        plot(squeeze(batchUs(idx(j),k,:))', 'Color', batchCols{i+1})
                    end
                end
                hold off
                savefig(fullfile(ops.plotPath, "AllClusters.fig"))
                close("all")
            end
            %num = floor(size(unclusterable,2) * size(iperm,2)) / (Nbatch - size(unclusterable,2));
            %temp = sortByVar(ops, num);
            %iperm = cat(2, temp, iperm);
        otherwise
            iperm = randperm(Nbatch); 
    end
    
    %TODO PLOT TEMPLATES OF EACH CLUSTER
    
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