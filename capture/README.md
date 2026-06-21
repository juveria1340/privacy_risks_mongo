# Traffic Capture

## Run on node-3 (capture-node)

```bash
bash capture/capture_traffic.sh
```

## What it captures
- All TLS traffic on port 27017 (MongoDB)
- Saves to /tmp/captures/capture_TIMESTAMP.pcap

## Copy pcap files to your laptop
```powershell
scp -i C:\Users\juver\.ssh\id_ed25519 `
  Juveria@node-3.cloudlab.us:/tmp/captures/*.pcap `
  C:\Users\juver\Desktop\privacy_risks_mongo\data\
```
