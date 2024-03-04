#!/usr/bin/env bash
set -euo pipefail

PGUSER=${PGUSER:-gorgias}
DOMAIN=${DOMAIN:-com}


for i in {000..127}; do
  echo "##### starting ticket_message_${i}"
  echo docker run --rm -e PGPASSWORD="${PGPASSWORD}" postgres psql -U $PGUSER -h "pgmain-${CLUSTER_NAME}.gorgias.${DOMAIN}" -t -c "DELETE FROM ticket_message_${i} tmp WHERE NOT EXISTS (SELECT 1 FROM ticket t WHERE t.id = tmp.ticket_id);"
done

echo 'done'
