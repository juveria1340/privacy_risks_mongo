# Traffic Capture

## Overview
Traffic is captured on node-1 (mongo-node) using tcpdump
on the cni0 interface which carries all inter-pod Kubernetes
traffic destined for the MongoDB pod on port 27017.

## Why cni0?
During initial testing, tcpdump on eno1 (external interface)
captured nothing. Investigation showed that Kubernetes pod
traffic flows through the cni0 bridge interface on the
node where the destination pod runs (node-1/mongo-node).
The cni0 interface at 10.244.1.1/24 bridges all local
pod network traffic including MongoDB connections from
app pods on node-2.

## Network Interfaces on node-1
| Interface  | IP            | Purpose                    |
|------------|---------------|----------------------------|
| eno1       | 128.105.x.x   | External/management network|
| enp94s0f0  | 10.10.1.2     | Internal cluster network   |
| flannel.1  | 10.244.1.0    | Flannel overlay network    |
| cni0       | 10.244.1.1    | Pod bridge (USE THIS)      |

## Traffic Flow
product-browse pod (10.244.2.7, node-2)

|

| TLS encrypted MongoDB query

v

flannel.1 (overlay network)

|

v

cni0 (10.244.1.1, node-1)  <-- tcpdump here

|

v

MongoDB pod (10.244.1.2, node-1, port 27017)

## Capture Methods

### Method 1 — Automated Per-Service (Recommended)

**On node-1:**
```bash
bash capture/capture_per_service.sh 100
```

**On node-0 (simultaneously):**
```bash
bash capture/generate_traffic.sh 100
```

### Method 2 — Manual Single Capture

**On node-1:**
```bash
sudo tcpdump -i cni0 port 27017 \
  -w /tmp/captures/capture.pcap -q
```

**On node-0:**
```bash
bash capture/generate_traffic.sh 100
```

## Output Files

## Copy to Laptop
```powershell
scp -i C:\Users\juver\.ssh\id_ed25519 `
  Juveria@node-1.cloudlab.us:/tmp/captures/*.pcap `
  C:\Users\juver\Desktop\privacy_risks_mongo\data\raw\
```

## Justification
- Captured per service for clean ground truth labels
- 100 requests per service for baseline validation
- 1000+ requests recommended for dissertation results
- cni0 interface captures all pod-to-pod MongoDB traffic
- TLS ensures payload is encrypted (only metadata visible)
