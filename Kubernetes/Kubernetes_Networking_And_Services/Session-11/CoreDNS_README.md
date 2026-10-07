# Kubernetes CoreDNS & Service Discovery Research

This document provides an in-depth analysis of CoreDNS, how service discovery works within Kubernetes, how DNS queries are resolved step-by-step, CoreDNS configuration (`Corefile`), and actionable steps for troubleshooting cluster DNS issues.

---

## 1. What is CoreDNS?

**CoreDNS** is a flexible, extensible DNS server written in Go that serves as the default cluster DNS server in Kubernetes (replacing `kube-dns` starting in Kubernetes v1.13).

* **CNCF Project:** CoreDNS is a Graduated project under the Cloud Native Computing Foundation (CNCF).
* **Plugin Architecture:** CoreDNS operates as a chain of plugins. Each request passes through a sequence of plugins (e.g., `kubernetes`, `forward`, `cache`, `errors`, `prometheus`) that inspect, modify, or answer the query.
* **Lightweight & Fast:** Designed for cloud-native architectures, offering high concurrency, modern protocol support, and low resource overhead. 

---

## 2. Why Kubernetes Uses CoreDNS

Kubernetes relies on CoreDNS as a core control plane component to solve critical infrastructure challenges in dynamic container environments:

1. **Eliminating Static IPs:** Pods are ephemeral and receive temporary, unpredictable IP addresses when created or rescheduled. CoreDNS enables applications to locate services using static logical names.
2. **Pluggable Architecture:** Custom capabilities (such as metrics exposure, rewrite rules, conditional forwarding, or custom host records) can be enabled simply by updating the CoreDNS configuration file (`Corefile`) without compiling code.
3. **Low Overhead & Scalability:** CoreDNS handles thousands of concurrent internal DNS lookups per second while maintaining a small memory footprint.
4. **Native Kubernetes API Integration:** Through its `kubernetes` plugin, CoreDNS watches the Kubernetes API for `Service` and `Endpoint` changes in real time, keeping DNS records instantly updated without requiring continuous polling.

---

## 3. How Service Discovery Works

Service discovery in Kubernetes links human-readable domain names to dynamic network locations.

```
+-----------------------------------------------------------------------+
|                            Kubernetes API                             |
+-----------------------------------------------------------------------+
        |                                                 |
        | Watch Service & Endpoint events                 | Watch Endpoints
        v                                                 v
+-------------------------------+               +-----------------------+
|            CoreDNS            |               |      kube-proxy       |
+-------------------------------+               +-----------------------+
        |                                                 |
        | Resolves Name to ClusterIP                      | Programs iptables/eBPF
        v                                                 v
  [ payment-svc ] -------------> [ 10.96.0.50 ] -------------> [ Pod IP 10.244.1.15 ]
```

### The Discovery Lifecycle:
1. **Service Creation:** A operator or deployment creates a Service (e.g., `payment-svc`) targeting set of Pods using label selectors.
2. **ClusterIP Allocation:** Kubernetes assigns a virtual IP called a **ClusterIP** to the Service (e.g., `10.96.0.50`).
3. **API Event Watch:** CoreDNS receives an event from the API server and automatically publishes an `A/AAAA` record mapping `payment-svc.default.svc.cluster.local` to `10.96.0.50`.
4. **Endpoint Tracking:** As target Pods start or terminate, the Kubernetes `EndpointSlice` controller updates the backend endpoints. While the Service FQDN still points to the same ClusterIP, `kube-proxy` (or CNI eBPF rules) updates packet routing rules to direct traffic to healthy target Pod IPs.

---

## 4. How DNS Queries Are Resolved (Step-by-Step)

When a client application inside a Pod performs a lookup (e.g., querying `auth-service` or `api.github.com`), the resolution process executes through distinct layers:

### Step 1: `/etc/resolv.conf` Injection
Every Pod created in a Kubernetes cluster is automatically provisioned with a `/etc/resolv.conf` file by `kubelet`:

```ini
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

* **`nameserver`:** Points directly to the CoreDNS Service IP (`kube-dns`).
* **`search`:** Defines namespaces to append sequentially when resolving short names.
* **`ndots:5`:** Any query containing fewer than 5 dots will first try appending the local domain search paths before attempting an absolute lookup.

### Step 2: Query Processing Flow

```
                                  +---------------------+
                                  | Client Pod Lookup   |
                                  +---------------------+
                                             |
                                     (Query: "db-svc")
                                             v
                                  +---------------------+
                                  | CoreDNS Server      |
                                  | (10.96.0.10:53)     |
                                  +---------------------+
                                             |
                     +-----------------------+-----------------------+
                     |                                               |
         [ Internal Cluster Request ]                    [ External Request ]
         e.g., "db-svc.default.svc.cluster.local"        e.g., "api.github.com"
                     |                                               |
                     v                                               v
         +-----------------------+                       +-----------------------+
         | 'kubernetes' Plugin   |                       | 'forward' Plugin      |
         | Checks API cache for  |                       | Forwards to host DNS  |
         | Service ClusterIP     |                       | (e.g., 8.8.8.8)       |
         +-----------------------+                       +-----------------------+
                     |                                               |
                     v                                               v
         Returns ClusterIP Address                       Returns Public IP Address
