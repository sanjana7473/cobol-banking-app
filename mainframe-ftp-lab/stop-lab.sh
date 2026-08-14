#!/bin/bash

# Stop the mainframe lab environment
# This script stops and cleans up the Docker containers

echo "🛑 Stopping Mainframe Lab Environment..."
echo "========================================"

# Stop the containers
docker compose -f docker/docker-compose.yaml down

echo ""
echo "📊 Container Status:"
docker compose -f docker/docker-compose.yaml ps

echo ""
echo "✅ Lab environment stopped!"
echo ""
echo "📁 Your data is preserved in:"
echo "   • ./jcl/ - JCL files"
echo "   • ./docker/prt/ - Printer output"
echo "   • ./docker/pch/ - Punch output"
echo "   • ./docker/ftp/ - FTP storage"
echo "   • ./docker/log/ - Log files"
echo ""
echo "💡 To restart: ./start-lab.sh"