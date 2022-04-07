# High Availability Bitcoin Node - Helm Chart

This is a rudimentary Helm Chart for a simple Highly Available Bitcoin node. At
present it supports multiple bitcoin implementations (bitcoind, btcd, bcoin),
architectures (arm64, amd64), deployment environments (cloud, bare-metal), and
networks (prod, test, simnet, etc).

## Why?

Bitcoin, at a macro level, is a fundamentally highly available system: though
one node might fail, the incentives in the system ensure that there are many
nodes still available. So why make a highly available node? Bitcoin is not,
however, highly available at the micro node level: a single node may experience
all kinds of individual down time, disruptions, and failures.

## Install

### Requirements

|            |       |
| ---------- | ----- |
| Kubernetes | >1.23 |
| Helm       | >3.8  |
| Longhorn   | >1.2  |

> You may want to design a 3+ host Kubernetes Cluster with this chart in mind
> Additionally, having host names will be helpful.

```
helm repo add gildedpleb https://gildedpleb.github.io/helm-charts/
helm repo update
helm show values gildedpleb/hab > values.hab.yml
```

Edit `values.hab.yml` according to [configuration](./configuration.md) options.
And [examples](./examples.md) for examples.

```
helm install hab gildedpled/hab -f values.hab.yaml
```

## Roadmap Feature List

-   Build images from repo locally, and automatically, and push to remote, via:
    https://flavio.castelli.me/2020/09/16/build-multi-architecture-container-images-using-kubernetes/
-   Store images locally in a registry like docker registry
-   Mirror source code repos locally
-   Make all officially supported repos interoperable, aka, the same RPC calls
    return the same data, in the same format, no matter if the load balancer
    directs you to a bcoin node or a bitcoind node.
    -   Would probably mean it needs to be a bitcoin controller, more here:
        https://leftasexercise.com/2019/10/14/building-a-bitcoin-controller-part-vi-managing-secrets-and-creating-events/
    -   Might even need a front end
-   Integrate with higher layers, like lightning, block explorers, coinjoins,
    etc.
-   Diversify out of Longhorn
-   Full tor integration, like tor services, or ingress
-   Add autoscaling... probably infeasible due to resource constraints
-   Reduce log pollution

## Contributors

gildedpleb

---

Be a Gilded Pleb. Run a HAB node.
