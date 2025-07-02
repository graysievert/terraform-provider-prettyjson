default: fmt lint install generate

build:
	go build -v ./...

install: build
	go install -v ./...

lint:
	golangci-lint run

generate: docs-generate-legacy
	@echo "⚠️  WARNING: 'make generate' uses legacy documentation generation."
	@echo "   For complete documentation with examples, use 'make docs' instead."

docs-generate-legacy:
	cd tools; go generate ./...

fmt:
	gofmt -s -w -e .

test:
	go test -v -cover -timeout=120s -parallel=10 ./...

testacc:
	TF_ACC=1 go test -v -cover -timeout 120m ./...

docs: docs-generate docs-validate

docs-generate:
	cd tools && go run github.com/hashicorp/terraform-plugin-docs/cmd/tfplugindocs generate --provider-dir .. --provider-name prettyjson
	@if [ -f scripts/enhance-docs.sh ]; then \
		echo "🔧 Running documentation enhancement..."; \
		./scripts/enhance-docs.sh; \
	fi

docs-validate:
	@echo "Validating documentation..."
	@test -f docs/index.md || (echo "ERROR: Provider documentation not found" && exit 1)
	@test -f docs/functions/jsonprettyprint.md || (echo "ERROR: Function documentation not found" && exit 1)
	@grep -q "jsonprettyprint" docs/functions/jsonprettyprint.md || (echo "ERROR: Function documentation is incomplete" && exit 1)
	@echo "Documentation validation passed"

docs-clean:
	rm -rf docs/
	mkdir -p docs

docs-dev: docs-clean docs-generate
	@echo "Development documentation generated successfully"

# Environment validation targets
validate-env:
	@echo "Validating environment for cross-platform testing..."
	@if [ -x scripts/platform-tests/validate-environment.sh ]; then \
		./scripts/platform-tests/validate-environment.sh; \
	else \
		echo "Environment validation script not found or not executable"; \
		exit 1; \
	fi

validate-env-report:
	@echo "Validating environment and generating report..."
	@if [ -x scripts/platform-tests/validate-environment.sh ]; then \
		./scripts/platform-tests/validate-environment.sh --report; \
	else \
		echo "Environment validation script not found or not executable"; \
		exit 1; \
	fi

validate-env-strict:
	@echo "Validating environment with strict mode (warnings as errors)..."
	@if [ -x scripts/platform-tests/validate-environment.sh ]; then \
		./scripts/platform-tests/validate-environment.sh --strict; \
	else \
		echo "Environment validation script not found or not executable"; \
		exit 1; \
	fi

# Cross-platform testing targets
test-platform:
	@echo "Running platform-specific tests..."
	@if [ -x scripts/platform-tests/run-platform-tests.sh ]; then \
		./scripts/platform-tests/run-platform-tests.sh; \
	else \
		echo "Platform test script not found or not executable"; \
		exit 1; \
	fi

test-platform-setup:
	@echo "Setting up platform testing environment..."
	@if [ -x scripts/platform-tests/setup-platform-env.sh ]; then \
		./scripts/platform-tests/setup-platform-env.sh; \
	else \
		echo "Platform setup script not found or not executable"; \
		exit 1; \
	fi

test-cross-platform: validate-env test-platform-setup test-platform
	@echo "Cross-platform testing completed"

# Architecture-specific testing
test-amd64:
	GOARCH=amd64 go test -v ./internal/provider/

test-arm64:
	@echo "Cross-compiling for ARM64..."
	GOARCH=arm64 CGO_ENABLED=0 go build -v .
	@echo "ARM64 build successful (execution test skipped on non-ARM64 host)"

build-amd64:
	GOARCH=amd64 CGO_ENABLED=0 go build -o bin/terraform-provider-prettyjson_amd64 .

build-arm64:
	GOARCH=arm64 CGO_ENABLED=0 go build -o bin/terraform-provider-prettyjson_arm64 .

build-architectures: build-amd64 build-arm64
	@echo "Multi-architecture builds completed"

test-architectures: test-amd64 test-arm64
	@echo "Architecture testing completed"

# Terraform version testing targets
test-terraform-versions:
	@echo "Running comprehensive Terraform version testing..."
	@if [ -x scripts/platform-tests/terraform-version-tests.sh ]; then \
		./scripts/platform-tests/terraform-version-tests.sh; \
	else \
		echo "Terraform version test script not found or not executable"; \
		exit 1; \
	fi

test-terraform-versions-minimal:
	@echo "Running minimal Terraform version testing..."
	@if [ -x scripts/platform-tests/terraform-version-tests.sh ]; then \
		./scripts/platform-tests/terraform-version-tests.sh -m minimal; \
	else \
		echo "Terraform version test script not found or not executable"; \
		exit 1; \
	fi

test-terraform-versions-extended:
	@echo "Running extended Terraform version testing..."
	@if [ -x scripts/platform-tests/terraform-version-tests.sh ]; then \
		./scripts/platform-tests/terraform-version-tests.sh -m extended --generate-report; \
	else \
		echo "Terraform version test script not found or not executable"; \
		exit 1; \
	fi

