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

Then edit the scheme to add command-line arguments and environment variables.

### Running

```bash
swift run aruba1830 --help
```

Or after building:

```bash
.build/debug/aruba1830 --help
```

## Documentation

- **`ARUBA_1830_API_REFERENCE.md`** - Complete API documentation
  - 118 endpoints cataloged
  - Authentication flow
  - Request/response formats
  - All operations documented
  - Port enable/disable procedures
  - MAC table operations

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

Set up credentials in `.env` file in the project root:

```bash
ARUBA_HOST=192.168.7.68
ARUBA_USERNAME=admin
ARUBA_PASSWORD=yourpassword
```

The CLI will automatically authenticate and acquire session credentials.

Alternatively, provide credentials via command line:

```bash
aruba1830 mac-table --host 192.168.7.68 --user admin --password secret
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

# Enable a port by number
aruba1830 port enable 1

# Enable a port by MAC address (auto-detected)
aruba1830 port enable aa:bb:cc:dd:ee:ff

# Enable all ports at once
aruba1830 port enable all

# Disable a port by number
aruba1830 port disable 1

# Disable a port by MAC address (auto-detected, with safety check!)
aruba1830 port disable aa:bb:cc:dd:ee:ff

# Force disable even if multiple MACs on port
aruba1830 port disable aa:bb:cc:dd:ee:ff --force

# Disable all ports at once
aruba1830 port disable all
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

## Special Feature: Smart Port Control

The CLI automatically detects whether you're specifying a port number or MAC address - no flags needed!

```bash
# By port number (auto-detected)
aruba1830 port enable 1

# By MAC address (auto-detected)
aruba1830 port enable aa:bb:cc:dd:ee:ff

# Enable or disable all ports
aruba1830 port enable all
aruba1830 port disable all
```

**Safety Check for MAC-based Disable:** When disabling a port by MAC address, if multiple MAC addresses are detected on the target port, the CLI will warn you and require the `--force` flag:

```
⚠️  Warning: 5 MAC addresses found on port 8
Use --force to disable anyway
```

This prevents accidentally disconnecting multiple devices. Simply add `--force` if you're sure:

```bash
aruba1830 port disable aa:bb:cc:dd:ee:ff --force
```
