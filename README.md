# Aruba 1830 CLI

A cross-platform Swift CLI tool for managing Aruba 1830 network switches via HTTP API.

## Features

- 🔧 **Port Management** - Enable/disable ports, view status and statistics
- 📊 **MAC Address Table** - View and filter MAC addresses by VLAN or port
- 🌐 **VLAN Management** - View and manage VLANs
- ⚡ **PoE Control** - Manage Power over Ethernet settings
- 📝 **System Monitoring** - View logs, system info, and diagnostics
- 🔐 **User Management** - Manage admin users and sessions
- 🏗️ **Cross-platform** - Builds on macOS and Linux

## Quick Start

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

### Debugging in Xcode

Open the project in Xcode for full debugging support:

```bash
open Package.swift
```

See **`DEBUG_CRASH.md`** for detailed debugging instructions and troubleshooting tips.

### Running

```bash
swift run aruba1830 --help
```

Or after building:

```bash
.build/debug/aruba1830 --help
```

## Documentation

### For Users
- **`ARUBA_1830_API_REFERENCE.md`** - Complete API documentation
  - 118 endpoints cataloged
  - Authentication flow
  - Request/response formats
  - All operations documented

### For Developers
- **`SWIFT_IMPLEMENTATION_GUIDE.md`** - Swift implementation guide
  - HTTP client patterns
  - XML parsing strategies
  - Session management
- **`DEBUG_CRASH.md`** - Debugging guide
  - Xcode setup instructions
  - Troubleshooting crashes
  - Debugging techniques
  - Code examples

## Package Structure

- `Aruba1830CLICore` - Core library with reusable functionality
  - API client
  - XML parser
  - Session management
  - Data models
- `Aruba1830CLI` - Executable target with CLI commands
- `Aruba1830CLICoreTests` - Test suite for the core library

## Requirements

- Swift 6.2 or later
- macOS 13+ or Linux
- Access to Aruba 1830 switch management interface

## Swift 6.2 Features

This package uses Swift 6 language mode with:
- Strict concurrency checking
- Modern Swift 6 language features
- ExistentialAny upcoming feature enabled
- Full async/await support for API calls

## CLI Commands

### Configuration

Set up credentials in `.env` file (see [ENV_EXAMPLE.md](ENV_EXAMPLE.md)):

```bash
ARUBA_HOST=192.168.7.68
ARUBA_USERNAME=admin
ARUBA_PASSWORD=yourpassword
ARUBA_SESSION_TOKEN=cs2d4faf80
```

Or provide via command line:

```bash
aruba1830 mac-table --host 192.168.7.68 --user admin --password secret --session-token cs2d4faf80
```

### MAC Address Table

```bash
# View entire MAC table
aruba1830 mac-table

# Filter by VLAN
aruba1830 mac-table --vlan 10

# Filter by port
aruba1830 mac-table --port 5

# Combine filters
aruba1830 mac-table --vlan 10 --port 5
```

### Port Control

```bash
# List all ports
aruba1830 port list

# Enable a port
aruba1830 port enable 1

# Disable a port by number
aruba1830 port disable 1

# Disable port by MAC address (special feature!)
aruba1830 port disable 11:22:33:44:55:66

# Force disable even if multiple MACs on port
aruba1830 port disable 11:22:33:44:55:66 --force

# Alternative command for MAC-based disable
aruba1830 port disable-by-mac 11:22:33:44:55:66
```

### System Information

```bash
# Display system info
aruba1830 system info

# View logs
aruba1830 system logs

# View last 50 log entries
aruba1830 system logs --tail 50
```

### VLAN Management

```bash
# List all VLANs
aruba1830 vlan list
```

### PoE Management

```bash
# View PoE status for all ports
aruba1830 poe status

# Disable PoE on a port
aruba1830 poe disable 5
```

## Special Feature: Port Disable by MAC Address

The CLI includes a safety feature when disabling ports by MAC address:

```bash
# Find MAC in table and disable associated port
aruba1830 port disable aa:bb:cc:dd:ee:ff
```

**Safety Check:** If multiple MAC addresses are detected on the target port, the CLI will warn you and require the `--force` flag:

```
⚠️  Warning: 5 MAC addresses found on port 8
Use --force to disable anyway
```

This prevents accidentally disconnecting multiple devices.

## Testing

⚠️ **IMPORTANT:** Tests that modify switch configuration only affect **PORT 1** to prevent network disruption.

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ModelsTests
swift test --filter XMLParserTests
swift test --filter ConfigurationTests
```

