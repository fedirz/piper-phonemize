# https://github.com/Cantera/cantera-base-manylinux/blob/main/Dockerfile
# Note, TARGET_ARCH must be defined as a build-time arg, it is deliberately different
# from TARGETARCH which is defined by docker. The reason is because TARGETARCH=amd64
# but we need TARGET_ARCH=x86_64
ARG TARGET_ARCH
FROM quay.io/pypa/manylinux_2_28_${TARGET_ARCH} AS build

WORKDIR /piper-phonemize

COPY CMakeLists.txt Makefile MANIFEST.in LICENSE.md README.md ./
COPY src ./src
COPY piper_phonemize ./piper_phonemize
COPY etc ./etc
RUN cmake -B build -D CMAKE_INSTALL_PREFIX=install
RUN cmake --build build --config Release
RUN cmake --install build
#
COPY pyproject.toml setup.py ./
RUN /opt/python/cp312-cp312/bin/python -m build --wheel .
# Fixed up wheels will end up `./wheelhouse` directory.
# Without specifying `LD_LIBRARY_PATH` auditwheel will not be able to find the required libraries.
# NOTE: these libraries were installed in by one of the previous `cmake` commands.
# Both architectures are included in the `LD_LIBRARY_PATH` to ensure that the library is found in both cases.
RUN LD_LIBRARY_PATH='/piper-phonemize/install/lib/:/piper-phonemize/lib/onnxruntime-linux-x64-1.14.1/lib:/piper-phonemize/lib/onnxruntime-linux-aarch64-1.14.1/lib' auditwheel repair dist/*.whl

FROM scratch

COPY --from=build /piper-phonemize/wheelhouse/ ./