test-terraform-version:
	@echo "Testing specific Terraform version: $(VERSION)"
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION is required. Usage: make test-terraform-version VERSION=1.8.0"; \
		exit 1; \
	fi
	@if [ -x scripts/platform-tests/terraform-version-tests.sh ]; then \
		./scripts/platform-tests/terraform-version-tests.sh -v "$(VERSION)" --verbose; \
	else \
		echo "Terraform version test script not found or not executable"; \
		exit 1; \
	fi

validate-terraform-versions:
	@echo "Validating Terraform version compatibility..."
	@if [ -x scripts/platform-tests/terraform-version-tests.sh ]; then \
		./scripts/platform-tests/terraform-version-tests.sh --validate-only; \
	else \
		echo "Terraform version test script not found or not executable"; \
		exit 1; \
	fi

# Automated test execution targets
test-automated:
	@echo "Running automated test execution pipeline..."
	@if [ -x scripts/platform-tests/automated-test-execution.sh ]; then \
		./scripts/platform-tests/automated-test-execution.sh; \
	else \
		echo "Automated test execution script not found or not executable"; \
		exit 1; \
	fi

test-automated-quick:
	@echo "Running quick automated test execution..."
	@if [ -x scripts/platform-tests/automated-test-execution.sh ]; then \
		./scripts/platform-tests/automated-test-execution.sh --suites "unit,acceptance" --parallel 2 --timeout 15m; \
	else \
		echo "Automated test execution script not found or not executable"; \
		exit 1; \
	fi

test-automated-comprehensive:
	@echo "Running comprehensive automated test execution..."
	@if [ -x scripts/platform-tests/automated-test-execution.sh ]; then \
		./scripts/platform-tests/automated-test-execution.sh --suites "unit,acceptance,function,integration,performance" --parallel 4 --generate-report --performance-optimization; \
	else \
		echo "Automated test execution script not found or not executable"; \
		exit 1; \
	fi

test-automated-parallel:
	@echo "Running automated tests with enhanced parallel execution..."
	@if [ -x scripts/platform-tests/enhanced-parallel-executor.sh ]; then \
		./scripts/platform-tests/enhanced-parallel-executor.sh --max-parallel 8 --load-balancing --adaptive-parallelism --performance-optimization; \
	else \
		echo "Enhanced parallel executor script not found or not executable"; \
		exit 1; \
	fi

# Test result aggregation targets
aggregate-test-results:
	@echo "Aggregating test results..."
	@if [ -x scripts/platform-tests/test-result-aggregator.sh ]; then \
		./scripts/platform-tests/test-result-aggregator.sh --formats json,markdown,junit --include-logs; \
	else \
		echo "Test result aggregator script not found or not executable"; \
		exit 1; \
	fi

aggregate-test-results-comprehensive:
	@echo "Generating comprehensive test result analysis..."
	@if [ -x scripts/platform-tests/test-result-aggregator.sh ]; then \
		./scripts/platform-tests/test-result-aggregator.sh --formats json,markdown,junit,github --include-logs --performance-metrics --trend-analysis --threshold 85; \
	else \
		echo "Test result aggregator script not found or not executable"; \
		exit 1; \
	fi

# CI/CD integration targets
ci-test-quick:
	@echo "Running CI quick test suite..."
	@$(MAKE) test-automated-quick
	@$(MAKE) aggregate-test-results

ci-test-standard:
	@echo "Running CI standard test suite..."
	@$(MAKE) test-automated
	@$(MAKE) aggregate-test-results

ci-test-comprehensive:
	@echo "Running CI comprehensive test suite..."
	@$(MAKE) test-automated-comprehensive
	@$(MAKE) aggregate-test-results-comprehensive

# Performance testing targets
test-performance:
	@echo "Running performance tests..."
	@if [ -x scripts/platform-tests/automated-test-execution.sh ]; then \
		./scripts/platform-tests/automated-test-execution.sh --suites "performance" --performance-optimization --generate-report; \
	else \
		echo "Automated test execution script not found or not executable"; \
		exit 1; \
	fi

test-load-balancing:
	@echo "Testing with advanced load balancing..."
	@if [ -x scripts/platform-tests/enhanced-parallel-executor.sh ]; then \
		./scripts/platform-tests/enhanced-parallel-executor.sh --load-balancing --resource-monitoring --failure-correlation --verbose; \
	else \
		echo "Enhanced parallel executor script not found or not executable"; \
		exit 1; \
	fi

