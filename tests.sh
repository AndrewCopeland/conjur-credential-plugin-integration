source config.sh
source utils.sh
# set -ex #echo one
# its failing for some reason when set -e.
# I have to look into this but at this point the instance should be setup correctly.
set +e
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

function get_next_build_number {
  folder=$1
  job_name=$2
  if [[ "$1" != "" ]]; then
    folder="/job/$1"
  fi
  number=$(curl -s http://localhost:8080$folder/job/$job_name/api/xml?xpath=/*/nextBuildNumber| awk -F ">" '{print $2}' | awk -F "<" '{print $1}')
  echo "$number"
}

function run_job {
  folder=$1
  job_name=$2
  build_number=$(get_next_build_number "$folder" "$job_name")
  if [[ "$1" != "" ]]; then
    folder="/job/$1"
  fi
  curl -s -X POST http://localhost:8080$folder/job/$job_name/build
  echo "$build_number"
}

function get_job_response_in_folder {
  folder=$1
  job_name=$2
  build_number=1
  if [[ "$3" != "" ]]; then
    build_number="$3"
  fi

  if [[ "$1" != "" ]]; then
    folder="/job/$1"
  fi

  building=$(curl -s http://127.0.0.1:8080$folder/job/$job_name/$build_number/api/json?pretty=true | jq .building 2>/dev/null)
  while [ "$building" != "false" ]; do
    building=$(curl -s http://127.0.0.1:8080$folder/job/$job_name/$build_number/api/json?pretty=true | jq .building 2>/dev/null)
    sleep 1
    echo "waiting for job $1/$job_name #$build_number to finish building"
  done

  consoleText=$(curl -s http://127.0.0.1:8080$folder/job/$job_name/$build_number/consoleText)
  echo "$consoleText"
}

function start_test {
  folder=$1
  job_name=$2
  build_number=$(run_job "$folder" "$job_name")
  echo "$build_number"
}

function validate_test {
  folder=$1
  job_name=$2
  build_number=$3
  expected_password=$(echo "$4" | base64)
  TOTAL_TESTS=$(($TOTAL_TESTS + 1))
  echo "-------------------------------------"
  echo "Validating test - $folder/$job_name #$build_number - expected secret '$expected_password'"
  console=$(get_job_response_in_folder "$folder" "$job_name" "$build_number")
  default_password=$(echo "$console" | grep "$expected_password")
  if [[ "$default_password" == "" ]]; then
    echo "$console"
    echo_red "FAILED: Recieved invalid password from jenkins"
	  FAILED_TESTS=$(($FAILED_TESTS + 1))
    # exit 1
  else
	  PASSED_TESTS=$(($PASSED_TESTS + 1))
	  echo_green "PASSED"
  fi
}

function validate_fail_test {
  folder=$1
  job_name=$2
  build_number=$3
  expected_result=$4
  TOTAL_TESTS=$(($TOTAL_TESTS + 1))
  echo "-------------------------------------"
  echo "Validating test - $folder/$job_name #$build_number - expecting result '$expected_result'"
  console=$(get_job_response_in_folder "$folder" "$job_name" "$build_number")
  if [[ "$console" != *"Finished: FAILURE"* ]]; then
    echo "$console"
    echo_red "FAILED: Job passed but should have failed"
    FAILED_TESTS=$(($FAILED_TESTS + 1))
    return 1
  fi

  default_password=$(echo "$console" | grep "$expected_result")
  if [[ "$default_password" == "" ]]; then
    echo "$console"
    echo_red "FAILED: Recieved invalid response from jenkins"
	  FAILED_TESTS=$(($FAILED_TESTS + 1))
    # exit 1
  else
	  PASSED_TESTS=$(($PASSED_TESTS + 1))
	  echo_green "PASSED"
  fi
}

start=$(date +%s)

# run the tests
# folder tests
team_folder="team1"
id_freestyle_secret=$(start_test "$team_folder" "freestyle-secret")
id_freestyle_secret_username=$(start_test "$team_folder" "freestyle-secret-username")
id_freestyle_secret_ssh_key=$(start_test "$team_folder" "freestyle-secret-ssh-key")
id_freestyle_jit_secret=$(start_test "$team_folder" "freestyle-jit-secret")
id_freestyle_jit_secret_username=$(start_test "$team_folder" "freestyle-jit-secret-username")
id_freestyle_git_no_context=$(start_test "$team_folder" "freestyle-git-no-context")


# global tests
id_freestyle_secret_global=$(start_test "" "freestyle-secret")
id_freestyle_secret_username_global=$(start_test "" "freestyle-secret-username")
id_freestyle_secret_not_found_global=$(start_test "" "freestyle-secret-not-found")
id_freestyle_secret_ssh_key_global=$(start_test "" "freestyle-secret-ssh-key")

# validate all of the tests
validate_test "$team_folder" "freestyle-secret" "$id_freestyle_secret" "$GIT_ACCESS_TOKEN"
validate_test "$team_folder" "freestyle-secret-username" "$id_freestyle_secret_username" "$GIT_ACCESS_TOKEN"
validate_test "$team_folder" "freestyle-secret-ssh-key" "$id_freestyle_secret_ssh_key" "$GIT_ACCESS_TOKEN"

# validate_test "$folder" "freestyle-jit-secret" "$id_freestyle_jit_secret" "$TEAM_SECRET"
# validate_test "$folder" "freestyle-jit-secret-username" "$id_freestyle_jit_secret_username" "$TEAM_SECRET"

validate_test "" "freestyle-secret" "$id_freestyle_secret_global" "$GIT_ACCESS_TOKEN"
validate_test "" "freestyle-secret-username" "$id_freestyle_secret_username_global" "$GIT_ACCESS_TOKEN"
validate_test "" "freestyle-secret-ssh-key" "$id_freestyle_secret_ssh_key_global" "$GIT_SSH_KEY"

# validate expected failures
validate_fail_test "" "freestyle-secret-not-found" "$id_freestyle_secret_not_found_global" "Variable 'does/not/exists' not found in account 'conjur'"
validate_fail_test "$team_folder" "freestyle-git-no-context"  "$id_freestyle_git_no_context" "Unable to find credential at Global Instance Level"

end=$(date +%s)
duration=$((end - start))
echo "------------------------------"
echo "OUTPUT"
echo "------------------------------"
echo "test duration $duration seconds"
echo_green "PASSED: $PASSED_TESTS"
echo_red "FAILED: $FAILED_TESTS"
echo_yellow "TOTAL: $TOTAL_TESTS"

if [[ $TOTAL_TESTS -eq $PASSED_TESTS ]] ; then
  echo_green "success all tests passed"
else 
  echo_red "FAILED! All tests did not pass!"
  exit 1
fi
curl -X POST -d '<jenkins><install plugin="git@latest" /></jenkins>' --header 'Content-Type: text/xml' http://localhost:8080/pluginManager/installNecessaryPlugins