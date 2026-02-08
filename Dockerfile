FROM swift:6.0-jammy

# Install Zig for Mufi runtime compilation
RUN apt-get update && apt-get install -y 
    wget 
    xz-utils 
    libgtk-3-dev 
    libvulkan-dev 
    glslang-tools 
    && rm -rf /var/lib/apt/lists/*

RUN wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz 
    && tar -xf zig-linux-x86_64-0.13.0.tar.xz 
    && mv zig-linux-x86_64-0.13.0 /usr/local/zig 
    && ln -s /usr/local/zig/zig /usr/local/bin/zig 
    && rm zig-linux-x86_64-0.13.0.tar.xz

# Set environment variables
ENV PATH="/usr/local/bin:${PATH}"
