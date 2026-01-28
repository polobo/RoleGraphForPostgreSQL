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

function check_prerequisites()
{
    echo "Checking prerequisites..."

    # First check if the database is clean (no user roles, schemas, or objects)
    # These checks must pass regardless of whether rolegraph is installed

    # Check for unexpected user schemas (excluding system schemas and rolegraph)
    local user_schemas
    user_schemas=$(PSQLRC="${SELF_DIR}/.psqlrc" psql -qtAX -c "SELECT array_agg(nspname::text) FROM pg_namespace WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast', 'rolegraph') AND nspname !~ '^pg_temp' AND nspname !~ '^pg_toast_temp';")
    if [[ "${user_schemas}" != "{public}" && "${user_schemas}" != "" ]]; then
        echo "ERROR: Unexpected schemas found in database: ${user_schemas}"
        echo "This test suite requires a fresh database with only the rolegraph schema installed."
        echo "Please use a clean PostgreSQL instance or database."
        exit 1
    fi

    # Check if public schema has any tables or views
    local public_objects
    public_objects=$(PSQLRC="${SELF_DIR}/.psqlrc" psql -qtAX -c "SELECT COUNT(*) FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid WHERE n.nspname = 'public' AND c.relkind IN ('r', 'v', 'm');")
    if [[ "${public_objects}" != "0" ]]; then
        echo "ERROR: Public schema contains tables or views."
        echo "This test suite requires a fresh database with only the rolegraph schema installed."
        echo "Please use a clean PostgreSQL instance or database."
        exit 1
    fi

    # Check for existing roles (excluding bootstrap superuser and system roles)
    local existing_roles
    existing_roles=$(PSQLRC="${SELF_DIR}/.psqlrc" psql -qtAX -c "SELECT array_agg(rolname::text) FROM pg_roles WHERE rolname !~ '^pg_' AND oid != 10;")
    if [[ "${existing_roles}" != "" && "${existing_roles}" != "{}" ]]; then
        echo "ERROR: User roles already exist in database: ${existing_roles}"
        echo "This test suite requires a completely fresh PostgreSQL cluster with no user-created roles."
        echo "Please use a clean PostgreSQL instance or drop all existing roles."
        exit 1
    fi

    # Now check if rolegraph schema exists - if clean but missing, auto-install
    local schema_exists
    schema_exists=$(PSQLRC="${SELF_DIR}/.psqlrc" psql -qtAX -c "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'rolegraph');")
    if [[ "${schema_exists}" != "t" ]]; then
        echo "✓ Database is clean but rolegraph schema not found"
        echo "Running install.bash to set up required views..."
        echo ""
        if ! "${SELF_DIR}/install.bash"; then
            echo ""
            echo "ERROR: Installation failed"
            exit 1
        fi
        echo ""
    fi

    # Check if required views exist
    local views_exist
    views_exist=$(PSQLRC="${SELF_DIR}/.psqlrc" psql -qtAX -c "SELECT COUNT(*) FROM pg_views WHERE schemaname = 'rolegraph' AND viewname IN ('role_relationship', 'role_graph', 'role_graph_detail');")
    if [[ "${views_exist}" != "3" ]]; then
        echo "ERROR: Required views not found in rolegraph schema."
        echo "Expected: role_relationship, role_graph, role_graph_detail"
        echo "Installation may have failed. Please check the output above."
        exit 1
    fi

    echo "✓ Prerequisites check passed"
}

function main()
{
    check_prerequisites
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
