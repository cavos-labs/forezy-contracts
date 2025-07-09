#!/bin/bash

# Test runner script for Forezy Contracts

echo "🔧 Building contracts..."
scarb build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "🧪 Running tests..."
snforge test

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed"
    exit 1
fi 