# Mainframe Lab

A containerized mainframe environment with MVS 3.8j TK4- and FTP server for learning and testing mainframe operations and SITE/QUOTE commands.

## Features

- 🖥️ **MVS 3.8j TK4-** - Full mainframe operating system simulation
- 📡 **TN3270 Terminal** - Connect with authentic 3270 terminal emulation
- 🌐 **Web Console** - Modern web interface for system monitoring
- 📁 **FTP Server** - Test SITE/QUOTE commands and file operations
- 🔧 **Task Automation** - Simple commands for all operations

## Prerequisites

```bash
# Install 3270 terminal emulator
brew install x3270

# Install task runner (optional but recommended)
brew install go-task/tap/go-task
```

## Quick Start

```bash
# Start the lab
task start
# or 
./start-lab.sh

# Submit a JCL job
task submit
# or
./submit-hello.sh

# Test FTP functionality  
task test-ftp
# or
./test-ftp.sh

# Open web console
task console
```

## Task Commands

```bash
task start          # Start all services
task stop           # Stop all services  
task submit         # Submit hello.jcl job
task test-ftp       # Test FTP with SITE/QUOTE commands
task console        # Open Hercules web console
task status         # Check service status
task restart        # Restart all services
task teardown       # Complete cleanup
```

## Scripts (Alternative to Tasks)

- `./start-lab.sh` - Start mainframe and FTP services
- `./stop-lab.sh` - Stop all services
- `./submit-hello.sh` - Submit hello world JCL job  
- `./test-ftp.sh` - Test FTP with SITE/QUOTE commands

## Access Points

- **TN3270 Terminal**: `c3270 localhost:3270`
- **Web Console**: [http://localhost:8038](http://localhost:8038) - Monitor job status and system logs
- **FTP Server**: `ftp://dev:devpass@localhost:2121`

## Usage Examples

### Submit JCL Job
```bash
# Using task
task submit

# Or manually
cat ./jcl/hello.jcl | nc localhost 3505

# Check status in web console
open http://localhost:8038
```

### FTP Testing
```bash
# Interactive FTP
ftp localhost 2121
Name: dev
Password: devpass
ftp> quote site help
ftp> ls
ftp> quit

# Using curl with SITE commands
curl -v --quote "SITE HELP" ftp://dev:devpass@localhost:2121/
```

### TN3270 Terminal
```bash
# Connect to mainframe
c3270 localhost:3270

# Login with standard MVS credentials
# (Check TK4- documentation for user accounts)
```

## Directory Structure

```
mainframe-lab/
├── docker/
│   └── docker-compose.yaml    # Container configuration
├── jcl/
│   └── hello.jcl             # Sample JCL job
├── ftphome/                  # FTP storage (auto-created)
├── Taskfile.yml             # Task automation
└── *.sh                     # Individual scripts
```

