def compress_data(ops, preprocessed_batches):
    match (ops['method']):
        case 'linear':
            print("Starting linear subsampling")
            selected_batches = list(range(ops['starting'], len(preprocessed_batches), ops['spacing']))
        case 'numSpikes':
            pass
        case 'entropy':
            pass
        case 'variance':
            pass
        case 'dynamic': #  this is kmeans/clustering stuff
            pass
    return selected_batches

# TODO probably a good idea to do lazy loading