#!/bin/bash

# Test FTP server with SITE and QUOTE commands
# This demonstrates various FTP operations including SITE/QUOTE functionality

echo "🌐 Testing FTP Server with SITE/QUOTE Commands..."
echo "================================================="

# Check if FTP container is running
if ! docker ps | grep -q ftp; then
    echo "❌ Error: FTP container is not running!"
    echo "   Run './start-lab.sh' first"
    exit 1
fi

echo "📁 Creating test files in FTP directory..."
mkdir -p ./docker/ftp/test
echo "Hello from FTP test!" > ./docker/ftp/test/sample.txt
echo "JCL test file" > ./docker/ftp/test/test.jcl

echo ""
echo "🔐 Testing FTP connection and basic commands..."

# Check if ftp command is available
if ! command -v ftp &> /dev/null; then
    echo "⚠️  FTP command not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install inetutils
    else
        echo "❌ Homebrew not found. Please install FTP client manually:"
        echo "   brew install inetutils"
        echo ""
        echo "🔄 Continuing with curl tests only..."
    fi
fi

# Test basic FTP connection and SITE commands
cat << 'EOF' > /tmp/ftp_test_commands.txt
user dev devpass
binary
passive off
pwd
ls
cd test
ls -la
quote site help
quote site chmod 755 sample.txt
quote site chmod 644 test.jcl
ls -la
put jcl/hello.jcl
ls -la
quote stat
quit
EOF

echo "📤 Executing FTP test session..."
if command -v ftp &> /dev/null; then
    ftp -n localhost 2121 < /tmp/ftp_test_commands.txt
else
    echo "⚠️  FTP command not available, skipping interactive FTP test"
fi

echo ""
echo "🧪 Testing with curl and QUOTE commands..."

# First upload a file to test chmod on
echo "📤 Uploading test file first..."
curl -T ./jcl/hello.jcl ftp://dev:devpass@localhost:2121/test/hello.jcl

echo ""
echo "Testing SITE CHMOD with curl..."
curl -v --quote "SITE CHMOD 755 test/hello.jcl" ftp://dev:devpass@localhost:2121/

echo ""
echo "Testing SITE HELP with curl..."
curl -v --quote "SITE HELP" ftp://dev:devpass@localhost:2121/

echo ""
echo "Testing STAT command with curl..."
curl -v --quote "STAT" ftp://dev:devpass@localhost:2121/

echo ""
echo "📂 Listing files with curl..."
curl -l ftp://dev:devpass@localhost:2121/test/

echo ""
echo "✅ FTP testing completed!"
echo ""
echo "📋 Summary of tested SITE/QUOTE commands:"
echo "   • SITE HELP - Show available site commands"
echo "   • SITE CHMOD - Change file permissions"
echo "   • STAT - Show server status"
echo ""
echo "📁 Check uploaded files: ls -la ./docker/ftp/test/"
echo ""
echo "💡 Note: Pure-FTPd may not support all SITE commands."
echo "   Check server logs if commands fail: docker logs ftp"

# Cleanup
rm -f /tmp/ftp_test_commands.txt