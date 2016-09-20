# system for clustering of distributed processes

supports pluggable seed and transport protocols and abstract cluster protocols

```
quorum = require "quorum"
quorum-seed-redis = require "quorum-seed-redis"

quorum.init { 
    seed: new quorum-seed-redis() 
    transport: new quorum-transport-smokesignal()
}
```
