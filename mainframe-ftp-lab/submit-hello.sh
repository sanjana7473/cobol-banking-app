#!/bin/bash

# Submit the hello.jcl job to the mainframe
# This demonstrates how to submit JCL via the card reader port

echo "📄 Submitting HELLO JCL Job..."
echo "=============================="

# Check if the hello.jcl file exists
if [ ! -f "./jcl/hello.jcl" ]; then
    echo "❌ Error: ./jcl/hello.jcl not found!"
    exit 1
fi

# Check if TK4 is running
if ! docker ps | grep -q tk4; then
    echo "❌ Error: TK4 container is not running!"
    echo "   Run './start-lab.sh' first"
    exit 1
fi

echo "📤 Submitting JCL to card reader (port 3505)..."
python3 -c "
import socket
with open('./jcl/hello.jcl', 'rb') as f:
    data = f.read()
s = socket.socket()
s.settimeout(10)
s.connect(('127.0.0.1', 3505))
s.send(data)
s.close()
print('JCL sent successfully')
"

if [ $? -eq 0 ]; then
    echo "✅ JCL submitted successfully!"
    echo ""
    echo "🔍 Monitor the job:"
    echo "   • Check Hercules console: http://localhost:8038"
    echo "   • Watch output: ./monitor-output.sh"
    echo "   • Check printer files: ls -la ./docker/prt/"
    echo ""
    echo "💡 The job should compile and run a COBOL 'Hello World' program"
else
    echo "❌ Failed to submit JCL!"
    exit 1
fi