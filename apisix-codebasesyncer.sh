#!/bin/sh

. ./configure.sh

# Define maximum waiting time (seconds, 0 means infinite wait)
MAX_WAIT=0
echo "Checking APISIX service status..."
start_time=$(date +%s)
while : ; do
  # Check service status by detecting if the port is listening
  if curl -sSf http://$APISIX_ADDR/apisix/admin/routes -H "$AUTH" -H "$TYPE" >/dev/null; then
    echo "APISIX has been successfully started (admin interface responds normally)"
    break
  fi

  # Timeout detection
  if [ $MAX_WAIT -ne 0 ]; then
    current_time=$(date +%s)
    if (( current_time - start_time > MAX_WAIT )); then
      echo "Error: APISIX startup not detected within ${MAX_WAIT} seconds"
      exit 1
    fi
  fi

  echo "Waiting for APISIX to start...(waited $(( $(date +%s) - start_time )) seconds)"
  sleep 5
done

# Add route for codebase syncer CLI tools
curl -i http://$APISIX_ADDR/apisix/admin/routes/codebase-syncer \
  -H "$AUTH" \
  -H "$TYPE" \
  -X PUT \
  -d '
{
    "uris": [
        "/codebaseSyncer_cli_tools/*"
    ],
    "id": "codebase-syncer",
    "name": "codebase-syncer",
    "upstream_id": "codebase-syncer",
    "plugins": {
      "proxy-rewrite": {
        "uri": "/$uri"
      },
      "file-logger": {
        "path": "logs/codebase-syncer.log",
        "include_req_body": false,
        "include_resp_body": false,
        "only_req_line": true
      },
      "limit-count": {
        "count": 100,
        "time_window": 60,
        "rejected_code": 429,
        "key": "remote_addr"
      }
    },
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "http://127.0.0.1:30574": 1
        }
    }
}'