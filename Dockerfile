FROM --platform=linux/arm64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential g++ gdb valgrind \
      python3 \
      openjdk-21-jdk-headless \
      curl ca-certificates time zip git \
    && rm -rf /var/lib/apt/lists/*

# node 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

# rust stable
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /work

# The sources are baked into the image rather than bind-mounted. A bind mount is
# the more convenient workflow, but Docker Desktop's file sharing is not always
# functional on macOS, and a hermetic image is the more reproducible artifact
# anyway: the results depend on nothing outside this build. Results come back
# over stdout, so no shared filesystem is needed in either direction.
# This COPY is the last layer, so editing a source file rebuilds only this step.
COPY . /work

CMD ["/bin/bash"]
