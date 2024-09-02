FROM spikeinterface/kilosort-compiled-base

# Copy your local spikeinterface repo into the Docker image
COPY spikeinterface /home/spikeinterface

# Install spikeinterface from the copied path
RUN pip install /home/spikeinterface

RUN git clone https://github.com/flatironinstitute/spikeforest.git /tmp/spikeforest
RUN pip install /tmp/spikeforest
RUN rm -rf /tmp/spikeforest
