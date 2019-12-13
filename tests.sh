source config.sh
# set -x #echo one

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
    echo "FAILED: Recieved invalid password from jenkins"
	FAILED_TESTS=$(($FAILED_TESTS + 1))
    # exit 1
  else
	PASSED_TESTS=$(($PASSED_TESTS + 1))
	echo "PASSED"
  fi
}

start=$(date +%s)

# run the tests
# folder tests
folder="team1"
id_freestyle_secret=$(start_test "$folder" "freestyle-secret")
id_freestyle_secret_username=$(start_test "$folder" "freestyle-secret-username")
id_freestyle_secret_ssh_key=$(start_test "$folder" "freestyle-secret-ssh-key")

# global tests
id_freestyle_secret_global=$(start_test "" "freestyle-secret")
id_freestyle_secret_username_global=$(start_test "" "freestyle-secret-username")

# validate all of the tests
validate_test "$folder" "freestyle-secret" "$id_freestyle_secret" "$GIT_ACCESS_TOKEN"
validate_test "$folder" "freestyle-secret-username" "$id_freestyle_secret_username" "$GIT_ACCESS_TOKEN"
validate_test "$folder" "freestyle-secret-ssh-key" "$id_freestyle_secret_ssh_key" "$GIT_ACCESS_TOKEN"
validate_test "" "freestyle-secret" "$id_freestyle_secret_global" "$GIT_ACCESS_TOKEN"
validate_test "" "freestyle-secret-username" "$id_freestyle_secret_username_global" "$GIT_ACCESS_TOKEN"



end=$(date +%s)
duration=$((end - start))
echo "test duration $duration seconds"

if [[ $TOTAL_TEST -eq $PASSED_TESTS ]] ; then
  echo "success all tests passed"
else 
  echo "FAILED: $FAILED_TESTS tests failed out of $TOTAL_TESTS tests"
fi
