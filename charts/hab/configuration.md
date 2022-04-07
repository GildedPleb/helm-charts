# Configuration

This is the configuration context, values, and justification for a HAB node.

## Context

### Node Types

Presently, there are three node types in [`node-types.yml`](node-types.yml). For
the sake of greedy development, you can not use `values.hab.yaml` to add new
types, and must either directly edit `node-types.yml` or submit a RP with a new
node type definition--please review our
[contributing documentation](./contributing.md) and submit a PR!

#### Node Type Specification

The general format is intended to be limited to values that are constant accross
all node implamentations of the same type, as such:

```yml
                                           # Req?  | Type            | Default        | Notes
                                           # ----- | --------------- | -------------- | --------------------------------------
bitcoind:                                  # Yes   | Key             |                | Repository, cmd, or project name used as reference in the `type` key below.
  repository: "ruimarinho/bitcoin-core"    # Yes   | String / url    |                | Image name MUST be multi-arch image
  pullPolicy: "IfNotPresent"               # No    | String          | IfNotPresent   |
  tag: ""                                  # Maybe | String          |                | If the Bitcoin repo to use with this node type does not follow the Bitcoin Core semver, then tag will need to be defined
  pullSecrets: []                          # No    | List            | nil            |
  command: []                              # No    | List of Strings | nil            | Entry command to run on startup, if the image does not provide one or it needs revising
  env:                                     # No    | Dict            | nil            |
    - name: BITCOIN_DATA                   # No    | String          | nil            |
      value: &data "/data/"                # No    | String          | nil            |
  mount:                                   # Yes   | Dict            |                | Mount point path mapped against the command line option for setting the data directory to use
    path: *data                            # Yes   | String / path   |                |
    setParam: "-datadir="                  # Yes   | String          |                | Must match valid commandline arg for this type of node
  peers:                                   # Yes   | Dict            |                | The way the implementations allows you to add peers
    multiArg: true                         # Yes   | Bool            |                | With or without repeating the same argument or prodiving a list of peers to one argument
    addParam: "-addnode="                  # Yes   | String          |                | Must match valid commandline arg for this type of node
  ports:                                   # Yes   | String          |                | The Bitcoin port
    p2pParam: "-port="                     # Yes   | String          |                | Must match valid commandline arg for this type of node
    p2pPort: "8333"                        # Yes   | String          |                | The Bitcoin port (unless it needs changing)
    ...
```

## Values

### Failover Hosts

```yml
nPlusOneHosts:
  - 'pi5'
  - 'nuc2'
  ...
```

`nPlusOneHosts` is a list of hosts (`kubernetes.io/hostname`) which are to be
reserved for scheduling in the event that regular or primary hosts (n) fail. If
set, the scheduler will not schedule pods to these hosts unless, and only
unless, the primary hosts fail for those pods, and they have no other "targeted"
hosts that are available to them. To not define `nPlusOneHosts`, comment it out.

### Additional Peers

```yml
additionalPeers:
  - addressAndPort: '8.8.8.8:8333'
    group: 'prod'
  ...
```

`additionalPeers` allows you to add external peers to peer groups to ensure that
all the nodes in that group attempt to connect to that peer. To not define
`additionalPeers`, comment it out.

### NodeList Values

`nodeList` is a list of all the nodes that you would like to run, as determined
in your `values.yaml`. If you have the resources for it, it is broadly
expandable, simply add a new node set to the list. For naming, the combination
of `type` and `name` of each node, in a `{type}-{name}` string must be
universally unique. e.g.:

VALID:

```yml
nodeList:
  - type: bitcoind
    name: test
    ...
  - type: btcd
    name: test
    ...
```

VALID:

```yml
nodeList:
  - type: btcd
    name: test1
    ...
  - type: btcd
    name: test2
    ...
```

INVALID:

```yml
nodeList:
  - type: btcd
    name: test
    ...
  - type: btcd
    name: test
    ...
```

