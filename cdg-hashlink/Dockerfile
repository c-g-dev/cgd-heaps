FROM ubuntu:22.04

# Prevent tzdata and other packages from prompting for input
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies as specified in the README
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libturbojpeg-dev \
    libvorbis-dev \
    libopenal-dev \
    libsdl2-dev \
    libglu1-mesa-dev \
    libmbedtls-dev \
    libuv1-dev \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /usr/src/hashlink

# Copy the entire project into the container
COPY . .

# Build the project
RUN make

# Install Hashlink binaries
RUN make install

# Verify the installation and set default command
CMD ["hl"]