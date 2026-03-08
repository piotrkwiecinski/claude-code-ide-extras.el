#!/usr/bin/env bash

# Compile and test check for claude-code-ide-companion

set -euo pipefail

WITH_NATIVE_COMPILE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --with-native-compile)
            WITH_NATIVE_COMPILE=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--with-native-compile]" >&2
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT" || exit 1
echo "Running compile and test checks..." >&2

# Fetch dependencies
DEPS_DIR="$PROJECT_ROOT/.deps"
if [ ! -d "$DEPS_DIR/claude-code-ide.el" ]; then
    echo "=== Fetching dependencies ===" >&2
    mkdir -p "$DEPS_DIR"
    git clone --depth 1 https://github.com/manzaltu/claude-code-ide.el.git "$DEPS_DIR/claude-code-ide.el"
fi

LOAD_PATH="-L . -L $DEPS_DIR/claude-code-ide.el"

# STEP 1: Byte-compile
echo "=== Running byte-compilation check ===" >&2
emacs -batch $LOAD_PATH \
    --eval "(setq byte-compile-warnings '(not free-vars unresolved))" \
    -f batch-byte-compile claude-code-ide-companion.el
COMPILE_EXIT_CODE=$?

if [ $COMPILE_EXIT_CODE -eq 0 ]; then
    echo "Byte-compilation check passed" >&2
else
    echo "Byte-compilation failed" >&2
fi

# STEP 2: Native compile (optional)
NATIVE_COMPILE_EXIT_CODE=0

if [ $COMPILE_EXIT_CODE -eq 0 ] && [ "$WITH_NATIVE_COMPILE" = true ]; then
    if emacs -batch --eval "(if (featurep 'native-compile) (message \"yes\") (message \"no\"))" 2>&1 | grep -q "yes"; then
        echo "" >&2
        echo "=== Running native-compilation check ===" >&2
        emacs -batch $LOAD_PATH -f batch-native-compile claude-code-ide-companion.el
        NATIVE_COMPILE_EXIT_CODE=$?

        if [ $NATIVE_COMPILE_EXIT_CODE -eq 0 ]; then
            echo "Native-compilation check passed" >&2
        else
            echo "Native-compilation failed" >&2
        fi
    else
        echo "" >&2
        echo "Native compilation not available, skipping" >&2
    fi
fi

# STEP 3: Run tests
TEST_FAILED=0
if [ $COMPILE_EXIT_CODE -eq 0 ] && [ $NATIVE_COMPILE_EXIT_CODE -eq 0 ]; then
    echo "" >&2
    echo "=== Running tests ===" >&2
    emacs -batch -L . -l ert -l claude-code-ide-companion-tests.el -f ert-run-tests-batch-and-exit >&2
    TEST_EXIT_CODE=$?

    if [ $TEST_EXIT_CODE -eq 0 ]; then
        echo "All tests passed" >&2
    else
        echo "Tests failed" >&2
        TEST_FAILED=1
    fi
else
    echo "" >&2
    echo "Skipping tests due to compilation errors" >&2
    TEST_FAILED=1
fi

# STEP 4: Clean up
rm -f *.elc
find . -name "*.eln" -type f -delete 2>/dev/null || true

if [ $COMPILE_EXIT_CODE -ne 0 ] || [ $NATIVE_COMPILE_EXIT_CODE -ne 0 ] || [ $TEST_FAILED -eq 1 ]; then
    exit 1
fi

exit 0
