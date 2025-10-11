# Aruba 1830 Switch - HTTP API Reference

**Automatic API Documentation**  
**Version:** 1.0  
**Last Updated:** 2025-10-11  

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication & Sessions](#authentication--sessions)
3. [API Endpoints](#api-endpoints)
4. [Data Operations](#data-operations)
5. [Configuration Operations](#configuration-operations)
6. [Response Format](#response-format)
7. [Error Handling](#error-handling)
8. [Complete Endpoint Catalog](#complete-endpoint-catalog)

---

## Overview

The Aruba 1830 switch provides an HTTP-based management API with the following characteristics:

- **Protocol:** HTTP (no HTTPS in tested configuration)
- **Data Format:** XML for both requests and responses
- **Authentication:** Dual system (URL session token + HTTP cookies)
- **Server:** GoAhead-Webs embedded web server

### Key Features

- Read switch configuration and status
- Modify port and system settings
- Query MAC address tables
- Manage VLANs, PoE, and QoS
- Access system logs and diagnostics
- Control user access and security

---

## Authentication & Sessions

### Session Model

The Aruba 1830 uses a **dual authentication system**:

1. **URL-based session token** - Embedded in the request path
2. **HTTP cookies** - Contain user credentials and session ID

Both components are required for API access.

### Session Token

**Format:**
```
http://192.168.7.68/{SESSION_TOKEN}/hpe/
```

**Example:**
```
http://192.168.7.68/cs2d4faf80/hpe/
```

- Session token is a random alphanumeric string (e.g., `cs2d4faf80`)
- Generated automatically by the server on first access
- Used in the URL path for all subsequent requests

### Session Cookies

**Required Cookies:**
```
sessionID=UserId={CLIENT_IP}&{SESSION_HASH}&
userName={USERNAME}
activeLangId=english
```

**Example:**
```
Cookie: sessionID=UserId=192.168.7.206&8f173f64d04b9f15b81b0f367d7995d1&; userName=melle; activeLangId=english
```

### Authentication Flow

**Complete Login Sequence:**

1. **Obtain Session Token** (via 302 Redirect)
   ```http
   GET http://{SWITCH_IP}/ HTTP/1.1
   ```
   **Response:**
   ```http
   HTTP/1.1 302 Redirect
   Location: /{SESSION_TOKEN}/hpe/config/log_off_page.htm
   ```
   The session token (e.g., `cs2d4faf80`) is extracted from the Location header.

2. **Login with Credentials**
   ```http
   GET /{SESSION_TOKEN}/htdocs/login/system.xml?action=login&user={USERNAME}&password={PASSWORD}&ssd=true& HTTP/1.1
   Host: {SWITCH_IP}
   ```
   **Response:**
   ```http
   HTTP/1.1 200 OK
   Set-Cookie: sessionID=UserId={CLIENT_IP}&{SESSION_HASH}&;path=/; HttpOnly
   Content-Type: text/xml
   
   <?xml version='1.0' encoding='UTF-8'?>
   <ResponseData>
     <ActionStatus>
       <statusCode>0</statusCode>
       <statusString>OK</statusString>
     </ActionStatus>
   </ResponseData>
   ```

3. **Use Session** - All subsequent requests include:
   - Session token in URL path: `/{SESSION_TOKEN}/hpe/wcd?...`
   - Session cookie in header: `Cookie: sessionID=...`

**Important Notes:**
- The login endpoint is `/htdocs/login/system.xml` (not a POST to login.lua)
- Credentials are passed as URL query parameters (should be URL-encoded)
- The `sessionID` cookie is automatically set via the `Set-Cookie` header
- The `ssd=true&` parameter appears to be required (trailing `&` included)

---

## API Endpoints

### Base URL Pattern

All API calls follow this pattern:

```
http://{SWITCH_IP}/{SESSION_TOKEN}/hpe/wcd?{QueryExpression}
```

**Components:**
- `{SWITCH_IP}`: Switch management IP address (e.g., `192.168.7.68`)
- `{SESSION_TOKEN}`: Session identifier (e.g., `cs2d4faf80`)
- `{QueryExpression}`: Query wrapped in curly braces (e.g., `{ForwardingTable}`)

### Query Expression Format

Queries are wrapped in curly braces and can include:

- **Simple table name:** `{TableName}`
- **Multiple tables:** `{Table1}{Table2}{Table3}`
- **With filters:** `{TableName&filter=(condition)}`
- **With parameters:** `{TableName&UnitID=0&interfaceType=1}`
- **Pagination:** `{TableName&entryCount=en&Count=10}`

### Common Endpoint Examples

```
# MAC address table
GET /wcd?{ForwardingTable}

# All ports information
GET /wcd?{Ports}

# Ports filtered by unit
GET /wcd?{Ports&UnitID=0&interfaceType=1}

# System configuration
GET /wcd?{SystemGlobalSetting}

# VLAN list
GET /wcd?{VLANList}

# Combined query (multiple tables)
GET /wcd?{SystemGlobalSetting}{Units}{VLANList}
```

---

## Data Operations

### Reading Data (GET Requests)

**Request Format:**
```http
GET /{SESSION_TOKEN}/hpe/wcd?{QueryExpression} HTTP/1.1
Host: {SWITCH_IP}
Cookie: sessionID={SESSION_COOKIE}; userName={USERNAME}
```

**Response Format:**
```xml
<?xml version="1.0" encoding="UTF-8" ?>
<ResponseData>
  <DeviceConfiguration>
    <TableName type="section">
      <Entry>
        <field1>value1</field1>
        <field2>value2</field2>
      </Entry>
      <!-- More entries... -->
    </TableName>
  </DeviceConfiguration>
</ResponseData>
```

### Example: MAC Address Table

**Request:**
```http
GET /cs2d4faf80/hpe/wcd?{ForwardingTable}
Cookie: sessionID=UserId=192.168.7.206&hash&; userName=admin
```

**Response:**
```xml
<?xml version="1.0" encoding="UTF-8" ?>
<ResponseData>
<DeviceConfiguration>
  <ForwardingTable type="section">
    <Entry>
      <VLANID>1</VLANID>
      <MACAddress>00:23:43:00:17:d5</MACAddress>
      <interfaceType>1</interfaceType>
      <interfaceName>18</interfaceName>
      <addressType>3</addressType>
    </Entry>
    <Entry>
      <VLANID>1</VLANID>
      <MACAddress>04:a1:51:74:6b:4f</MACAddress>
      <interfaceType>1</interfaceType>
      <interfaceName>3</interfaceName>
      <addressType>3</addressType>
    </Entry>
  </ForwardingTable>
</DeviceConfiguration>
</ResponseData>
```

**Field Definitions:**
- `VLANID`: VLAN identifier (integer)
- `MACAddress`: MAC address in colon-separated format
- `interfaceType`: Interface type (1 = physical port)
- `interfaceName`: Port number or interface name
- `addressType`: Address type (3 = dynamic, others = static)

---

## Configuration Operations

### Writing Data (POST Requests)

**Request Format:**
```http
POST /{SESSION_TOKEN}/hpe/wcd?{QueryExpression} HTTP/1.1
Host: {SWITCH_IP}
Cookie: sessionID={SESSION_COOKIE}; userName={USERNAME}
Content-Type: application/x-www-form-urlencoded

<?xml version='1.0' encoding='utf-8'?>
<DeviceConfiguration>
  <TableName action="set|delete">
    <Entry>
      <field1>value1</field1>
      <field2>value2</field2>
    </Entry>
  </TableName>
</DeviceConfiguration>
```

**Action Types:**
- `action="set"` - Create or update configuration
- `action="delete"` - Delete configuration entry

### Example: Port Enable/Disable

**Disable Port 1:**

```http
POST /cs2d4faf80/hpe/wcd?{Standard802_3List}
Cookie: sessionID=...; userName=admin
Content-Type: application/x-www-form-urlencoded

<?xml version='1.0' encoding='utf-8'?>
<DeviceConfiguration>
  <Standard802_3List action="set">
    <Entry>
      <adminState>2</adminState>
      <interfaceName>1</interfaceName>
      <interfaceDescription></interfaceDescription>
      <autoNegotiationAdminEnabled>1</autoNegotiationAdminEnabled>
      <adminAdvertisementList>100000000000000000000000</adminAdvertisementList>
    </Entry>
  </Standard802_3List>
  <STP action="set">
    <InterfaceList>
      <InterfaceEntry>
        <interfaceName>1</interfaceName>
        <STPEnabled>1</STPEnabled>
        <timeRangeName></timeRangeName>
      </InterfaceEntry>
    </InterfaceList>
  </STP>
  <TimeBasedPortTable action="delete">
    <Entry>
      <interfaceName>1</interfaceName>
      <timeRangeName></timeRangeName>
    </Entry>
  </TimeBasedPortTable>
</DeviceConfiguration>
```

**Enable Port 1:**

Same as above, but change:
```xml
<adminState>1</adminState>  <!-- 1 = Enabled, 2 = Disabled -->
```

**Key Configuration Fields:**
- `adminState`: **1** = Port Enabled, **2** = Port Disabled
- `interfaceName`: Port number (string: "1", "2", etc.)
- `autoNegotiationAdminEnabled`: **1** = Auto-negotiation on, **2** = off
- `adminAdvertisementList`: Bit mask for advertised speeds
- `STPEnabled`: **1** = STP enabled on port, **2** = disabled

---

## Response Format

### Success Response

```xml
<?xml version='1.0' encoding='UTF-8'?>
<ResponseData>
  <ActionStatus>
    <version>1.0</version>
    <requestURL>TableName</requestURL>
    <requestAction>set</requestAction>
    <statusCode>0</statusCode>
    <deviceStatusCode>0</deviceStatusCode>
    <statusString>OK</statusString>
  </ActionStatus>
</ResponseData>
```

**Status Indicators:**
- `statusCode=0`: Operation successful
- `statusString="OK"`: Success message
- `deviceStatusCode=0`: Device-level success

### Error Response

```xml
<?xml version='1.0' encoding='UTF-8'?>
<ResponseData>
  <ActionStatus>
    <version>1.0</version>
    <requestURL>TableName</requestURL>
    <requestAction>set</requestAction>
    <statusCode>3</statusCode>
    <deviceStatusCode>...</deviceStatusCode>
    <statusString>Error description</statusString>
  </ActionStatus>
</ResponseData>
```

**Error Status Codes:**
- `statusCode=3`: Operation failed
- `statusString`: Contains error description

---

## Error Handling

### HTTP Status Codes

- **200 OK**: Request processed (check XML ActionStatus for actual result)
- **302 Redirect**: Session token assignment or authentication redirect
- **401 Unauthorized**: Session expired or invalid credentials
- **403 Forbidden**: Insufficient permissions
- **404 Not Found**: Invalid endpoint or resource

### Session Expiry

**Detection:**
- HTTP 401/403 responses
- Redirect to login page
- ActionStatus with authentication error

**Default Timeout:**
- Timeout duration not yet documented
- Appears to be inactivity-based

**Session Refresh:**
- Make any valid API call to extend session
- Re-authenticate if session expired

---

## Complete Endpoint Catalog

### System Configuration (36 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{SystemGlobalSetting}` | Global system settings |
| `{Units}` | Device unit information |
| `{TimeSetting}` | Date/time configuration |
| `{LocateUnit}` | Unit location/identification |
| `{DiagnosticsUnitList}` | Diagnostics information |
| `{ImageUnitList}` | Firmware images |
| `{InterfaceGlobalSetting}` | Interface global configuration |
| `{ManagementInterfaceGlobalSetting}` | Management interface settings |
| `{EWSGlobalSetting}` | Embedded Web Server settings |
| `{SNMPGlobalSetting}` | SNMP configuration |
| `{SNTPGlobalSetting}` | SNTP/NTP settings |
| `{SNTPServerTable}` | SNTP server list |
| `{LogGlobalSetting}` | Logging configuration |
| `{SyslogGlobalSetting}` | Syslog settings |
| `{ForwardingGlobalSetting}` | Forwarding/switching settings |
| `{VLANGlobalSetting}` | VLAN global settings |
| `{LLDPGlobalSetting}` | LLDP global settings |
| `{LLDPGlobalAdvertisementStatus}` | LLDP advertisement status |
| `{LACPGlobalSetting}` | LACP configuration |
| `{SpanningTreeGlobalParam}` | STP global parameters |
| `{PasswordGlobalParam}` | Password policy |
| `{TimeRangeList}` | Time-based access rules |
| `{TimeRangePeriodicList}` | Periodic time ranges |
| `{TimeBasedPortTable}` | Time-based port control |
| `{InterfaceRecoveryGlobalSetting}` | Auto-recovery settings |
| `{LoopbackDetectionGlobalSetting}` | Loop detection |
| `{MulticastGlobalSetting}` | Multicast settings |
| `{EEEGlobalSetting}` | Energy Efficient Ethernet |
| `{GreenEthGlobalSetting}` | Green Ethernet features |
| `{DOSGlobalSettings}` | Denial of Service protection |
| `{DHCPv6GlobalSetting}` | DHCPv6 configuration |
| `{AAAGlobalSetting}` | AAA (Authentication, Authorization, Accounting) |
| `{CommunityList}` | SNMP communities |
| `{PoEPSEUnitList}` | PoE unit information |
| `{EncryptionSetting}` | Encryption configuration |
| `{ComponentMapperTable&filter=...}` | Component mapping |
| `{VLANInterfaceList&UnitID=...}` | VLAN per-unit interface list |
| `{BoardProfileList}` | Board profiles |

### Port/Interface Management (24 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{Ports}` | All ports information |
| `{Ports&UnitID=0&interfaceType=1}` | Ports filtered by unit |
| `{Standard802_3List}` | 802.3 Ethernet settings |
| `{Standard802_3List&interfaceType=1}` | Filtered 802.3 settings |
| `{Standard802_3List&entryCount=en&Count=10}` | Paginated results |
| `{LACPPortList}` | LACP port configuration |
| `{LLDPInterfaceList}` | LLDP per-interface |
| `{LLDPStatisticsInterfaceList}` | LLDP statistics |
| `{PoEPSEInterfaceList}` | PoE per-interface settings |
| `{EEEInterfaceList}` | Energy Efficient Ethernet per-interface |
| `{EEELLDPInterfaceList}` | EEE LLDP settings |
| `{EEELLDPLocalInterfaceList}` | EEE LLDP local |
| `{ErrorRecoveryInterfaceTable}` | Port error recovery |
| `{VLANInterfaceISList}` | VLAN interface-specific |
| `{VLANInterfaceMembershipTable}` | VLAN membership |
| `{EtherlikeStatisticsList}` | Etherlike statistics |
| `{StatisticsList}` | General port statistics |
| `{LLDPMEDAdvertisementInterfaceList}` | LLDP-MED advertisement |
| `{LLDPMEDInterfaceList}` | LLDP-MED settings |
| `{IGMPMLDSnoopRouterPortList&addrType=1}` | IGMP/MLD router ports |
| `{SSLCryptoCertificateImportList}` | SSL certificate import |
| `{HostParamTable&name=l2_port_supported_speeds}` | Port capabilities |
| `{StormControlTable}` | Broadcast storm control |
| `{SpanDestinationTable}` | Port mirroring destinations |
| `{SpanSourceTable}` | Port mirroring sources |

### VLAN Management (3 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{VLANList}` | All VLANs |
| `{VLANCurrentStatus}` | Current VLAN status |
| `{IGMPMLDSnoopVLANList&addrType=1}` | IGMP/MLD snooping per VLAN |

### Spanning Tree Protocol (4 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{STP}` | STP configuration |
| `{STP&entryCount=en&Count=10}` | STP paginated |
| `{RSTP}` | RSTP settings |
| `{STPInterfaceCountersList}` | STP interface counters |
| `{General&HostParam=/hpe/js/hostparams.js}` | General STP parameters |

### LLDP (3 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{LLDPMEDNeighborList}` | LLDP-MED neighbors |
| `{LLDPMEDNeighborList&entryCount=en&Count=10}` | Paginated neighbors |
| `{LLDPGlobalAdvertisementStatus}` | LLDP advertisement status |

### Routing & IP (1 endpoint)

| Endpoint | Description |
|----------|-------------|
| `{ManagementIpv4AddressTable}` | Management IP addresses |

### Quality of Service (3 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{CoSSetting}` | Class of Service settings |
| `{CoSToQueueMappingList}` | CoS to queue mapping |
| `{DSCPMapping}` | DSCP mapping configuration |

### Security & Access Control (2 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{PasswordComplexity}` | Password complexity rules |
| `{PasswordComplexityExcludeKeywordList}` | Password exclusions |

### User Management (3 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{AdminUserSetting}` | Admin user settings |
| `{AdminUserSetting&userName=USER}` | Specific user settings |
| `{ConnectedUserList}` | Currently connected users |

### Logging & Events (7 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{MemoryLogTable}` | RAM-based logs |
| `{FlashLogTable}` | Persistent flash logs |
| `{SyslogServerList}` | Syslog server configuration |
| `{SyslogSeverityCounters}` | Log severity counters |
| `{UnexpectedRestart}` | Unexpected restart status |
| `{UnexpectedRestartLogTable}` | Restart log entries |
| `{DOSPreventionTable&filter=...}` | DoS prevention logs |

### PoE Management (2 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{PoEPSEInterfaceList}` | PoE per-port settings |
| `{PoEStatisticsTable}` | PoE statistics |

### Diagnostics & Troubleshooting (5 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{DiagnosticsUnitList}` | Unit diagnostics |
| `{StackTopologyTable}` | Stack topology information |
| `{InventoryEntitiesTable}` | Hardware inventory |
| `{ErrorRecoveryTable}` | Error recovery status |
| `{LoopbackDetectionList}` | Loop detection results |

### MAC Address & Forwarding (2 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{ForwardingTable}` | MAC address table |
| `{ForwardingGlobalSetting}` | Forwarding settings |

### File Management (2 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{FileTable}` | File system table |
| `{FileTable&filter=(fileName=...)}` | File search |

### Link Aggregation (2 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{LAGList}` | Link Aggregation Groups |
| `{LAGList&entryCount=en&Count=10}` | Paginated LAG list |

### Miscellaneous (7 endpoints)

| Endpoint | Description |
|----------|-------------|
| `{SSLCryptoCertificateList}` | SSL certificates |
| `{SYNProtectionTable}` | SYN flood protection |
| `{SynRateProtectionTable}` | SYN rate limiting |
| `{IGMPMLDSnoopGroupList&filter=...}` | IGMP/MLD groups |
| `{GreenEthSavingTypeList&savingType=1}` | Green Ethernet savings |
| `{EWSServiceTable}` | Web server services |

---

## Appendix A: Common Use Cases

### View MAC Address Table

```
GET /wcd?{ForwardingTable}
```

### Get All Port Status

```
GET /wcd?{Ports}{Standard802_3List}
```

### Disable/Enable Port

```
POST /wcd?{Standard802_3List}
Body: <adminState>2</adminState> for disable
      <adminState>1</adminState> for enable
```

### View System Information

```
GET /wcd?{SystemGlobalSetting}{Units}{DiagnosticsUnitList}
```

### View VLANs

```
GET /wcd?{VLANList}{VLANCurrentStatus}
```

### View Logs

```
GET /wcd?{MemoryLogTable}
GET /wcd?{FlashLogTable}
```

### View LLDP Neighbors

```
GET /wcd?{LLDPMEDNeighborList}
```

### Check PoE Status

```
GET /wcd?{PoEPSEInterfaceList}{PoEStatisticsTable}
```

---

## Appendix B: Known Limitations

1. **Session Management**:
   - Session timeout duration not documented
   - Session refresh mechanism not documented  
   - Clean logout procedure not documented

2. **Error Codes**: Full list of statusCode values not documented

3. **HTTPS**: Switch tested with HTTP only; HTTPS support unknown

4. **Encryption**: The login endpoint accepts credentials as URL parameters (not ideal for security)
   - The API documentation shows an `{EncryptionSetting}` endpoint which may provide RSA encryption
   - RSA public key encryption may be available for password transmission

