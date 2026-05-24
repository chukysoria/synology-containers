# Monitoring Stack Setup Guide

This monitoring stack provides comprehensive Docker container and host system monitoring for your Synology DSM deployment.

## Components

### 1. **Prometheus** (Port 9090)
- **Purpose**: Time-series metrics database that scrapes and stores metrics from all exporters
- **Data Retention**: 30 days (configurable in `docker-compose.yaml`)
- **Configuration**: `prometheus.yml` defines all scrape targets
- **Access**: https://prometheus.{DOMAIN} (requires Authentik authentication via Traefik)

### 2. **cAdvisor** (Port 8080)
- **Purpose**: Google's container metrics exporter - provides CPU, memory, disk, network metrics per container
- **Features**: Real-time container statistics without requiring Docker socket permissions at dashboard level
- **Metrics**: CPU usage, memory usage, network I/O, disk I/O, cache metrics
- **Storage**: Minimal - only exports current metrics to Prometheus

### 3. **Node Exporter** (Port 9100)
- **Purpose**: Collects host-level system metrics from the Synology NAS
- **Metrics**: CPU, memory, disk, network interfaces, file descriptors, system load
- **Key for Synology**: Shows DSM resource usage alongside container metrics
- **Efficiency**: Lightweight agent with minimal resource overhead

### 4. **Grafana** (Port 3000)
- **Purpose**: Visualization dashboard and alerting
- **Authentication**: Integrated with Authentik via OAuth
- **Datasource**: Automatically provisioned to use Prometheus
- **Pre-built Dashboards**: Import from Grafana Dashboard Library (see below)

## Deployment Instructions

### Prerequisites
Ensure these environment variables are set before deploying:
- `DOMAIN`: Your domain (e.g., `boulebar.duckdns.org`)
- `GRAFANA_OAUTH_CLIENT_ID`: OAuth client ID from Authentik
- `GRAFANA_OAUTH_CLIENT_SECRET`: OAuth client secret from Authentik
- `PUID` and `PGID`: User and group IDs (defaults: 1029, 65536)
- `TZ`: Timezone (default: `Europe/Madrid`)

### Deployment Order (via Portainer)

1. **Start Prometheus, cAdvisor, Node Exporter first**:
   ```bash
   docker compose -f stacks/compose.yaml up -d prometheus cadvisor node-exporter
   ```
   Wait for all to be healthy (~1-2 minutes)

2. **Then start Grafana**:
   ```bash
   docker compose -f stacks/compose.yaml up -d grafana
   ```
   Grafana will automatically connect to Prometheus on startup

### File Locations on Synology

All monitoring data is stored under `${BASE_PATH}` (default: `/volume2/docker/`):

```
/volume2/docker/
├── prometheus/
│   └── data/              # Time-series database (~1GB per month typical)
├── grafana/
│   └── data/              # Grafana dashboards, users, settings
```

## Adding Pre-built Dashboards to Grafana

### Quick Setup (Recommended)

1. Login to Grafana: https://grafana.{DOMAIN}
2. Go to **Dashboards → Browse → + Create Dashboard**
3. Click **Import Dashboard**
4. Use Grafana Dashboard ID:

| Dashboard | ID | Purpose |
|-----------|-----|---------|
| Docker and Host Monitoring | 893 | Complete container and system overview |
| cAdvisor Exporter | 14282 | Detailed container metrics |
| Node Exporter Full | 1860 | Comprehensive host system metrics |
| Prometheus | 3662 | Prometheus health and scrape metrics |

**To import:**
- Paste dashboard ID → Select Prometheus datasource → Click Import