#### Specification

Each node in the nodeList expects this structure:

```yml
                                           # Req?  | Type            | Default        | Notes
nodeList:                                  # ----- | --------------- | -------------- | --------------------------------------
  - enabled: true                          # No    | Bool            | True           |
    name: "simnet"                         # Yes   | String          |                | {type}-{name} must be universally unique
    group: "test"                          # No    | String          | "{name}-group" | A group to open peer connections with in the HAB node
    type: "btcd"                           # Yes   | String          |                | Must be from the list of node types in node-types.yml
    replicas: 1                            # No    | Number          | 1              | The number of nodes which meet this node definition (statefulset replicas)
    targetHosts: ["nuc1"]                  # No    | List of Strings | nil            | In the case that we want to match bitcoin nodes to kubernetes hosts, matching `kubernetes.io/hostname`
    isolateNode: false                     # No    | Bool            | True           | If True, no other node, of any group, that is also isolateNode: True, will be scheduled to the same host.
    participateInNPlusOne: false           # No    | Bool            | False          | Whether or not this set can utilize the nPlusOne host(s) if a host in this set is under duress or dead.
    participateInBackups: false            # No    | Bool            | False          | See note below on Backing up
    storageAmt: "30Gi"                     # Yes   | String          |                |
    args:                                  # No    | List of Strings | nil            | All args to pass to the bitcoin node running on the pod. Bad args can prevent pods from starting. Any command line node arguments native to the bitcoin node instance can be passed in the additional arguments section, provided they are formatted correctly
      - "--txindex"
      - "--rpcuser=$(SIMNET_RPC_USER)"     # NOTE: To pass a secret to a command line arg, set an ENV (below) and either add a secret cleartext, or reference it in a k8s secret, which is added before installing the chart.
      - "--rpcpass=$(SIMNET_RPC_PASS)"
      - "--simnet"
      - "--miningaddr=sb1q..."
    additionalServicePorts:                # No    | List of Dicts   | nil            | Define any additional services/ports that you would like to expose
      - port: 28333                        # No    | Number          | nil            |
        targetPort: 28333                  # No    | Number          | nil            |
        protocol: TCP                      # No    | Type            | nil            |
        name: zmqblock                     # No    | String          | nil            | Must be unique
    envs:                                  # No    | List of Dicts   | nil            | Define any additional envs, either directly or as references to k8s secrets
      - name: SIMNET_RPC_USER
        valueFrom:
          secretKeyRef:
            name: simnet-rpc-secret
            key: user
      - name: SIMNET_RPC_PASS
        value: password
    readinessCMD: "btcclt"                 # No    | String          | nil            | See note on readiness below
    externalAccess:                        # No    | Dict            | nil            | Whether or not we can access this node from outside the cluster
      enabled: true                        #                                          | The mapping here is the standard mapping for, generally speaking, any standard ingress, more docs here for the recommended nginx ingress : https://kubernetes.github.io/ingress-nginx/
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
    resources:                             # No    | Dict            | nil            | This increases chances charts run on environments with little resources, such as raspberry pis. More docs here: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 100m
        memory: 128Mi
    ...
```

#### The rest..

The rest of `values.yml` is boilerplate Helm templateing.

## HAB Node Configuration Notes and Justification

### Deployment Type

Each `nodeList` node is deployed as a kubernetes
[StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/).
Generally speaking, this is more desirable than a standard deployments type,
after all, Bitcoin is a stateful application. What is more, it may be required
as some clients if deployed as Deployments, will lock the database while in use,
preventing multiple pods from accessing the same volume without onerous
development overhead.

StatefulSets have some other advantages and drawbacks as well:

**PRO**:

-   Replication is dramatically simplified via storage classes
-   Volumes are not ephemeral
-   Each bitcoin node has its own private and verified copy of the blockchain

**CON**:

