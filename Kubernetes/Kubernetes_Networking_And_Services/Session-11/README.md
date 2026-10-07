# Kubernetes Core Concepts: Workloads & Networking

This document provides a clear breakdown and comparison of fundamental Kubernetes workload controllers and networking objects.

## 1. Deployment vs ReplicaSet

### Purpose

* **ReplicaSet:** Ensures a specified number of identical Pod replicas are running at any given time.

* **Deployment:** A higher-level declarative abstraction built on top of ReplicaSets. It manages application lifecycle operations like automated updates, rollbacks, and versioning.

### Pod Management

* **ReplicaSet:** Manages Pods directly using key-value labels and selectors (`matchLabels`).

* **Deployment:** Manages Pods indirectly by managing underlying ReplicaSets.

### Scaling

* **ReplicaSet:** Supports manual scaling (adjusting `replicas` field) and autoscaling (via Horizontal Pod Autoscaler).

* **Deployment:** Delegates scaling to the active ReplicaSet while maintaining deployment state and revision history.

### Rolling Updates & Rollbacks

* **ReplicaSet:** Does **not** natively support rolling updates or rollbacks. Updating a ReplicaSet's template leaves running Pods untouched until manually deleted.

* **Deployment:** Fully supports native zero-downtime rolling updates (`RollingUpdate` strategy), revision history tracking, and one-command rollbacks (`kubectl rollout undo`).

### Relationship between Deployment and ReplicaSet

A **Deployment** creates and owns **ReplicaSets**. When you update a Deployment's Pod template, it creates a new ReplicaSet and scales it up while scaling down the old ReplicaSet.

```
[ Deployment ] ---> manages ---> [ ReplicaSet (v2) ] ---> creates ---> [ Pods ]
                                 [ ReplicaSet (v1) ] (scaled down)

```

## 2. Deployment vs DaemonSet vs StatefulSet

| **Feature** | **Deployment** | **DaemonSet** | **StatefulSet** | 
| **Primary Use Cases** | Stateless web applications, microservices, APIs. | Cluster-wide background utilities (monitoring agents, log collectors, network plugins). | Stateful applications needing stable identities or persistent storage (databases, message queues). | 
| **Pod Creation** | Creates identical, interchangeable Pods with randomized names (e.g., `web-78d4c7987d-abcde`). | Ensures **exactly one** Pod runs on every eligible node across the cluster. | Creates Pods sequentially with persistent, ordinal indices (e.g., `db-0`, `db-1`, `db-2`). | 
| **Scaling** | Scaled manually or dynamically via replica count adjustments. | Scales automatically as nodes are added or removed from the cluster. | Scaled sequentially (up or down) maintaining ordinal order and identity. | 
| **Networking** | Pod IP addresses are ephemeral and interchangeable. | Uses standard node/pod networking; often binds to node network interface. | Requires a Headless Service to provide stable, unique DNS records for every individual Pod. | 
| **Storage** | Typically stateless or uses shared ephemeral storage. | Uses host-level paths (`hostPath`) to access node storage/logs directly. | Uses `volumeClaimTemplates` to automatically bind unique, persistent volumes to each Pod index. | 
| **Real-World Examples** | NGINX, Node.js API, Spring Boot Microservices. | Fluentd, Prometheus Node Exporter, Calico CNI. | PostgreSQL Cluster, MongoDB ReplicaSet, Apache Kafka. | 

## 3. ReplicaSet vs Service

### ReplicaSet Responsibility

* **Compute & Availability:** Guarantees that the desired number of Pod instances are running and healthy across nodes.

* **Focus:** Internal Pod lifecycle and replica count management.

### Service Responsibility

* **Networking & Discovery:** Provides a stable IP address, DNS name, and load balancer across a dynamic set of Pods.

* **Focus:** Internal and external network routing.

### Why a Service is Required

Pods in Kubernetes are ephemeral—they can crash, scale, or move between nodes, changing their IP addresses unpredictably. A **Service** acts as an abstraction layer providing a single, permanent endpoint (IP/DNS) so client applications do not need to keep track of dynamic Pod IPs.

### How Traffic Reaches Pods

1. **Selector Matching:** The Service uses a `selector` to discover matching Pod labels maintained by the ReplicaSet.

2. **Endpoint Creation:** Kubernetes continuously updates an **Endpoints** (or `EndpointSlice`) object listing all healthy Pod IPs matching the selector.

3. **Kube-Proxy Routing:** `kube-proxy` on each node configures routing rules (via `iptables` or `IPVS`).

4. **Load Balancing:** Traffic sent to the Service's stable ClusterIP is automatically load-balanced across the target active Pod IPs.

```
Client Traffic ---> [ Service (Stable IP) ] 
                          |
             +------------+------------+
             |                         |
     [ Pod 1 (IP A) ]          [ Pod 2 (IP B) ]
      (Managed by RS)           (Managed by RS)

```