#!/bin/bash

# Start the mainframe lab environment
# This script starts both the TK4- mainframe simulator and FTP server

echo "🚀 Starting Mainframe Lab Environment..."
echo "========================================"

# Start the lab
docker compose -f docker/docker-compose.yaml up -d


echo ""
echo "⏳ Waiting for services to start..."
sleep 10

# Check if services are running
echo ""
echo "📊 Service Status:"
echo "=================="
docker compose -f docker/docker-compose.yaml ps

echo ""
echo "🔗 Access Points:"
echo "================="
echo "• TN3270 Terminal: c3270 localhost:3270"
echo "• Hercules Console: http://localhost:8038"
echo "• FTP Server: ftp://dev:devpass@localhost:2121"
echo ""
echo "📁 Important Directories:"
echo "========================"
echo "• JCL Files: ./jcl/"
echo "• FTP Storage: ./ftphome/"
echo ""
echo "🎯 Ready to test! Use the other scripts to submit jobs and test FTP."
echo "   • ./submit-hello.sh - Submit hello world JCL"
echo "   • ./test-ftp.sh - Test FTP with SITE/QUOTE commands"
echo "   • ./monitor-output.sh - Watch for job output"