-   Scaling compute resources are dramatically constrained
-   Node identity (such as rpc tls certs and the like) are not unified accross
    resources without intervention
-   (Unless there is some serious coding wizardry) nodes who we wish to connect
    with all other nodes in their group must also connect to themselves, causing
    a lot of log pollution.

### Storage Class

For each node set, we define a new storage class to allow for varying
definitions around backups. However, seeing as how this is the only real
tangible benefit to using Longhorn with this chart (for the time being) we may
move forward by making longhorn optional in a future release.

#### Backups

`participateInBackups: true/false` determines whether or not we should back up
the nodes volumes to NFS/S3. This presently requires Longhorn and a working
NSF/S3 bucket set up in Longhorn. If `participateInBackups: True`, we don't
restore volumes from backups automatically because its computationally
impractical; it might take 20 min, 2 hours, 10 hours, or 2 days for the chart to
deploy as it waits for resources to download from accross the internet or local
network--where it would usually take a few seconds, depending on hab node
resources. To restore from backup, consult
[Longhorn documentation](https://longhorn.io/docs/1.2.4/snapshots-and-backups/).

### Pod Management Policy

We define a `podManagementPolicy: "Parallel"` along with
`publishNotReadyAddresses: true` and we then check to make sure that all pods
have addresses in an initContainer before launching the nodes to ensure that
there are no DNS lookup failures when launching a node. Some implementations
will exit upon DNS lookup failure, thereby crashlooping that pods deployment,
which in turn will crash-loop other pods. The drawback of this method is that if
we want statefulset scaling-up assurances, we must do it manually.

### Readiness Prob

Lastly, we expose a readiness prob command to allow the user to make use of
readiness as they see fit for each deployment. Unfortunately, it does not seem
worthwhile, at this point in time, to determin readiness against all the various
types of deployment networks (livenet, simnet, testnet, etc) and also allow the
user to define what readiness means: does it mean that the network is fully
synced? Does it mean that the node is ready to validate a transaction? Or does
it simply mean that nothing is broken? etc.

Below are suggested readiness probes for each deployment type which would switch
Kubernetes reporting to "Ready" once and only if the node is fully synced.

**bitcoind:**

```yml
readinessCMD:
    "tail -n 500 /data/debug.log | grep 'UpdateTip: new best=' | tail -3 | grep
    progress=1.0"
```

**bcoin:**

```yml
readinessCMD: 'tail -n 1000 /.bcoin/debug.log | grep progress=100'
```

**btcd:**

```yml
readinessCMD:
    'tail -n 100 /root/.btcd/logs/mainnet/btcd.log | grep ''SYNC: Processed'' |
    tail -n 1 | awk ''{print $1"T"$2"."$16"T"$17}'' | awk -F. ''{ c="date -jf
    %FT%T " $1 " +%s"; c | getline t1; close(c); m="date -jf %FT%T " $3 " +%s";
    m | getline t2;close(m); if( (t1 - t2) > 60) exit 1 }'''
```

> My god this one-liner is ugly:
>
> -   `tail -n 100 /root/.btcd/logs/mainnet/btcd.log` Take the last 100 lines
>     from the log
> -   `grep ''SYNC: Processed''` Of those, keep only the lines that have "SYNC:
>     Processed" in them
> -   `tail -n 1` Take the last of those
> -   `awk ''{print $1"T"$2"."$16"T"$17}''` Format the two dates that are in
>     that log: when the log was published, and when the block was published
> -   `awk -F. ''{ c="date -jf %FT%T " $1 " +%s"; c | getline t1; close(c); m="date -jf %FT%T " $3 " +%s"; m | getline t2;close(m);`
>     Covert each date to unix time in seconds
> -   `if( (t1 - t2) > 60) exit 1` If they differ by more than 1 minute (60
>     seconds) return an error and fail the readiness prob (blocks can
>     absolutely be outside this window, adjust accordingly)

## Examples

See [Examples](./examples.md)
