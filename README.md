## Status & Todos

Replicas are running and discover each other.

- test with 3 replicas
- open questions:
   - Can a node resync if it was "gone" for some time?
- Update documentation

# Run pocketbase replicas on kubernetes

## What is Marmot?

[Marmot](https://github.com/maxpert/marmot) is an distributed SQLite replicator that runs as a side-car to you service, and replicates data across cluster using NATS. 

## What is PocketBase?
[PocketBase](https://github.com/pocketbase/pocketbase) is an open source backend consisting of embedded database (SQLite) with realtime subscriptions, built-in auth management, convenient dashboard UI and simple REST-ish API.

## What is Kubernetes?
Kubernetes is an open-source platform for automating the deployment, scaling, and management of containerized applications.

## Important Notes:
 - **Cluster instances have to start with same DB snapshot** - Since Marmot doesn't support schema level change propagation, 
    tables, indexes you will be creating, deleting won't be picked up. Marmot only transports data right now! This
    repo ships with sample data snapshot that was created using local PocketBase instance, so it should give you
    good starting point. You only need schema of tables + indexes in order to see replication working. This should 
    not be a no big deal because one can easily write a script to apply migrations (recommended way), use the 
    backup to import old data, and deploy it as part of Docker image. 
 - **Change propagation is dependent on PocketBase committing to disk** - Marmot can only propagate changes that are written
    to disk! Marmot does not use any hooks or anything into PocketBase process. As a matter of fact Marmot doesn't
    even care whats running along side with it.
 - **This example doesn't use persistent volume** - Base snapshot and logs in Marmot nodes should be enough to get you
   up and running every-time. 

## Deploy and Scale