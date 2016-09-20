### system for clustering of distributed processes

## desc

#### plugable seed protocols

Used to acquire initial information on other nodes

#### plugable transport protocols

used to establish bidirectional query-reply style communication between nodes, responsible for potential routing, message re-sending, reconnecting, etc

works on top of [lweb3](https://github.com/leshy/lweb3)

#### plugable cluster protocols

used on top of the cluster to implement advanced functionality like raft protocol for master node consensus,
data storage algos, pub/sub etc



## usage

```
quorum = require "quorum"
quorum-seed-redis = require "quorum-seed-redis"

quorum.init { 
    seed: new quorum-seed-redis() 
    transport: new quorum-transport-smokesignal()
}
```