```

1. **Client Request:** The client queries for `db-svc`. Because it contains fewer than 5 dots (`ndots:5`), the client OS appends search paths: `db-svc.default.svc.cluster.local`.
2. **CoreDNS Evaluation:** The request hits CoreDNS on port 53.
3. **Plugin Execution Chain:**
   * **`cache`:** Checks if the answer is already cached in memory.
   * **`kubernetes`:** Checks if the domain ends with `.cluster.local`. If yes, CoreDNS resolves the name against its local API watch cache and returns the assigned ClusterIP.
   * **`forward`:** If the domain does not match `.cluster.local` (e.g., `google.com`), CoreDNS routes the request to upstream external resolvers configured on the host node (e.g., `/etc/resolv.conf` of the host or public resolvers like `8.8.8.8`).

---

## 5. CoreDNS Configuration (`Corefile`)

CoreDNS configuration is managed via a ConfigMap named `coredns` in the `kube-system` namespace. The main configuration block is written in a language called **Corefile**.

### Typical `Corefile` Structure

```text
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
```

### Core Plugins Explanation:

| Plugin | Purpose |
| :--- | :--- |
| **`errors`** | Logs standard errors to `stdout` for troubleshooting. |
| **`health`** | Exposes a health check endpoint at `http://localhost:8080/health`. |
| **`ready`** | Exposes a readiness probe endpoint at port 8181 to signal when all plugins are initialized. |
| **`kubernetes`** | Core plugin answering cluster domain queries (`cluster.local`). `pods insecure` allows resolving direct Pod IPs. |
| **`prometheus`** | Exposes CoreDNS performance metrics at `http://localhost:9153/metrics` for scraping. |
| **`forward`** | Forwards non-cluster queries to upstream DNS resolvers (defaults to host `/etc/resolv.conf`). |
| **`cache`** | Enables internal caching with a specified Time-To-Live (TTL in seconds). |
| **`loop`** | Detects simple DNS routing loops and halts the server process to avoid infinite recursion. |
| **`loadbalance`** | Randomizes the order of `A`/`AAAA` records in responses to distribute load. |

---

## 6. How to Troubleshoot DNS Issues

When Pods cannot resolve service names, follow this systematic diagnostic workflow:

### Step 1: Verify CoreDNS Pod Status
Ensure the CoreDNS Pods are running and healthy:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

* **Check:** Are pods in `Running` state? Are restart counts high?

### Step 2: Inspect CoreDNS Logs
Check for lookup failures, upstream timeouts, or crash loops:

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100
```

### Step 3: Test DNS Resolution with a Debug Pod
Spin up a temporary utility container (like `busybox` or `dnsutils`) to perform direct queries:

```bash
kubectl run dns-test --rm -i --tty --image=infoblox/dnstools -- bash
```

Inside the test Pod, execute the following diagnostic commands:

```bash
# 1. Test short name resolution
nslookup payment-svc

# 2. Test FQDN resolution
nslookup payment-svc.default.svc.cluster.local

# 3. Direct query to CoreDNS ClusterIP
dig @10.96.0.10 payment-svc.default.svc.cluster.local

# 4. Test external resolution
nslookup kubernetes.io
```

### Step 4: Validate Service & Endpoint Configurations
Verify that the target Service exists and has active backend Endpoints:

```bash
# Check if the Service exists and has a ClusterIP
kubectl get svc payment-svc

# Check if target Pods are correctly bound to the Service
kubectl get endpoints payment-svc
```
* *If Endpoints list is `<none>`, check that target Pod labels match the Service selector.*

### Step 5: Check Pod `/etc/resolv.conf`
Ensure the client Pod has correct DNS settings injected:

```bash
kubectl exec -it <pod-name> -- cat /etc/resolv.conf
```
* Validate that the `nameserver` matches the `kube-dns` Service IP (`kubectl get svc -n kube-system kube-dns`).

### Common DNS Issues & Root Causes

1. **`NXDOMAIN` Errors:**
   * **Cause:** Misspelled Service name, namespace mismatch, or missing endpoint selectors.
2. **DNS Query Timeouts:**
   * **Cause:** NetworkPolicy blocking UDP/TCP port 53 traffic between app Pods and CoreDNS.
3. **`ndots` Latency Degradation:**
   * **Cause:** `ndots:5` forces 4 unsuccessful lookups before reaching external domains (e.g., `example.com`). Fix by using trailing dots (`example.com.`) or tuning `ndots` in the Pod's `dnsConfig`.
