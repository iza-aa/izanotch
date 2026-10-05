#!/usr/bin/env bash
#
# tail_logs.sh
# Streams Izanotchy / Clicky live diagnostics logs in realtime.
#

LOG_DIR="$HOME/Library/Logs/Izanotchy"
LOG_FILE="$LOG_DIR/clicky.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

echo "============================================================"
echo "  Izanotchy Clicky Live Diagnostics Stream"
echo "  File: $LOG_FILE"
echo "  Press Ctrl+C to exit"
echo "============================================================"
echo ""

tail -n 30 -f "$LOG_FILE"
