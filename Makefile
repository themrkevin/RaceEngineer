# Makefile
.PHONY: test test-all test-app help

# Default target
.DEFAULT_GOAL := help

# Run package tests. 
# Usage:
#   make test                   -> Runs all local packages
#   make test pkg=TelemetryKit  -> Runs only TelemetryKit
test-package: ## Run package tests on macOS (e.g., make test, or make test pkg=TelemetryKit)
ifdef pkg
	@bundle exec fastlane test_package name:$(pkg)
else
	@bundle exec fastlane test_package
endif

test-app: ## Run full iOS app tests on Simulator
	@bundle exec fastlane test_app

test-all: test test-app ## Run all package tests followed by app tests

help: ## Show available commands
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'