# Validation and reporting targets
validate-test-infrastructure:
	@echo "Validating test infrastructure..."
	@echo "Checking script permissions..."
	@test -x scripts/platform-tests/automated-test-execution.sh || (echo "ERROR: automated-test-execution.sh not executable" && exit 1)
	@test -x scripts/platform-tests/test-result-aggregator.sh || (echo "ERROR: test-result-aggregator.sh not executable" && exit 1)
	@test -x scripts/platform-tests/enhanced-parallel-executor.sh || (echo "ERROR: enhanced-parallel-executor.sh not executable" && exit 1)
	@test -x scripts/platform-tests/terraform-version-tests.sh || (echo "ERROR: terraform-version-tests.sh not executable" && exit 1)
	@echo "All test infrastructure scripts are executable"
	@echo "Validating required tools..."
	@command -v go >/dev/null 2>&1 || (echo "ERROR: Go not found" && exit 1)
	@command -v terraform >/dev/null 2>&1 || (echo "ERROR: Terraform not found" && exit 1)
	@command -v jq >/dev/null 2>&1 || (echo "ERROR: jq not found" && exit 1)
	@echo "All required tools are available"

generate-test-report:
	@echo "Generating comprehensive test report..."
	@mkdir -p test-reports
	@$(MAKE) validate-test-infrastructure
	@$(MAKE) test-automated-comprehensive 2>&1 | tee test-reports/execution.log || true
	@$(MAKE) aggregate-test-results-comprehensive
	@echo "Test report generated in test-reports/ and aggregated-reports/"

# Cleanup targets
clean:
	@echo "Cleaning up generated files and directories..."
	@rm -rf test-reports/ aggregated-reports/ META.d/ tmp/ terraform.d/
	@rm -f *-test-report*.json *-report*.json coverage.out coverage.html *.prof
	@rm -f terraform-provider-prettyjson* bin/terraform-provider-prettyjson*
	@rm -rf bin/ dist/
	@find test/integration -name "providers" -type d -exec rm -rf {} + 2>/dev/null || true
	@find test/integration -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find test/integration -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@find test/integration -name "terraform.tfstate*" -delete 2>/dev/null || true
	@find test/integration -name "outputs" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Generated files cleaned successfully"

clean-test:
	@echo "Cleaning test artifacts..."
	@rm -rf test-reports/ aggregated-reports/
	@rm -f *-test-report*.json *-report*.json coverage.out coverage.html
	@find test/integration -name "providers" -type d -exec rm -rf {} + 2>/dev/null || true
	@find test/integration -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find test/integration -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@find test/integration -name "terraform.tfstate*" -delete 2>/dev/null || true
	@find test/integration -name "outputs" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Test artifacts cleaned"

clean-build:
	@echo "Cleaning build artifacts..."
	@rm -f terraform-provider-prettyjson* bin/terraform-provider-prettyjson*
	@rm -rf bin/ dist/ terraform.d/
	@echo "Build artifacts cleaned"

clean-all: clean-test clean-build
	@echo "All generated files cleaned"

# Help target for automated testing
help-automated:
	@echo "Automated Test Execution Targets:"
	@echo ""
	@echo "Basic Test Execution:"
	@echo "  test-automated              Run standard automated test suite"
	@echo "  test-automated-quick         Run quick test suite (unit + acceptance)"
	@echo "  test-automated-comprehensive Run comprehensive test suite with all features"
	@echo "  test-automated-parallel      Run tests with enhanced parallel execution"
	@echo ""
	@echo "Result Aggregation:"
	@echo "  aggregate-test-results               Basic result aggregation"
	@echo "  aggregate-test-results-comprehensive Comprehensive analysis with metrics"
	@echo ""
	@echo "CI/CD Integration:"
	@echo "  ci-test-quick        Quick CI test suite"
	@echo "  ci-test-standard     Standard CI test suite"
	@echo "  ci-test-comprehensive Comprehensive CI test suite"
	@echo ""
	@echo "Performance Testing:"
	@echo "  test-performance     Run performance-focused tests"
	@echo "  test-load-balancing  Test with advanced load balancing"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean               Clean all generated files"
	@echo "  clean-test          Clean test artifacts only"
	@echo "  clean-build         Clean build artifacts only"
	@echo "  clean-all           Clean all generated files"
	@echo ""
	@echo "Validation and Reporting:"
	@echo "  validate-test-infrastructure Validate all test scripts and tools"
	@echo "  generate-test-report        Generate comprehensive test report"
	@echo "  help-automated              Show this help message"
	@echo ""

.PHONY: fmt lint test testacc build install generate docs docs-generate docs-generate-legacy docs-validate docs-clean docs-dev validate-env validate-env-report validate-env-strict test-platform test-platform-setup test-cross-platform test-amd64 test-arm64 test-architectures build-amd64 build-arm64 build-architectures test-terraform-versions test-terraform-versions-minimal test-terraform-versions-extended test-terraform-version validate-terraform-versions test-automated test-automated-quick test-automated-comprehensive test-automated-parallel aggregate-test-results aggregate-test-results-comprehensive ci-test-quick ci-test-standard ci-test-comprehensive test-performance test-load-balancing validate-test-infrastructure generate-test-report help-automated clean clean-test clean-build clean-all
