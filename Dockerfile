# https://github.com/Cantera/cantera-base-manylinux/blob/main/Dockerfile
# Note, TARGET_ARCH must be defined as a build-time arg, it is deliberately different
# from TARGETARCH which is defined by docker. The reason is because TARGETARCH=amd64
# but we need TARGET_ARCH=x86_64
ARG TARGET_ARCH
FROM quay.io/pypa/manylinux_2_28_${TARGET_ARCH:-x86_64} AS build

WORKDIR /piper-phonemize

COPY CMakeLists.txt Makefile MANIFEST.in LICENSE.md README.md ./
COPY src ./src
COPY piper_phonemize ./piper_phonemize
COPY etc ./etc
RUN cmake -B build -D CMAKE_INSTALL_PREFIX=install
RUN cmake --build build --config Release
RUN cmake --install build
# Without this, we'll get: Error processing file '/usr/share/espeak-ng-data/phontab': No such file or directory.
RUN find / -type d -name 'espeak-ng-data' -exec cp -R {} ./piper_phonemize \;
COPY pyproject.toml setup.py ./
RUN /opt/python/cp312-cp312/bin/python -m build --wheel --sdist .
# Fixed up wheels will end up `./wheelhouse` directory.
# Without specifying `LD_LIBRARY_PATH` auditwheel will not be able to find the required libraries.
# NOTE: these libraries were installed in by one of the previous `cmake` commands.
# Both architectures are included in the `LD_LIBRARY_PATH` to ensure that the library is found in both cases.
ENV LD_LIBRARY_PATH='/piper-phonemize/install/lib/:/piper-phonemize/install/lib64/:/piper-phonemize/lib/onnxruntime-linux-x64-1.14.1/lib:/piper-phonemize/lib/onnxruntime-linux-aarch64-1.14.1/lib'
RUN auditwheel repair dist/*.whl
# Smoke test
RUN echo "testing one two three" | ./install/bin/piper_phonemize -l en-us --espeak-data ./piper_phonemize

FROM scratch

COPY --from=build /piper-phonemize/wheelhouse/ ./
COPY --from=build /piper-phonemize/dist/*.tar.gz ./