### Manual Dashboard Setup
Alternatively, download JSON from [Grafana Dashboards](https://grafana.com/grafana/dashboards/):
- Go to Grafana → Dashboards → Import
- Paste JSON or upload JSON file
- Select Prometheus as the datasource

## Monitoring Your Containers

### Available Metrics

**Container Metrics (from cAdvisor)**:
- CPU usage percentage per container
- Memory consumption (RSS, working set)
- Network bytes in/out
- Disk read/write operations
- Container uptime and restart counts

**Host Metrics (from Node Exporter)**:
- NAS CPU load and temperature
- Memory/Swap usage
- Disk space and I/O
- Network interface stats
- File system information
- Process counts

### Creating Custom Alerts

In Grafana:
1. Open a dashboard → Click **Alert** tab
2. Create alert rules (e.g., "CPU > 80%", "Memory > 85%")
3. Configure notification channels (email, webhook, Slack, etc.)

Example alert queries:
```promql
# High container CPU usage
rate(container_cpu_usage_seconds_total[5m]) * 100 > 80

# High memory usage
container_memory_usage_bytes / (1024*1024) > 512

# Host disk space low
node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1
```

## Configuration Details

### Prometheus Configuration (`prometheus.yml`)

Automatically scrapes:
- **Prometheus itself** (self-monitoring)
- **cAdvisor** (container metrics)
- **Node Exporter** (host metrics)
- **Portainer API** (container orchestration stats) - *optional, requires API access*

### Data Retention

Default: 30 days of metrics storage. Adjust in `docker-compose.yaml`:
```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=60d'  # Change to 60 days
```

### Network Architecture

```
┌─────────────────────────────────────┐
│      Traefik (frontend network)     │
│  - Exposes: grafana, prometheus     │
│  - Authentication: Authentik        │
└──────────────┬──────────────────────┘
               │
      ┌────────┴────────┐
      │                 │
   Grafana          Prometheus
   (frontend,      (frontend,
    grafana-db,    monitoring-net)
    monitoring-net)│
      │            │
      │    ┌───────┼────────┐
      │    │       │        │
      │  cAdvisor  Node   Portainer API
      │  (monitoring-net)  (frontend)
      │
   TimescaleDB
   (grafana-db-net)
```

## Troubleshooting

### Prometheus shows "No targets"
- Check Prometheus is healthy: `docker logs prometheus`
- Verify cAdvisor/Node Exporter are running and healthy
- Verify internal DNS: `docker exec prometheus wget -O- http://cadvisor:8080`

### Grafana datasource shows "red" (offline)
- Ensure Prometheus is running and healthy
- Check Grafana logs: `docker logs grafana`
- Verify Grafana provisioning: `docker exec grafana cat /etc/grafana/provisioning/datasources/prometheus.yml`

### High Prometheus disk usage
- Reduce retention period (default 30 days)
- Check metrics cardinality: high cardinality = more storage needed
- Monitor: `/volume2/docker/prometheus/data/` size

### cAdvisor high CPU usage
- This is normal for real-time metrics collection
- If excessive, reduce scrape interval in `prometheus.yml` (not recommended)
- Ensure container has adequate CPU shares

## Performance Optimization

### For Synology with limited resources:
1. Reduce Prometheus `scrape_interval` from 15s to 30s (less frequent updates)
2. Reduce `evaluation_interval` similarly
3. Limit metric retention: `--storage.tsdb.retention.time=14d`
4. Use sampling for very large deployments

Edit in `stacks/monitoring/docker-compose.yaml`:
```yaml
prometheus:
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.retention.time=14d'
```

Edit in `stacks/monitoring/prometheus.yml`:
```yaml
global:
  scrape_interval: 30s      # Reduce from 15s
  evaluation_interval: 30s  # Reduce from 15s
```

## Securing Your Monitoring Stack

✅ **Already Configured**:
- Grafana behind Traefik with Authentik authentication
- Prometheus behind Traefik with Authentik authentication
- `no-new-privileges` security option on all containers
- Containers running as non-root (`PUID:PGID`)

⚠️ **Optional Hardening**:
- Disable Prometheus web UI if not needed: `--web.enable-admin-api=false`
- Restrict Node Exporter collectors: Use `--collector.disable-defaults` to enable only specific ones
- Enable Prometheus authentication (requires reverse proxy configuration)

## Scaling and Advanced Configuration

### Adding Custom Metrics Exporters

To add more exporters (e.g., Redis exporter, MySQL exporter):
1. Add service to `stacks/monitoring/docker-compose.yaml`
2. Add scrape config to `stacks/monitoring/prometheus.yml`
3. Example for Redis (already in your stack):
   ```yaml
   - job_name: 'redis'
     static_configs:
       - targets: ['redis:6379']
   ```

### Exporting Metrics to External Systems

Prometheus supports remote storage writes:
```yaml
prometheus:
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.remote.write.url=http://external-tsdb:8086'  # InfluxDB, etc.
```

### High Availability Setup

For production, consider:
1. Run multiple Prometheus instances with different retention
2. Use Thanos for long-term storage
3. Set up alert manager for notification routing

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [cAdvisor Metrics](https://github.com/google/cadvisor/blob/master/docs/storage/prometheus.md)
- [Node Exporter Metrics](https://github.com/prometheus/node_exporter)
- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)
- [Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/)
