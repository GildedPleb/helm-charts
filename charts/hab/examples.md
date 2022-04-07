# Examples

A standard single raspberry pi node, 1 host, 1 node:

```yml
nodeList:
  - name: livenet
    type: bitcoind
    storageAmt: 1000Gi
```

---

An ultra simple BCoin cluster with 5 nodes, and 1 - 5 hosts (though, if it's 1
host, it would need 7.5 tb of available space...):

```yml
nodeList:
  - name: livenet
    type: bcoin
    storageAmt: 1500Gi
    replicaCount: 5
```

---

A 3 host, 3 node cluster with 1 node each of Bitcoin Core, BCoin, and BTCD, all
networked together, and trying to reach a node in Chicago.

```yml
additionalPeers:
  - addressAndPort: "47.185.51.150:8333" # a random public node in Chicago
    group: cluster
nodeList:
  - name: livenet
    type: bitcoind
    storageAmt: 1000Gi
    group: cluster
  - name: livenet
    type: bcoin
    storageAmt: 1500Gi
    group: cluster
  - name: livenet
    type: btcd
    storageAmt: 3000Gi
    group: cluster
```

---

A cluster of 2 - 4 hosts, 3 nodes, with a failover host

```yml
nPlusOneHosts:
  - 'host4'
nodeList:
  - name: livenet
    type: bitcoind
    storageAmt: 1000Gi
    group: cluster
    replicaCount: 2
    participateInNPlusOne: true
  - name: livenet
    type: bcoin
    storageAmt: 1500Gi
    group: cluster
    participateInNPlusOne: true
```

---

A 4 host, 3 node cluster with very uneven storage distribution per host, where
only bitcoind and bcoin can participate in nPlusOne

```yml
nPlusOneHosts:
  - 'host4-mid-hd'
nodeList:
  - name: livenet
    type: bitcoind
    storageAmt: 600Gi
    group: cluster
    targetHosts: ["host1-small-hd"]
    participateInNPlusOne: true
  - name: livenet
    type: bcoin
    storageAmt: 1500Gi
    group: cluster
    targetHosts: ["host2-mid-hd"]
    participateInNPlusOne: true
  - name: livenet
    type: btcd
    storageAmt: 4000Gi
    group: cluster
    targetHosts: ["host3-large-hd"]
```

---

A 3 node, 1 - 3 host simnet cluster with rpc enabled, and mapped in envs. Will
require a kubernetes secret `simnet-rpc-secret`

```yml
nodeList:
  - name: simnet
    type: btcd
    storageAmt: 20Gi
    replicaCount: 3
    args:
      - "--rpcuser=$(SIMNET_RPC_USER)"
      - "--rpcpass=$(SIMNET_RPC_PASS)"
      - "--simnet"
      - "--miningaddr=sb1qjwgq9pa4df4qv2dqdlkaf6mvzhel7lus4yhl80"
    envs:
      - name: SIMNET_RPC_USER
        valueFrom:
          secretKeyRef:
            name: simnet-rpc-secret
            key: user
      - name: SIMNET_RPC_PASS
        valueFrom:
          secretKeyRef:
            name: simnet-rpc-secret
            key: pass
```

---

A 3 node, 3 host cluster with indexing, disabled wallet, zmq, rpc clients, and
also full re-indexing and re-validation on all reboots. Additionally, the nodes
are isolated to prevent them from being scheduled to the same host. Bitcoind is
able to pass in plaintext rpc auth because it is an encoded secret--still
probably not advisable though.

```yml
nodeList:
  - name: livenet
    type: bitcoind
    storageAmt: 1200Gi
    replicaCount: 3
    isolateNode: true
    args:
      - "-listen=1"
      - "-server=1"
      - "-txindex=1"
      - "-disablewallet"
      - "-maxconnections=40"
      - "-rest=1"
      - "-assumevalid=0"
      - "-reindex"
      - "-rpcbind=0.0.0.0"
      - "-rpcauth=rpcadmin:4228cacb482f444deb7bc0eb0131362b$fe7f1d00cb80892194940e78703e142002f726f91fb53d3bd067e8728e3f01ca"
      - "-zmqpubrawblock=tcp://0.0.0.0:28333"
      - "-zmqpubrawtx=tcp://0.0.0.0:28332"
    additionalServicePorts:
      - port: 28333
        targetPort: 28333
        protocol: TCP
        name: zmqblock
```

