#!/bin/bash
# setup-venv.sh - Setup Python virtual environment with OpenTelemetry packages

set -e

echo "Setting up Python virtual environment for XDP OpenTelemetry exporter..."
echo

# Check if we're in the right directory
if [ ! -f "xdp_otel_exporter_enhanced.py" ]; then
    echo "Error: Must run this script from the xdp-otel-demo directory"
    exit 1
fi

# Create venv if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate venv
echo
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo
echo "Upgrading pip..."
pip install --upgrade pip

# Install OpenTelemetry packages
echo
echo "Installing OpenTelemetry packages..."
pip install \
    opentelemetry-api \
    opentelemetry-sdk \
    opentelemetry-exporter-otlp-proto-grpc

# Verify installation
echo
echo "Verifying installation..."
python3 -c "from opentelemetry import metrics; print('✓ opentelemetry imported successfully')"

echo
echo "Installed packages:"
pip list | grep opentelemetry

echo
echo "============================================"
echo "✓ Setup complete!"
echo "============================================"
echo
echo "To use the exporter:"
echo "  1. Keep this terminal open (venv is activated)"
echo "  2. Run: sudo -E venv/bin/python3 xdp_otel_exporter_enhanced.py --map-name stats_map"
echo
echo "Or in a new terminal:"
echo "  1. cd $(pwd)"
echo "  2. source venv/bin/activate"
echo "  3. sudo -E venv/bin/python3 xdp_otel_exporter_enhanced.py --map-name stats_map"
echo
