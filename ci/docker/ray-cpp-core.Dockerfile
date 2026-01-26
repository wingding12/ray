# syntax=docker/dockerfile:1.3-labs
#
# Ray C++ Core Artifacts Builder
# ==============================
# Builds ray_cpp_pkg.zip containing C++ headers, libraries, and examples.
#
ARG ARCH_SUFFIX=
ARG HOSTTYPE=x86_64
ARG MANYLINUX_VERSION
FROM rayproject/manylinux2014:${MANYLINUX_VERSION}-jdk-${HOSTTYPE} AS builder

ARG BUILDKITE_BAZEL_CACHE_URL
ARG BUILDKITE_CACHE_READONLY
ARG HOSTTYPE
ARG CACHE_DIR=/home/forge/.cache/bazel

ENV BUILDKITE_BAZEL_CACHE_URL=${BUILDKITE_BAZEL_CACHE_URL}
ENV BUILDKITE_CACHE_READONLY=${BUILDKITE_CACHE_READONLY}
ENV CACHE_DIR=${CACHE_DIR}

WORKDIR /home/forge/ray

COPY . .

RUN --mount=type=cache,target=/home/forge/.cache/bazel,uid=2000,gid=100,id=ray-bazel-cache-${HOSTTYPE} \
    <<'EOF'
#!/bin/bash
set -euo pipefail

export BAZELISK_HOME=$CACHE_DIR/bazelisk

export RAY_BUILD_ENV="manylinux"

BAZEL_CACHE_ARGS=""
if [[ -z "${BUILDKITE_BAZEL_CACHE_URL:-}" ]]; then
  # Disable remote cache for local builds (no credentials)
  BAZEL_CACHE_ARGS="--remote_cache="
elif [[ "${BUILDKITE_CACHE_READONLY:-}" == "true" ]]; then
  # Read-only mode: disable uploads only
  BAZEL_CACHE_ARGS="--remote_upload_local_results=false"
fi

bazelisk build --config=ci --repository_cache=$CACHE_DIR/repo $BAZEL_CACHE_ARGS //cpp:ray_cpp_pkg_zip

cp bazel-bin/cpp/ray_cpp_pkg.zip /home/forge/ray_cpp_pkg.zip

EOF

FROM scratch

COPY --from=builder /home/forge/ray_cpp_pkg.zip /
