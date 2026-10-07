# Kubernetes DNS & FQDN Assignment

This document provides a breakdown of Fully Qualified Domain Names (FQDN) in Kubernetes, explaining how internal DNS resolution, namespace isolation, and Pod-to-Service communication function.

---

## 1. What is an FQDN?

A **Fully Qualified Domain Name (FQDN)** is the complete, unambiguous domain name for a specific host on the internet or a private network. It specifies all domain levels, including the hostname and the top-level domain (TLD).

* **Structure:** `[hostname].[domain].[tld].`
* **Example (Public Web):** `www.example.com.`
* **Key Characteristic:** Unlike a relative hostname (e.g., `web-service`), an FQDN is absolute and resolves uniquely from anywhere within the network routing domain.

---

## 2. Kubernetes Service DNS

Kubernetes runs an internal cluster DNS service (typically **CoreDNS**) as a cluster add-on.

* **Automatic Service Registration:** Whenever a Kubernetes `Service` is created, CoreDNS automatically creates a set of DNS records corresponding to that service.
* **Service Discovery:** Instead of hardcoding transient Pod IP addresses, applications query the internal DNS using logical Service names.
* **Cluster Domain:** By default, Kubernetes clusters use `.cluster.local` as their local top-level domain suffix.

---

## 3. Kubernetes DNS Naming Convention

Standard Kubernetes Services follow a strict hierarchical DNS naming syntax:

$$\text{<service-name>}.\text{<namespace>}.\text{svc}.\text{cluster.local}$$

### Component Breakdown:

1. **`<service-name>`:** The metadata name assigned to the Kubernetes Service object.
2. **`<namespace>`:** The Kubernetes namespace in which the Service resides.
3. **`svc`:** The domain label indicating that this record represents a Kubernetes **Service** (as opposed to `pod` for Pod IPs).
4. **`cluster.local`:** The default base domain name for the Kubernetes cluster internal network.

---

## 4. Namespace-Based DNS Resolution

Kubernetes configures each container's `/etc/resolv.conf` with a search list matching its own namespace. This allows different levels of DNS resolution depending on where the request originates:

### Same Namespace Communication
If `pod-a` and `service-x` are in the **same namespace** (`default`), `pod-a` can resolve the service using just the short name:
* **Query:** `service-x`
* **Resolves to:** `service-x.default.svc.cluster.local`

### Cross-Namespace Communication
If `pod-a` (in `frontend` namespace) needs to reach `service-y` in the **`backend` namespace**, it must supply at least the namespace qualifier:
* **Query:** `service-y.backend`
* **Resolves to:** `service-y.backend.svc.cluster.local`

---

## 5. Pod-to-Service Communication Flow

When a application in a Pod makes a request to a Service, the following step-by-step process occurs:

```
[ Pod A ] 
   | 
   | 1. DNS Lookup ("payment-svc")
   v
[ CoreDNS ] 
   | 
   | 2. Resolves FQDN to ClusterIP (e.g., 10.96.0.50)
   v
[ Pod A Network Stack ] 
   | 
   | 3. Packet sent to ClusterIP (10.96.0.50:8080)
   v
[ kube-proxy / iptables ] 
   | 
   | 4. Load balances & rewrites destination IP to Target Pod IP
   v
[ Target Pod B ] (10.244.1.15:8080)
```

1. **DNS Query:** The client application in Pod A sends a DNS lookup request for `payment-svc`.
2. **CoreDNS Resolution:** CoreDNS resolves `payment-svc` to its assigned virtual IP (**ClusterIP**).
3. **Traffic Transmission:** Pod A sends IP packets directed to the ClusterIP.
4. **Packet Routing & Load Balancing:** `kube-proxy` (or a CNI like Cilium/Calico) uses `iptables`/`eBPF` rules to intercept the ClusterIP traffic and route it to one of the healthy backend Pods matching the Service's selector.

---

## 6. Real-World Examples of Kubernetes FQDNs

### Example 1: Standard ClusterIP Service
* **Service Name:** `auth-api`
* **Namespace:** `production`
* **FQDN:** `auth-api.production.svc.cluster.local`

### Example 2: Database Service in a Custom Namespace
* **Service Name:** `postgres-db`
* **Namespace:** `database`
* **FQDN:** `postgres-db.database.svc.cluster.local`

### Example 3: Individual Pod in a StatefulSet (Headless Service)
StatefulSets require Headless Services (`clusterIP: None`) where individual Pods receive distinct, predictable DNS hostnames.
* **Pod Name:** `redis-0`
* **Headless Service Name:** `redis-cluster`
* **Namespace:** `cache`
* **FQDN:** `redis-0.redis-cluster.cache.svc.cluster.local`

### Example 4: Pod IP-based FQDN
Direct Pod IPs can also be resolved via DNS by converting the IP address (e.g., `10-244-1-45`) into a hyphenated string:
* **Pod IP:** `10.244.1.45`
* **Namespace:** `default`
* **FQDN:** `10-244-1-45.default.pod.cluster.local`
