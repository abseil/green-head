#!/bin/bash
#
# Copyright 2019 The Abseil Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script that can be invoked to test federation head in a hermetic environment
# using a Docker image on Linux. You must have Docker installed to use this
# script.

#NOTE Do not add "-x"
set -euox pipefail


BUILD_ROOT="$(realpath $(dirname ${0})/..)"

readonly GCC_DOCKER="gcr.io/google.com/absl-177019/linux_gcc-latest:20190703"
readonly CLANG_DOCKER="gcr.io/google.com/absl-177019/linux_clang-latest:20190813"

if [ -z ${STD:-} ]; then
  STD="c++11 c++14 c++17"
fi

echo "************************ GCC FEDERATION SMOKE TESTS ************************"

for std in ${STD}; do
  echo "*** Running: ${std} ***"
  time docker run  \
  --volume="${BUILD_ROOT}:/repo_root:ro"  \
  --workdir=/repo_root/test \
  --cap-add=SYS_PTRACE \
  --rm \
  -e CC="/usr/local/bin/gcc" \
  -e BAZEL_CXXOPTS="-std=${std}" \
  "${GCC_DOCKER}" \
  /usr/local/bin/bazel test ... \
    --copt=-Werror \
    --keep_going \
    --show_timestamps \
    --test_output=errors
done


echo "************************ CLANG FEDERATION SMOKE TESTS ************************"

for std in ${STD}; do
  docker run  \
  --volume="${BUILD_ROOT}:/repo_root:ro"  \
  --workdir=/repo_root/test \
  --cap-add=SYS_PTRACE \
  --rm \
  -e CC="/opt/llvm/clang/bin/clang" \
  -e BAZEL_COMPILER="llvm" \
  -e BAZEL_CXXOPTS="-std=${std}" \
  "${CLANG_DOCKER}" \
  /usr/local/bin/bazel test ... \
    --copt=-Werror \
    --keep_going \
    --show_timestamps \
    --test_output=errors
done


# echo "************************ FEDERATION SMOKE TESTS ************************"
# docker run  --volume="${BUILD_ROOT}:/repo_root:ro"  --workdir=/repo_root/test "${DOCKER_CONTAINER}" /usr/local/bin/bazel test ...

# echo "************************ GOOGLETEST TESTS ************************"
# docker run  --volume="${BUILD_ROOT}:/repo_root:ro"  --workdir=/repo_root/test "${DOCKER_CONTAINER}" /usr/local/bin/bazel test @com_google_googletest//googletest/...:all --define absl=1

# echo "************************ BENCHMARK TESTS ************************"
# docker run  --volume="${BUILD_ROOT}:/repo_root:ro"  --workdir=/repo_root/test "${DOCKER_CONTAINER}" /usr/local/bin/bazel test @com_github_google_benchmark//test/...:all

# echo "************************ ABSEIL TESTS ************************"
# docker run  --volume="${BUILD_ROOT}:/test:ro"  --workdir=/test/test "${DOCKER_CONTAINER}" /usr/local/bin/bazel test @com_google_absl//absl/...:all --test_output=errors --test_tag_filters=-benchmark

generate_post_data()
{
cat <<EOF
{"commit_title":"Auto-Merge of PR ${KOKORO_GITHUB_PULL_REQUEST_NUMBER_kokoro}", "commit_message": "Virtual Head Update","sha":"$KOKORO_GITHUB_PULL_REQUEST_COMMIT_kokoro", "merge_method":"merge"}
EOF
}

# The following variables will be defined when running on Kokoro
# KOKORO_GITHUB_PULL_REQUEST_NUMBER_kokoro
# KOKORO_GITHUB_PULL_REQUEST_COMMIT_kokoro
# KOKORO_GITHUB_PULL_REQUEST_NUMBER_kokoro
if [ ${KOKORO_GITHUB_PULL_REQUEST_NUMBER_kokoro:-0} -eq 0 ]; then
  KOKORO_GITHUB_PULL_REQUEST_NUMBER_kokoro=57
fi
if [ ${KOKORO_GITHUB_PULL_REQUEST_COMMIT_kokoro:-0} -eq 0 ]; then
  KOKORO_GITHUB_PULL_REQUEST_COMMIT_kokoro=115a97111f938cce161e3a9f028b910ccc0524f6
fi
if [ ${KOKORO_KEYSTORE_DIR:-0} -eq 0 ]; then
  KOKORO_KEYSTORE_DIR="."
  NETRC_FILE="${KOKORO_KEYSTORE_DIR}"/.netrc
else
  NETRC_FILE="$KOKORO_KEYSTORE_DIR"/73103_absl-federation-github-access_token_netrcfile
fi


if [ ${AUTOMERGE:-0} -ne 0 ]; then
  echo "AUTO_MERGE is set: ${AUTOMERGE}, Proceeding with PR merge..."
  cp "${NETRC_FILE}" ~/.netrc
  chmod 600 ~/.netrc
  curl --netrc -X PUT --data "$(generate_post_data)" https://api.github.com/repos/abseil/federation-head/pulls/"${KOKORO_GITHUB_PULL_REQUEST_NUMBER_kokoro}"/merge
else
  echo "AUTOMERGE is not set, Skipping PR merge..."
fi
