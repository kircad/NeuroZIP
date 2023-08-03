function iperm = sortByVar(ops, topN)
    Nbatch = ops.Nbatch;
    NT = ops.NT;
    batchstart = 0:NT:NT*Nbatch;    
    batchVars = zeros(Nbatch,2);
    fid = fopen(ops.fproc, 'r');
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
        batchVars = vertcat(batchVars,[i sum(var(dataRAW,0,2))]); %sum of variance along columns
    end
    vars = sortrows(batchVars,2,'descend');
    vars = vars(1:topN); 
    iperm = vars;
end