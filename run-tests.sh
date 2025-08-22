#!/bin/bash

echo "🚀 Starting DAO Treasury Contract Tests"
echo "======================================"

# Add Deno to PATH
export PATH="/home/samuel/.deno/bin:$PATH"

# Check contract syntax
echo "1. Checking contract syntax..."
clarinet check
if [ $? -eq 0 ]; then
    echo "✅ Contract syntax is valid"
else
    echo "❌ Contract syntax check failed"
    exit 1
fi

echo ""
echo "2. Testing contract functions in console..."
echo "   (Manual testing - check the test-script.clar file)"

# Start interactive console for manual testing
echo ""
echo "🔧 To test the contract manually:"
echo "   1. Run: clarinet console"
echo "   2. Copy and paste commands from test-script.clar"
echo "   3. Or run individual tests below:"
echo ""
echo "Basic test commands:"
echo "==================="
echo "(contract-call? .dao-treasury add-member 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 u100)"
echo "(stx-transfer? u1000000 .dao-treasury)"
echo "(contract-call? .dao-treasury get-treasury-balance)"
echo ""
echo "Run 'clarinet console' to start interactive testing!"
