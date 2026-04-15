PROTO_DIR := proto
CORE_API_DIR := services/core-api
MODULE := github.com/chirag3003/lms-monorepo/services/core-api
export PATH := $(PATH):$(shell go env GOPATH)/bin

.PHONY: proto sqlc docker-up docker-down

proto:
	protoc \
		-I $(PROTO_DIR) \
		--go_out=$(CORE_API_DIR) \
		--go_opt=module=$(MODULE) \
		--go-grpc_out=$(CORE_API_DIR) \
		--go-grpc_opt=module=$(MODULE) \
		$(PROTO_DIR)/admin/v1/admin.proto \
		$(PROTO_DIR)/auth/v1/auth.proto \
		$(PROTO_DIR)/onboarding/v1/onboarding.proto \
		$(PROTO_DIR)/loan/v1/loan.proto

sqlc:
	cd $(CORE_API_DIR) && sqlc generate

docker-up:
	docker compose up -d

docker-down:
	docker compose down
