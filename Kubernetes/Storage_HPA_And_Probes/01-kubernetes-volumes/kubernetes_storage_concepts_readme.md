# Kubernetes Storage Concepts: Ephemeral & Persistent Volumes

This document provides a detailed breakdown of Kubernetes storage primitives and volume management strategies, covering ephemeral volumes (`emptyDir`, `hostPath`), persistent storage (`PV`, `PVC`), and automated dynamic provisioning via `StorageClass`.

---

## Table of Contents
1. [Ephemeral Volumes](#1-ephemeral-volumes)
   - [emptyDir](#emptydir)
   - [hostPath](#hostpath)
2. [Persistent Volumes & Claims](#2-persistent-volumes--claims)
   - [PersistentVolume (PV)](#persistentvolume-pv)
   - [PersistentVolumeClaim (PVC)](#persistentvolumeclaim-pvc)
3. [StorageClass & Dynamic Provisioning](#3-storageclass--dynamic-provisioning)
   - [StorageClass](#storageclass)
   - [Dynamic Provisioning](#dynamic-provisioning)
4. [Storage Abstraction Summary](#4-storage-abstraction-summary)

---

## 1. Ephemeral Volumes

Ephemeral volumes are tied directly to the lifecycle of a Pod or Node. They are used for temporary scratch spaces, caching, or node-level host mounting.

### emptyDir

#### Purpose & Lifecycle
An `emptyDir` volume is created when a Pod is assigned to a Node and exists as long as that Pod is running on that Node. When a Pod is removed from a Node (deleted or rescheduled), the data in the `emptyDir` is deleted permanently.

#### Key Use Cases
- Temporary scratch space (e.g., disk-based sorting algorithms).
- Caching data for web applications.
- Shared directory for multi-container Pods (e.g., sidecar container pattern).

#### Practical Example
Below is a multi-container Pod where a `writer` container writes logs into an `emptyDir` volume, and a `reader` sidecar container reads them.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-demo-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c", "echo 'Hello from Writer' > /cache/data.txt && sleep 3600"]
    volumeMounts:
    - name: cache-volume
      mountPath: /cache
  - name: reader
    image: busybox
    command: ["sh", "-c", "cat /cache/data.txt && sleep 3600"]
    volumeMounts:
    - name: cache-volume
      mountPath: /cache
  volumes:
  - name: cache-volume
    emptyDir: {} # Can optionally specify medium: Memory for RAM disk
```

---

### hostPath

#### Purpose & Lifecycle
A `hostPath` volume mounts a file or directory from the host node's filesystem directly into your Pod. Data persists as long as the underlying node exists, but it is tied to that specific physical or virtual machine.

#### Key Use Cases
- Running cluster-level agents (e.g., Fluentd, Prometheus node-exporter) that require access to host logs (`/var/log`).
- System-level Pods needing access to host Docker/container runtime sockets (`/var/run/docker.sock`).

#### Practical Example
Below is a Pod mounting the host node's system log directory at `/var/log`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-log-viewer
spec:
  containers:
  - name: log-reader
    image: busybox
    command: ["sh", "-c", "ls -la /host/logs && sleep 3600"]
    volumeMounts:
    - name: node-logs
      mountPath: /host/logs
      readOnly: true
  volumes:
  - name: node-logs
    hostPath:
      path: /var/log
      type: Directory
```

---

## 2. Persistent Volumes & Claims

Kubernetes decouples storage infrastructure management from application request logic using **PersistentVolumes** and **PersistentVolumeClaims**.

```
+------------------+         Claims         +------------------------+
|   Application    | ---------------------> | PersistentVolumeClaim  |
|      Pod         |  (Requests Storage)    |        (PVC)           |
+------------------+                        +------------------------+
                                                        |
                                                        | Binds To
                                                        v
+------------------+                        +------------------------+
| Actual Physical  | <--------------------- |    PersistentVolume    |
| Cloud/NFS Disk   |    Represents Storage  |        (PV)            |
+------------------+                        +------------------------+
```

### PersistentVolume (PV)

#### Purpose & Lifecycle
A `PersistentVolume` is a piece of storage in the cluster that has been provisioned by an administrator or dynamically provisioned using a StorageClass. It is an API resource representing physical storage (AWS EBS, GCP Persistent Disk, NFS, local disk, etc.).
- Independent of any individual Pod's lifecycle.

#### Key Attributes
- **Capacity:** The storage size (e.g., `10Gi`).
- **Access Modes:** 
  - `ReadWriteOnce` (RWO) - Mounted as read-write by a single node.
  - `ReadOnlyMany` (ROX) - Mounted as read-only by many nodes.
  - `ReadWriteMany` (RWX) - Mounted as read-write by many nodes.
- **Reclaim Policy:** `Retain` (manual cleanup), `Delete` (deletes storage asset), or `Recycle` (scrubs data).

#### Practical Example (Statically Provisioned PV)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-pv-example
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/mnt/data" # Static host mount example
```

---

### PersistentVolumeClaim (PVC)

#### Purpose & Lifecycle
A `PersistentVolumeClaim` is a request for storage by a developer or application. It specifies requirements such as size, access modes, and storage class.
- When a PVC is created, Kubernetes matches it to an available `PersistentVolume` and **binds** them together.
- Pods use the PVC as a volume mount point.

#### Practical Example
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

#### Mounting PVC inside a Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-db-pod
spec:
  containers:
  - name: database
    image: postgres:15
    env:
    - name: POSTGRES_PASSWORD
      value: "examplepass"
    volumeMounts:
    - name: db-data
      mountPath: /var/lib/postgresql/data
  volumes:
  - name: db-data
    persistentVolumeClaim:
      claimName: app-pvc-claim
```

---

## 3. StorageClass & Dynamic Provisioning

### StorageClass

#### Purpose
A `StorageClass` provides a way for administrators to describe the "classes" or "types" of storage they offer (e.g., SSD vs. HDD, high-performance vs. low-cost cloud disks). It defines which volume plugin (provisioner) should be used and passes configuration parameters to it.

---

### Dynamic Provisioning

#### Purpose & Workflow
Instead of cluster administrators manually pre-creating `PersistentVolumes` (static provisioning), **Dynamic Provisioning** automatically creates storage on-demand whenever a `PersistentVolumeClaim` is submitted.

1. User creates a `PersistentVolumeClaim` referencing a `StorageClass`.
2. The `StorageClass` invokes the specified provisioner (e.g., AWS EBS CSI, GCP PD CSI, Azure Disk).
3. The provisioner automatically allocates the disk in the underlying cloud/infrastructure.
4. Kubernetes automatically creates the matching `PersistentVolume` object and binds it to the user's `PVC`.

#### Practical Example: StorageClass & Dynamic PVC

##### 1. Define the StorageClass (`storage-class.yaml`)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs # Or driver like ebs.csi.aws.com
parameters:
  type: gp3
reclaimPolicy: Delete
allowVolumeExpansion: true
```

##### 2. Define the PVC referencing the StorageClass (`dynamic-pvc.yaml`)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-ssd-claim
spec:
  storageClassName: fast-ssd # Triggers dynamic creation via 'fast-ssd' StorageClass
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

---

## 4. Storage Abstraction Summary

| Storage Type | Life Cycle Scope | Data Persistence | Best Used For |
| :--- | :--- | :--- | :--- |
| **emptyDir** | Tied to Pod | Deleted when Pod dies | Caching, temporary scratch files, sidecar communication |
| **hostPath** | Tied to Node | Persists on Node filesystem | System agents, logging daemons needing Node access |
| **Static PV / PVC** | Cluster Level | Persistent across Pod recreations | Fixed legacy infrastructure, manual disk allocations |
| **StorageClass & Dynamic PVC** | Cluster Level | Persistent across Pod recreations | Automated cloud storage provisioning (Production databases, Stateful workloads) |
