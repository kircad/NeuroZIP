function bin = makeBinaryMats(clusters)  %0: batches did NOT cluster together, 1: batches DID cluster together (adapted monti consensus algorithm)
    bin = zeros(size(clusters,2), size(clusters,2));
    for i = 1:size(unique(clusters),2) %TODO MAKE MORE EFFICIENT -- THIS CODE SUCKS
        n = find(clusters == i);
        for a = 1:size(n,2)
            for b = 1:size(n,2)
                bin(n(a),n(b)) = 1;
                bin(n(b),n(a)) = 1;
            end
        end
    end
end