#!/usr/bin/env bash
set -euo pipefail

PGUSER=${PGUSER:-gorgias}
DOMAIN=${DOMAIN:-com}

all_extra_account_ids=""

for i in {000..127}; do
  echo "##### starting ticket_message_${i}"
  extra_account_ids=$(docker run --rm -e PGPASSWORD="${PGPASSWORD}" postgres psql -U $PGUSER -h "pgreplicas-${CLUSTER_NAME}.gorgias.${DOMAIN}" -t -c "SELECT distinct account_id FROM ticket_message_${i} tm WHERE NOT EXISTS (SELECT 1 FROM account acc WHERE acc.id = tm.account_id)")
  all_extra_account_ids="${all_extra_account_ids}\n${extra_account_ids}"
done

echo
echo -e "##### all_extra_account_ids:"
echo -e "$all_extra_account_ids" | sort -r | uniq
