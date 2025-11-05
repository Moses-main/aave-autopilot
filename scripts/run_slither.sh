#!/bin/bash

# Run Slither analysis
echo "Running Slither analysis..."
slither . --checklist --markdown slither-report.md

# Check if slither-report.md exists
if [ -f "slither-report.md" ]; then
    echo "Slither report generated: slither-report.md"
    
    # Count high severity findings
    high_count=$(grep -c "High" slither-report.md || true)
    
    if [ "$high_count" -gt 0 ]; then
        echo "❌ Found $high_count high severity issues that need to be addressed."
        echo "Please review slither-report.md for details."
        exit 1
    else
        echo "✅ No high severity issues found."
    fi
else
    echo "Failed to generate Slither report."
    exit 1
fi
