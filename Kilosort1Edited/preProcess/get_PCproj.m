function Us = get_PCproj(S1, row, col, wPCA, maskMaxChans)

[nT, nChan] = size(S1);
dt = -21 + [1:size(wPCA,1)]; %WHY -21??? because we want the 61 channels AROUND the row that crosses the threshold
inds = repmat(row', numel(dt), 1) + repmat(dt', 1, numel(row));

clips = reshape(S1(inds, :), numel(dt), numel(row), nChan); %61 timesamples around n spikes detected by threshold - nsamps x nspikes x channels, what happens if spike at time <20?


mask = repmat([1:nChan], [numel(row) 1]) - repmat(col, 1, nChan); %what is the point of this - excludes insufficient SNR channels but how
Mask(1,:,:) = abs(mask)<maskMaxChans;

clips = bsxfun(@times, clips , Mask);

Us = wPCA' * reshape(clips, numel(dt), []);
Us = reshape(Us, size(wPCA,2), numel(row), nChan);

Us = permute(Us, [3 2 1]);

 %Why use rows as time not cols? because data matrix is transposed