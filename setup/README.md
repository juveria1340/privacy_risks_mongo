# Setup Scripts

Run these IN ORDER on CloudLab nodes.

## Step by Step

### Step 1 — Run on ALL 4 nodes (simultaneously)
```bash
git clone <your-repo>
cd privacy_risks_mongo
bash setup/1_install_kubernetes.sh
```

### Step 2 — Run on node-0 ONLY
```bash
bash setup/2_init_cluster.sh
```
Copy the join command printed at the end.

### Step 3 — Run on node-1, node-2, node-3
Paste the join command from Step 2.

### Step 4 — Run on node-0 ONLY
```bash
bash setup/3_generate_certs.sh
bash setup/4_deploy_dissertation.sh
```

## Time Estimate
| Script | Time |
|--------|------|
| 1_install_kubernetes.sh | ~5 mins |
| 2_init_cluster.sh | ~5 mins |
| 3_generate_certs.sh | ~1 min |
| 4_deploy_dissertation.sh | ~10 mins |
| **Total** | **~20 mins** |
