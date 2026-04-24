#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BORROWER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROTO_ROOT="${BORROWER_ROOT}/../lms-monorepo/proto"
OUT_ROOT="${BORROWER_ROOT}/lms_borrower/Core/Networking/Generated"
GRPC_SWIFT_PLUGIN="/opt/homebrew/opt/protoc-gen-grpc-swift/bin/protoc-gen-grpc-swift-2"

if [[ ! -x "${GRPC_SWIFT_PLUGIN}" ]]; then
  echo "gRPC Swift plugin not found at ${GRPC_SWIFT_PLUGIN}" >&2
  exit 1
fi

mkdir -p "${OUT_ROOT}"

protoc \
  -I "${PROTO_ROOT}" \
  --plugin=protoc-gen-grpc-swift="${GRPC_SWIFT_PLUGIN}" \
  --swift_opt=Visibility=Public \
  --swift_out="${OUT_ROOT}" \
  --grpc-swift_opt=Visibility=Public \
  --grpc-swift_out="${OUT_ROOT}" \
  auth/v1/auth.proto \
  branch/v1/branch.proto \
  chat/v1/chat.proto \
  kyc/v1/kyc.proto \
  loan/v1/loan.proto \
  media/v1/media.proto \
  onboarding/v1/onboarding.proto

echo "Generated Swift protobuf/grpc files at ${OUT_ROOT}"
