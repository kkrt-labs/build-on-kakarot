RPC_PATH := lib/kakarot-rpc
CAIRO_CONTRACTS_PATH := cairo_contracts
SOL_CONTRACTS_PATH := solidity_contracts
LOCAL_ENV_PATH := ./.env
MAKE := make

start:
	@echo "Starting Kakarot (L2 node) and Anvil (L1 node)"
	$(MAKE) -C $(RPC_PATH) local-rpc-up & anvil & \
	$(MAKE) copy-env

copy-env:
	@echo "Copying .env file from Kakarot RPC container..."
	@container_id=$$(docker-compose -f $(RPC_PATH)/docker-compose.yaml ps -q kakarot-rpc); \
	if docker cp $$container_id:/usr/src/app/.env $(LOCAL_ENV_PATH); then \
		echo ".env file copied to $(LOCAL_ENV_PATH)"; \
	else \
		echo "Failed to copy .env file."; \
		exit 1; \
	fi

build: build-cairo build-sol

build-cairo:
	@echo "Building Cairo contracts..."
	cd $(CAIRO_CONTRACTS_PATH) && scarb build

build-sol:
	@echo "Building Solidity contracts..."
	forge build

stop:
	@echo "Stopping Kakarot (L2 node) and Anvil (L1 node)"
	cd $(RPC_PATH) && docker-compose down -v & killall anvil

whitelist-contract: copy-env
	@if [ -z "$(CONTRACT_ADDRESS)" ]; then \
		echo "Error: CONTRACT_ADDRESS is required. Usage: make whitelist-contract CONTRACT_ADDRESS=0x..."; \
		exit 1; \
	fi
	@if [ ! -f $(LOCAL_ENV_PATH) ]; then \
		echo "Error: .env file not found at $(LOCAL_ENV_PATH)"; \
		exit 1; \
	fi
	@KAKAROT_ADDRESS=$$(grep KAKAROT_ADDRESS $(LOCAL_ENV_PATH) | cut -d '=' -f2); \
	if [ -z "$$KAKAROT_ADDRESS" ]; then \
		echo "Error: KAKAROT_ADDRESS not found in .env file"; \
		exit 1; \
	fi; \
	echo "Using KAKAROT_ADDRESS: $$KAKAROT_ADDRESS"; \
	echo "Whitelisting CONTRACT_ADDRESS: $(CONTRACT_ADDRESS)"; \
	starkli invoke $$KAKAROT_ADDRESS set_authorized_cairo_precompile_caller $(CONTRACT_ADDRESS) 1
