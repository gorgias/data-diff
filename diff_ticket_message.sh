#!/usr/bin/env bash
set -euo pipefail

PGUSER=${PGUSER:-gorgias}
DOMAIN=${DOMAIN:-com}
BISECT_FACTOR=${BISECT_FACTOR:-512}
MAX_PARALLEL_ACCOUNT_DIFFS=${MAX_PARALLEL_ACCOUNT_DIFFS:-16}
CURRENT_PARALLEL_ACCOUNTS_COUNT=0

# Expected ENVs:
#   PGPASSWORD
#   CLUSTER_NAME

diff_account_id() {
  account_id=$1

  echo "##### starting account_id: $account_id"

  # Do not add account_id to key columns or the range selection will slow the query down
  if ! docker run --rm gcr.io/gorgias-ops-production/data-diff:v0.11.1-modded "postgresql://${PGUSER}:${PGPASSWORD}@pgreplicas-${CLUSTER_NAME}.gorgias.${DOMAIN}:5432/gorgias" ticket_message ticket_message_part --no-tracking \
    --limit 10 \
    --key-columns id \
    --columns account_id \
    --columns ticket_id \
    --columns integration_id \
    --columns rule_id \
    --columns external_id \
    --columns message_id \
    --columns public \
    --columns channel \
    --columns via \
    --columns source \
    --columns customer_id \
    --columns user_id \
    --columns from_agent \
    --columns subject \
    --columns body_text \
    --columns body_html \
    --columns stripped_text \
    --columns stripped_html \
    --columns stripped_signature \
    --columns headers \
    --columns attachments \
    --columns meta \
    --columns actions \
    --columns internal \
    --columns failure_detail \
    --where "account_id = ${account_id}" \
    --threads 16 \
    --algorithm hashdiff \
    --bisection-factor $BISECT_FACTOR ; then
    echo "!!!!!!!!!!!!!!!!!! Failed to diff account_id: $account_id !!!!!!!!!!!!!!!!!!"
    exit 1
  fi

  echo
  echo "##### Done diffing account_id: $account_id"
  echo
  exit 0
}

date

account_ids=$(docker run --rm -e PGPASSWORD="${PGPASSWORD}" postgres psql -U $PGUSER -h "pgreplicas-${CLUSTER_NAME}.gorgias.${DOMAIN}" -t -c "SELECT id FROM account ORDER BY id DESC;")

declare -A diff_job_ids

while true; do

  if [[ -z $account_ids ]]; then
    echo "No more account_ids to diff"
    break
  fi

  account_ids=$(echo "$account_ids" | sort -r | uniq)

  # pop the first MAX_PARALLEL_ACCOUNT_DIFFS account_id items from the list
  concurrent_account_ids=$(echo $account_ids | awk -v n=$MAX_PARALLEL_ACCOUNT_DIFFS '{for (i=1; i<=n; i++) {print $i}}')
  echo -e "===== concurrent_account_ids: \n${concurrent_account_ids}\n"
  account_ids=$(echo $account_ids | awk -v n=$MAX_PARALLEL_ACCOUNT_DIFFS '{for (i=n+1; i<=NF; i++) {print $i}}')
  echo -e "===== remaining account_ids: \n${account_ids}\n"

  for id in $concurrent_account_ids; do
    echo "===== Diffing account_id: $id"
    diff_account_id $id &
    diff_job_ids[$!]=$id
  done

  for job_id in "${!diff_job_ids[@]}"; do
    if ! wait $job_id; then
      echo "!!!!!!!!!!!!!!!!!! account id ${diff_job_ids[$job_id]} failed to diff! Adding it to the list of account ids to retry later !!!!!!!!!!!!!!!!!!"
      account_ids=$(echo -e "${account_ids}\n${diff_job_ids[$job_id]}")
    fi
  done
  unset diff_job_ids
done

echo
echo "all done"
date
echo
