function batchUs = get_SVDs(ops, batchstart, fid)  
    Nbatch = ops.Nbatch;
    %batchVs = gpuArray.zeros([Nbatch, ops.batchPCS, NT], 'double');
    batchUs = gpuArray.zeros([Nbatch, ops.batchPCS, ops.Nchan], 'double');
    fprintf("Performing SVD...\n")
    for i = 1:Nbatch
        offset = 2 * ops.Nchan*batchstart(i);
        fseek(fid, offset, 'bof');
        dat = fread(fid, [ops.NT ops.Nchan], '*int16');
        if ops.GPU
            dataRAW = gpuArray(dat);
        else
            dataRAW = dat;
        end
        dataRAW = single(dataRAW);
        dataRAW = dataRAW / ops.scaleproc;
        dataRAW = dataRAW';
        [U, ~, ~] = svd(dataRAW, 'econ');
        for j = 1:ops.batchPCS %TODO TRY TO PARALLELIZE
            batchUs(i,j,:,:) = U(:,j)'; %numBatches x numBatchPCS x numChan (singular vector))
            %batchVs(i,j,:,:) = V(:,j); %numBatches x numBatchPCS x NT (singular vector))
        end
    end
    %batchVs = gather_try(batchVs); TODO FIGURE OUT WHAT TO DO WITH BATCHVs
    batchUs = gather_try(batchUs);
end