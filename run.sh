#!/bin/sh

cd /pb
cat << "EOD"
                                         ___  ___                           _
                                         |  \/  |                          | |
                                         | .  . | __ _ _ __ _ __ ___   ___ | |_
                                         | |\/| |/ _  | '__| '_   _ \ / _ \| __|
                                         | |  | | (_| | |  | | | | | | (_) | |_
                                         \_|  |_/\__,_|_|  |_| |_| |_|\___/ \__|

This data is sample database from http://2016.padjo.org/files/data/starterpack/ssa-babynames/ssa-babynames-nationwide-since-1980.sqlite
             (Marmot doesn't support schema changes replication, so make sure it boots with same DB state everywhere)
                                    Database was prepared and imported into local PocketBase
EOD
tar vxzf ./pb_data.tar.gz


/pb/pocketbase serve --http=0.0.0.0:8090 &
PB_ID=$!

# Generate Node ID
NODE_ID=$(echo $POD_UID)

HOSTNAME=$(hostname)
LAST_CHAR="${HOSTNAME: -1}"

NUMBER="$LAST_CHAR"

if [ "$NUMBER" -eq 0 ]; then
    NUMBER=1
elif [ "$NUMBER" -eq 1 ]; then
    NUMBER=0
fi

  # Get namespace
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

   # Get ServiceAccount token
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

   # API Server
#API_SERVER="https://kubernetes.default.svc"
API_SERVER="https://kubernetes.default.svc.cluster.local"


   # Label selector (adjust to match your pods' labels)
LABEL_SELECTOR="app=pocketbase"

  ### TEST BELOW SCRIPT

MARMOT_CONFIG=$(cat << EOM
db_path="/pb/pb_data/data.db"
node_id=${NODE_ID}

[replication_log]
shards=1
replicas=2
max_entries=1024
compress=true

[logging]
format="console"
EOM
)

# Enable disable snapshots based on WEBDAV_URL
if [ -z "$WEBDAV_URL" ]; then
    MARMOT_CONFIG="${MARMOT_CONFIG}"$(cat << EOM

[snapshot]
enable=false
EOM
)
else
    MARMOT_CONFIG="${MARMOT_CONFIG}"$(cat << EOM

[snapshot]
enable=true
store='webdav'
interval=3600_000

[snapshot.webdav]
url="${WEBDAV_URL}"
EOM
)
fi

echo "$MARMOT_CONFIG" > ./marmot-config.toml

# Start marmot in a loop
while true; do
    sleep 1

    # Launch!
    echo "Launching marmot ..."
    GOMEMLIMT=32MiB \
    /pb/marmot -config ./marmot-config.toml -cluster-addr 0.0.0.0:4221 -cluster-peers "dns://pocketbase-svc-${number}.pocketbase.svc.cluster.local:4221/" &
    MARMOT_ID=$!

    # Wait for marmot to exit
    wait $MARMOT_ID

    # Restart Marmot
    echo "Marmot needs to be running all the time, restarting..."
    sleep 1
done


# Define a cleanup function
cleanup() {
    echo "Caught signal, stopping."
    kill $PB_ID $MARMOT_ID
}

# Set the trap
trap cleanup TERM INT KILL

wait $PB_ID $MARMOT_ID
