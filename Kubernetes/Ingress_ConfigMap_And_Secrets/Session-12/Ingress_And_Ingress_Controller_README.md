# Kubernetes Core Concepts: Ingress & Ingress Controller

This document provides a concise and detailed breakdown of **Ingress** and **Ingress Controllers** in Kubernetes, explaining their roles, key differences, why both components are necessary, and practical code examples.

---

## 1. What is Ingress?

An **Ingress** is an API object in Kubernetes that manages external HTTP and HTTPS access to services within a cluster.

* **Layer 7 Routing:** Unlike standard `ClusterIP` or `NodePort` services that route traffic based on network IP addresses and ports (Layer 4), Ingress operates at the **Application Layer (Layer 7)**.
* **Declarative Configuration:** It allows you to define routing rules, hostnames, SSL/TLS termination, path-based routing, and load balancing in a single manifest file.
* **Inactive on Its Own:** An Ingress resource is simply a **configuration specification** stored in the Kubernetes `etcd` database. By itself, it has no functionality and cannot route or manage network traffic.

---

## 2. What is an Ingress Controller?

An **Ingress Controller** is the actual software daemon running in the cluster that fulfills and implements the rules defined in `Ingress` resources.

* **Controller Loop:** It continuously monitors the Kubernetes API server for changes to `Ingress` resources and endpoints.
* **Reverse Proxy Engine:** When an `Ingress` resource is created or modified, the Ingress Controller automatically configures an underlying reverse proxy (such as NGINX, HAProxy, Envoy, or Traefik) to route incoming external traffic accordingly.
* **Entry Point:** It receives external connections to the cluster and forwards requests directly to the backend Pod IPs or Services.

---

## 3. Difference Between Ingress and Ingress Controller

| Feature / Aspect | Ingress | Ingress Controller |
| :--- | :--- | :--- |
| **What it is** | A Kubernetes API **Resource / Spec** | An actively running **Application / Daemon** |
| **Analogy** | The **Blueprint / Map** | The **Builder / Router** |
| **Function** | Declares *how* traffic should be routed | Executes and *enforces* the routing rules |
| **Storage** | Stored as YAML/JSON in `etcd` | Runs as Pods (Deployment/DaemonSet) |
| **Examples** | `kind: Ingress` YAML manifest | NGINX Ingress, Traefik, HAProxy, AWS ALB Controller |

---

## 4. Why Both Are Required

To manage Layer 7 external traffic in Kubernetes, **both** an Ingress resource and an Ingress Controller are necessary due to the separation of configuration and implementation:

1. **Decoupling Configuration from Infrastructure:**
   * Developers write `Ingress` manifests specifying business logic (e.g., `/api` goes to `api-service`).
   * Cluster administrators deploy and maintain the `Ingress Controller` (e.g., NGINX or AWS ALB Controller) suitable for their cloud or on-premise infrastructure.

2. **The Blueprint vs. Engine Relationship:**
   * Without an **Ingress resource**, the Ingress Controller runs but has no rules to follow—traffic will not reach services.
   * Without an **Ingress Controller**, the `Ingress` resource sits idle as unfulfilled metadata in the API server.

3. **Efficiency and Cost Optimization:**
   * Instead of exposing every individual service using separate cloud load balancers (`Type: LoadBalancer`), both components work together so a **single Ingress Controller IP/Load Balancer** can route traffic to dozens of internal services based on hostnames and paths.

---

## 5. Examples

### Architecture / Traffic Flow

```
External Client
       |
       v  (HTTP/HTTPS Request)
+-------------------------------------------------------+
| Ingress Controller (e.g., NGINX Load Balancer Pod)    |
| - Reads Ingress rules                                 |
| - Terminates TLS                                      |
+-------------------------------------------------------+
       |                                   |
       | path: /api                        | path: /web
       v                                   v
+------------------+                +------------------+
|  api-service     |                |  web-service     |
| (ClusterIP:8080) |                | (ClusterIP:80)   |
+------------------+                +------------------+
       |                                   |
       v                                   v
  [ API Pods ]                        [ Web Pods ]
```

---

### Ingress Manifest Example (`ingress.yaml`)

Below is an example of an `Ingress` resource defining host-based and path-based routing rules:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  namespace: default
  annotations:
    # Specifies which Ingress Controller should handle this resource
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx # Binds to the installed NGINX Ingress Controller
  tls:
  - hosts:
    - example.com
    secretName: example-com-tls # Secret containing SSL certificate and key
  rules:
  - host: example.com
    http:
      paths:
      # Route 1: Path-based routing for API traffic
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      # Route 2: Path-based routing for Web Frontend
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

---

### Summary Checklist for Assignment

* **Ingress:** API object specifying Layer 7 rules (hostnames, paths, SSL/TLS).
* **Ingress Controller:** Active deployment running a proxy (e.g., NGINX) that executes Ingress rules.
* **Separation of Concerns:** Ingress = policy definition; Ingress Controller = policy execution.
* **Primary Benefit:** Consolidates multiple services behind a single entry point / IP address.
