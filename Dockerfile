FROM swift:6.0-noble

# Install dependencies for Zig, GTK 4, Adwaita, Vulkan and build tools
# Noble (24.04) has more recent versions of these libraries
RUN apt-get update && apt-get install -y \
    wget \
    xz-utils \
    pkg-config \
    build-essential \
    libgtk-4-dev \
    libadwaita-1-dev \
    libvulkan-dev \
    glslang-tools \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Zig 0.15.2
RUN wget https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz \
    && tar -xf zig-x86_64-linux-0.15.2.tar.xz \
    && mv zig-x86_64-linux-0.15.2 /usr/local/zig \
    && ln -s /usr/local/zig/zig /usr/local/bin/zig \
    && rm zig-x86_64-linux-0.15.2.tar.xz

# Set environment variables
ENV PATH="/usr/local/bin:${PATH}"