---

A 5 host, 3 node cluster with dedicated failover for bitcoind, and additional
failover for all nodes. (For the most part you wouldn't need to do this as two
bitcoind instances would be far more suitable. However, if the underlying
hardware on the bitcoind hosts is fragile and resource constrained in storage
terms, this may be effective.)

```yml
nPlusOneHosts:
  - 'host5-failover-all'
nodeList:
  - name: livenet
    type: bitcoind
    storageAmt: 1200Gi
    replicaCount: 1
    targetHosts: ["host1", "host2"]
    participateInNPlusOne: true
    group: cluster
    isolateNode: true
  - name: livenet
    type: bcoin
    storageAmt: 1500Gi
    group: cluster
    participateInNPlusOne: true
    isolateNode: true
  - name: livenet
    type: btcd
    storageAmt: 3000Gi
    group: cluster
    participateInNPlusOne: true
    isolateNode: true
```

---

A 3 host, 3 node livenet cluster, and a 3 node simnet cluster, on top of it.

```yml
nodeList:
  - name: livenet
    type: btcd
    storageAmt: 3000Gi
    group: live-cluster
    isolateNode: true
    replicaCount: 3
  - name: testnet
    type: btcd
    storageAmt: 10Gi
    group: test-cluster
    targetHosts: ["host1", "host2",  "host3"]
    replicaCount: 3
    args:
      - "--testnet"
```

---

