# source config.sh
set -e

util_defaults="set -e"

RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m' 

function conjur_authenticate {
	$util_defaults
    api_key=$(curl --fail -s -k --user "admin:$ADMIN_PASSWORD" $CONJUR_URL/authn/conjur/login)
	session_token=$(curl --fail -s -k --data "$api_key" $CONJUR_URL/authn/conjur/admin/authenticate)
	token=$(echo -n $session_token | base64 | tr -d '\r\n')
	header="Authorization: Token token=\"$token\""
	echo "$header"
}

function delete_variable {
	$util_defaults
	set -e
	variable_name=$1
	echo "deleting variable: $variable_name"
	output=$(curl -H "$header" -X PATCH -d "$(< policies/delete-$variable_name-variable.yml)" -s -k $CONJUR_URL/policies/conjur/policy/root)
}

function append_policy {
	$util_defaults
	policy_branch=$1
	policy_name=$2
	response=$(curl -H "$header" -X POST -d "$(< $policy_name)" -s -k $CONJUR_URL/policies/conjur/policy/$policy_branch)
	echo "$response"
}

function set_variable {
	$util_defaults
	variable_name=$1
	variable_value=$2
	curl -k -s -H "$header" --data "$variable_value" "$CONJUR_URL/secrets/conjur/variable/$variable_name"
}

function announce {
	$util_defaults
	echo "##############################################"
	echo "$1"
	echo "##############################################"
}

function repo_name {
	echo "$1" | awk -F '/' '{print $5}'
}

function echo_red {
	echo -e "${RED}${1}${NC}"
}

function echo_green {
	echo -e "${GREEN}${1}${NC}"
}

function echo_yellow {
	echo -e "${YELLOW}${1}${NC}"
}
