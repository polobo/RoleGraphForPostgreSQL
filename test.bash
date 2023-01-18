#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s failglob

SELF_DIR="$(cd $(dirname $0) && pwd)"
TEST_DIR="${SELF_DIR}"/test
LIB_DIR="${SELF_DIR}"/lib
EXP_DIR="${TEST_DIR}"/expected
OUT_DIR="${TEST_DIR}"/output
DET_DIR="${TEST_DIR}"/detail
DIFF_COUNT=0
TEST_COUNT=0

function main()
{
    mkdir -p "${OUT_DIR}"

    while IFS= read -r -d '' filename
    do
        plain_filename=$(basename "${filename}" .psql)
        PSQLRC="${SELF_DIR}/.psqlrc" psql -q < <(print_test_script "${plain_filename}")
        if ! diff "${EXP_DIR}/${plain_filename}.txt" "${OUT_DIR}/${plain_filename}.txt" ; then
           echo "Difference found!"
           DIFF_COUNT=$((DIFF_COUNT+1))
        fi
        TEST_COUNT=$((TEST_COUNT+1))
    done < <(find "${TEST_DIR}" -type f -name '*.psql' -print0 | sort -z)
    echo "Total Tests Performed:     ${TEST_COUNT}"
    echo "Total Differences Present: ${DIFF_COUNT}"
}

function print_test_script()
{
    echo "CREATE ROLE :createrole_user_name CREATEROLE LOGIN;"
    echo "GRANT USAGE ON SCHEMA rolegraph TO :createrole_user_name;"
    echo "GRANT SELECT ON TABLE rolegraph.role_relationship TO :createrole_user_name;"
    echo "GRANT SELECT ON TABLE rolegraph.role_graph TO :createrole_user_name;"
    echo "SELECT current_user AS initial_user \gset"
    echo "\set ctx 'su'"
    echo "\set is_su true"
    echo "\set is_cr false"
    echo "\i '${LIB_DIR}/remove-roles.psql'"
    echo "\i '${TEST_DIR}"/"${1}.psql'"
    echo "\c - :createrole_user_name"
    echo "\set ctx 'cr'"
    echo "\set is_su false"
    echo "\set is_cr true"
    echo "\i '${TEST_DIR}"/"${1}.psql'"
    echo "SET search_path TO rolegraph;"
    echo "\C 'Test Result for ${1}'"
    echo "SELECT rolname, administration, memberof_users, memberof_groups, member_users, member_groups FROM rolegraph.role_graph WHERE rolname !~ '^pg_.*' AND rolname::regrole != 10"
    echo "\g '${OUT_DIR}"/"${1}.txt'"
    echo "\C 'Details for Test ${1}'"
    cat <<SQL
    SELECT
        leaf_node::oid::regrole, group_node::oid::regrole,
        case when grantor::oid = 10 then 'superuser' else grantor::oid::regrole::text end,
        level,
        via_names, privs_path, grantor_path,
        got_admin, got_set, got_inherit, got_inherit_via_set, privs
    FROM role_relationship
   WHERE level > 0
         AND not(leaf_node = 3373 -- pg_monitor
                 AND
                 grantor = 10) -- bootstrap superuser
         AND (leaf_node != 10)
SQL
    echo "\g '${DET_DIR}"/"${1}.txt'"
    echo "\c - :initial_user"
    echo "REVOKE USAGE ON SCHEMA rolegraph FROM :createrole_user_name;"
    echo "REVOKE SELECT ON TABLE rolegraph.role_relationship FROM :createrole_user_name;"
    echo "REVOKE SELECT ON TABLE rolegraph.role_graph FROM :createrole_user_name;"
    echo "\i '${LIB_DIR}/remove-roles.psql'"
    echo "DROP ROLE :createrole_user_name;"
}

main