A 5 node, 1 - 5 host, simnet cluster with full tls ingress and loadbalancer
(will need the certificate `bitcoin-tls` and ClusterIssuer `selfsigned-issuer`
for this to work, and may also require rpc cert management -- but really, I just
don't have time to test this)

```yml
  - enabled: true
    name: simnet
    type: btcd
    storageAmt: 10Gi
    replicaCount: 5
    args:
      - "--rpcuser=user"
      - "--rpcpass=$(SIMNET_RPC_PASS)"
      - "--simnet"
      - "--rpclisten=127.0.0.1:18556"
      - "--miningaddr=sb1qjwgq9pa4df4qv2dqdlkaf6mvzhel7lus4yhl80"
    envs:
      - name: SIMNET_RPC_PASS
        value: cleartextSimnetPass
    additionalServicePorts:
      - port: 18556
        targetPort: 18556
        protocol: TCP
        name: simnetrpc
    externalAccess:
      enabled: true
      ingress:
        className: ""
        annotations:
          kubernetes.io/ingress.class: "nginx"
          cert-manager.io/cluster-issuer: "selfsigned-issuer"
        hosts:
          - host: btc.gilded.lan
            paths:
              - path: /
                pathType: Prefix
                portNumber: 8333
              - path: /rpc
                pathType: Prefix
                portNumber: 18556
        tls:
          - secretName: bitcoin-tls
            hosts:
              - btc.gilded.lan
```

---

An "even race" cluster: 3 identical hosts, 3 nodes with 1 node each of Bitcoin
Core, BCoin, and BTCD, where bcoin and btcd are networked together, and bitcoind
is isolated, and has to index everything. Because why not?

```yml
nodeList:
  - name: livenet
    type: bitcoind
    storageAmt: 3000Gi
    isolateNode: true
    args:
      - "-txindex=1"
  - name: livenet
    type: bcoin
    storageAmt: 3000Gi
    group: cluster
    isolateNode: true
  - name: livenet
    type: btcd
    storageAmt: 3000Gi
    group: cluster
    isolateNode: true
```

---

2 nearly identical bitcoind nodes, on 2 hosts, that are not networked. This is
essentially the same as adding `replicaCount: 2` to the first node, and deleting
the second, with one important difference: because these nodes are in different
peer groups, they will not talk to eachother (unless they talk to a remote peer
who shares their neighbors address). This is how to isolate peers from what
would normally be the same statefulset newtworking defaults. Also note that the
names need to change to pass validation.

```yml
nodeList:
  - name: livenet1
    type: bitcoind
    storageAmt: 3000Gi
    group: cluster1
  - name: livenet2
    type: bitcoind
    storageAmt: 3000Gi
    group: cluster2
```

--- 

HAB node design for a 7 node cluster with prod and dev capabilities

| Host |  Space      | Name                                   | Group      | Test Simnet    |
| ---- | ----------- | -------------------------------------- | ---------- | -------------- |
| nuc1 |  2tb + 4tb  | btcd full node and ctl     - fn, ctl   | prod, prod |                |
| nuc2 |  2tb        | available for test         -           |            | btcd simnet1   |
| pi1  |  2tb        | bitcoind1 Main HA Cluster  - ha        | prod       | btcd simnet2   |
| pi2  |  2tb        | bitcoind2 Main HA Cluster  - ha        | prod       | btcd simnet3   |
| pi3  |  2tb        | bitcoind3 Main HA Cluster  - ha        | prod       | btcd simnet4   |
| pi4  |  2tb        | bcoin1                     - fn        | prod       | btcd simnet5   |
| pi5  |  2tb        | n+1 node                   -           |            |                |

```yml
nPlusOneHosts:
  - "pi5"

nodeList:
  - enabled: true
    name: ctl
    group: prod
    type: bitcoind
    targetHosts: [nuc2]
    isolateNode: true
    replicaCount: 1
    storageAmt: 1700Gi
    participateInNPlusOne: true
    participateInBackups: true
    args:
      - "-listen=1"
      - "-server=1"
      - "-disablewallet"
      - "-dbcache=30000"
      - "-maxconnections=40"
      - "-maxuploadtarget=5000"
      - "-assumevalid=0"
      - "-reindex"
    readinessCMD: "tail -n 500 /data/debug.log | grep 'UpdateTip: new best=' | tail -3 | grep progress=1.0"
  - enabled: true
    name: ref
    group: prod
    type: bitcoind
    targetHosts: [nuc1]
    isolateNode: true
    replicaCount: 1
    storageAmt: 1700Gi
    participateInNPlusOne: true
    participateInBackups: true
    args:
      - "-listen=1"
      - "-server=1"
      - "-disablewallet"
      - "-dbcache=30000"
      - "-maxconnections=40"
      - "-maxuploadtarget=5000"
      - "-assumevalid=0"
      - "-reindex"
    readinessCMD: "tail -n 500 /data/debug.log | grep 'UpdateTip: new best=' | tail -3 | grep progress=1.0"
  - enabled: true
    name: test
    group: prod
    type: btcd
    targetHosts: [nuc1]
    isolateNode: false
    replicaCount: 1
    storageAmt: 4000Gi
    participateInNPlusOne: false
    participateInBackups: false
    externalAccess:
      enabled: false
    readinessCMD:
      'tail -n 100 /root/.btcd/logs/mainnet/btcd.log | grep ''SYNC: Processed'' |
      tail -n 1 | awk ''{print $1"T"$2"."$16"T"$17}'' | awk -F. ''{ c="date -jf
      %FT%T " $1 " +%s"; c | getline t1; close(c); m="date -jf %FT%T " $3 " +%s";
      m | getline t2;close(m); if( (t1 - t2) > 60) exit 1 }'''
    resources:
      limits:
        cpu: 1000m
        memory: 1000Mi
      requests:
        cpu: 1000m
        memory: 1000Mi
  - enabled: true
    name: test
    group: prod
    type: bcoin
    targetHosts: [pi1]
    isolateNode: true
    replicaCount: 1
    storageAmt: 1700Gi
    participateInNPlusOne: true
    participateInBackups: false
    args:
      - "--cache-size=4096"
    readinessCMD: "tail -n 1000 /.bcoin/debug.log | grep progress=100"
  - enabled: true
    name: ha
    group: prod
    type: bitcoind
    isolateNode: true
    replicaCount: 3
    targetHosts: [pi2, pi3, pi4]
    storageAmt: 1700Gi
    args:
      - "-listen=1"
      - "-server=1"
      - "-txindex=1"
      - "-disablewallet"
      - "-dbcache=4000"
      - "-maxconnections=40"
      - "-maxuploadtarget=5000"
      - "-rest=1"
      - "-rpcbind=0.0.0.0"
      - "-rpcallowip=10.0.0.0/8"
      - "-rpcauth=rpcadmin:4228cacb482f444deb7bc0eb0131362b$fe7f1d00cb80892194940e78703e142002f726f91fb53d3bd067e8728e3f01ca"
      - "-zmqpubrawblock=tcp://0.0.0.0:28333"
      - "-zmqpubrawtx=tcp://0.0.0.0:28332"
    readinessCMD: "tail -n 500 /data/debug.log | grep 'UpdateTip: new best=' | tail -3 | grep progress=1.0"
  - enabled: false
    name: simnet
    type: btcd
    storageAmt: 10Gi
    replicaCount: 5
    args:
      - "--rpcuser=user"
      - "--rpcpass=$(SIMNET_RPC_PASS)"
      - "--maxpeers=40"
      - "--simnet"
      - "--rpclisten=127.0.0.1:18556"
      - "--miningaddr=sb1qjwgq9pa4df4qv2dqdlkaf6mvzhel7lus4yhl80"
    targetHosts: [nuc2, pi1, pi2, pi3, pi4]
    envs:
      - name: SIMNET_RPC_PASS
        value: superSecretPass!
    additionalServicePorts:
      - port: 18556
        targetPort: 18556
        protocol: TCP
        name: simnetrpc
    externalAccess:
      enabled: true
      ingress:
        className: ""
        annotations:
          kubernetes.io/ingress.class: "nginx"
          cert-manager.io/cluster-issuer: "selfsigned-issuer"
        hosts:
          - host: btc.gilded.lan
            paths:
              - path: /
                pathType: Prefix
                portNumber: 8333
        tls:
          - secretName: bitcoin-tls
            hosts:
              - btc.gilded.lan
```

## Aren't some of these not actually Highly Available?

Yes. For this repo, we are assuming a varied definition of High Availability (HA).
Broadly speaking, HA usually refers to software architecture that continues to
function regardless of certain, tollerable, degradations. As it would apply
here, it would traditionally mean a replicated Bitcoind node statefulset, one
replica on each host, with N+1 tolerances, public exposure via a load balancer
and ingress, and each node mapping this publicly reachable address to the
network. Such that, any remote peer contact to our HA node will be unable to
discern service degradation in the event of local host failures as we, locally,
simply route around the failed host.

This is an excellent pattern, but we are not sure if that is the best/only way
to play this wholistically speaking. For instance, a load balancer may disrupt
the way that bitcoin handles in-transit peer-to-peer messaging accross
nodes/hosts--I could be wrong here, it bares putting more research into this
project and this v1 is excellent groundwork to that end. But more broadly
speaking, even if we achieve fully robust traditional HA, I think that it only
amounts to a tactic in the larger strategy of robust node operation; a tactic
along side running multiple implementations of the same bitcoin protocol,
running on a diversity or power sources, using a diversity of internet
providers, using a variety of host computers, ect.

As such, some of the examples above are indeed not HA on traditional metrics in
the slightest. However, they remain highly available on different metrics. For
instance, any node which runs multiple implementations of the bitcoin protocol
on multiple hardware architectures from multiple supply chains, dramatically
reduces external threats (be they unlikely) of compromised code or components
which may result in downtime or worse, or internal threats like zero-days which
may affect one dependency in one repo, but not others.

If the above traditional HA ideals are not reachable in this version, it is
already on the road map to make some kind of k8s controller that can map traffic
to nodes without worry about their underlying implementation language, logic, or
idiosyncrasies. Though the bitcoin protocol is universal accross all
implementations, running and interacting with any individual node is far from
unified.
