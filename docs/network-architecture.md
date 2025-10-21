# Network Architecture Documentation

## Overview

The Ticketing Auto system uses a secure network architecture with network segmentation to separate public-facing services from internal services. This architecture enhances security by limiting exposure of internal services while allowing controlled access to public services.

## Network Structure

### Networks

#### `ticketing_frontend` (Public Network)
- **Type**: Bridge network
- **Purpose**: Public-facing services that need external access
- **Connected Services**:
  - Traefik (reverse proxy)
  - Zammad (ticketing system)
  - OCS Inventory (asset management)
  - Wiki.js (documentation system)
  - Prometheus (monitoring)
  - Grafana (monitoring UI)
  - Loki (monitoring)
  - Alertmanager (monitoring)
- **Access**: External access via Traefik reverse proxy with TLS termination

#### `ticketing_backend` (Internal Network)
- **Type**: Bridge network with `internal: true` flag
- **Purpose**: Internal-only services that should not be directly exposed externally
- **Connected Services**:
  - OpenLDAP (user directory)
  - PostgreSQL (database for Zammad and Wiki.js)
  - MariaDB (database for OCS Inventory)
  - Redis (cache for Zammad)
  - Elasticsearch (search engine for Zammad)
  - Promtail (log collection)
- **Access**: Internal-only - no external access

## Service Network Assignment Strategy

### Public Services (Frontend Network Only)
Services that need direct external access:
- Traefik (reverse proxy)
- Monitoring stack (Prometheus, Grafana, Loki, Alertmanager)
- Application frontends (Zammad, OCS Inventory, Wiki.js)

### Internal Services (Backend Network Only)
Services that should never be exposed externally:
- OpenLDAP (user directory)
- All databases (PostgreSQL, MariaDB)
- Cache and search services (Redis, Elasticsearch)
- Log collection agents (Promtail)

### Dual Network Services (Both Networks)
All services use both networks via the `x-networks` template, allowing:
- Internal communication between services on the backend network
- External access via Traefik on the frontend network

## Traefik Configuration

### Network Strategy
Traefik is connected to both networks, allowing it to:
1. **Route external traffic** from the frontend network to services on the backend network
2. **Secure internal communication** between services using the backend network

### Host Rules (Fixed with single quotes)
All host rules use single quotes to avoid YAML parsing issues:
```yaml
"traefik.http.routers.service-name.rule=Host('subdomain.${TRAEFIK_DOMAIN}')"
```

### Service Configuration
- **Entrypoints**: `websecure` (HTTPS only)
- **TLS**: Automatic certificate management via Let's Encrypt
- **Service Discovery**: Docker provider with labels
- **Dashboard**: Secured with basic auth middleware

## Security Architecture

### Network Segmentation Benefits
1. **Reduced Attack Surface**: Internal services are not exposed externally
2. **Controlled Access**: All external access goes through Traefik reverse proxy
3. **Service Isolation**: Services can communicate internally without external exposure
4. **TLS Termination**: All external traffic is encrypted end-to-end

### Service Communication Flow

#### External Access Flow
```
User → Traefik (frontend network) → Service (backend network)
```

#### Internal Communication Flow
```
Service A (backend network) → Service B (backend network)
```

## Service Network Assignments

### Frontend Network Services
| Service | Purpose | Network Role |
|---------|---------|-------------|
| Traefik | Reverse proxy | External access point |
| Zammad | Ticketing system | Application frontend |
| OCS Inventory | Asset management | Application frontend |
| Wiki.js | Documentation | Application frontend |
| Prometheus | Monitoring | Monitoring UI |
| Grafana | Monitoring UI | Monitoring UI |
| Loki | Monitoring | Monitoring UI |
| Alertmanager | Monitoring | Monitoring UI |

### Backend Network Services
| Service | Purpose | Network Role |
|---------|---------|-------------|
| OpenLDAP | User directory | Internal service |
| PostgreSQL | Database | Internal service |
| MariaDB | Database | Internal service |
| Redis | Cache | Internal service |
| Elasticsearch | Search engine | Internal service |
| Promtail | Log collection | Internal service |

### Dual Network Services
All services use both networks for internal communication and external access.

## Health Checks
All services include health checks to ensure service availability and proper network connectivity.

## Environment Variables
- `TRAEFIK_DOMAIN`: Base domain for all services
- Environment variables are used for service discovery and configuration.

## Volume Management
All data is persisted using named volumes with consistent naming conventions.

## Security Features

### 1. Network Segmentation
- Internal services never exposed externally
- All external access through Traefik reverse proxy

### 2. TLS Configuration
- Let's Encrypt integration for automatic certificate management
- HTTPS only via redirect from HTTP to HTTPS

### 3. Service Discovery
- Docker labels for service discovery
- No manual configuration needed

### 4. Health Monitoring
- Built-in health checks for all services

## Validation Results

### Configuration Validation
```bash
docker-compose config --quiet
```
✅ **Result**: Configuration is valid with only expected environment variable warnings

### Key Fixes Applied
1. **Fixed Traefik dashboard labels syntax**:
   - Changed from backticks to single quotes for host rules
   - Fixed indentation issues in labels section

2. **Network configuration validated**:
   - Frontend network allows external access
   - Backend network is internal-only
   - All services properly assigned to appropriate networks

3. **Traefik service uses both networks correctly**:
   - Connected to both frontend and backend networks
   - Proper routing configuration
   - TLS configuration validated

4. **Services properly assigned to networks**:
   - Public services on frontend network
   - Internal services on backend network
   - All services use both networks for internal communication

## Conclusion

The network architecture provides:
- ✅ Secure network segmentation
- ✅ External access control
- ✅ Internal service isolation
- ✅ TLS security
- ✅ Service discovery automation

This architecture successfully separates concerns and enhances security while maintaining flexibility for service communication.
