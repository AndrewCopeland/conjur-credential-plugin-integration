source config.sh
# set -x #echo one

function get_recent_build_number {
  folder=$1
  job_name=$2
  number=$(curl -s http://localhost:8080/job/$folder/job/$job_name/api/xml?xpath=/*/lastStableBuild/number | awk -F ">" '{print $2}' | awk -F "<" '{print $1}')
  echo "$number"
}

function get_next_build_number {
  folder=$1
  job_name=$2
  number=$(curl -s http://localhost:8080/job/$folder/job/$job_name/api/xml?xpath=/*/nextBuildNumber| awk -F ">" '{print $2}' | awk -F "<" '{print $1}')
  echo "$number"
}

function run_job_in_folder {
  folder=$1
  job_name=$2
  build_number=$(get_next_build_number "$folder" "$job_name")
  curl -s -X POST http://localhost:8080/job/$folder/job/$job_name/build
  echo "$build_number"
}

function get_job_response_in_folder {
  folder=$1
  job_name=$2
  build_number=1
  if [[ "$3" != "" ]]; then
    build_number="$3"
  fi

  building=$(curl -s http://127.0.0.1:8080/job/$folder/job/$job_name/$build_number/api/json?pretty=true | jq .building 2>/dev/null)
  while [ "$building" != "false" ]; do
    building=$(curl -s http://127.0.0.1:8080/job/team1/job/freestyle-secret/$build_number/api/json?pretty=true | jq .building 2>/dev/null)
    sleep 1
    echo "waiting for job $folder/$job_name #$build_number to finish building"
  done

  consoleText=$(curl -s http://127.0.0.1:8080/job/$folder/job/$job_name/$build_number/consoleText)
  echo "$consoleText"
}

function start_test {
  folder=$1
  job_name=$2
  build_number=$(run_job_in_folder "$folder" "$job_name")
  echo "$build_number"
}

function validate_test {
  folder=$1
  job_name=$2
  build_number=$3
  expected_password=$(echo "$4" | base64)

  echo "Validating test - $folder/$job_name #$build_number - expected secret '$expected_password'"
  console=$(get_job_response_in_folder "$folder" "$job_name" "$build_number")
  default_password=$(echo "$console" | grep "$expected_password")
  if [[ "$default_password" == "" ]]; then
    echo "$console"
    echo "FAILED: Recieved invalid password from jenkins"
    exit 1
  fi
  echo "PASSED"
}


# run the tests
folder="team1"
id_freestyle_secret=$(start_test "$folder" "freestyle-secret")
id_freestyle_secret_username=$(start_test "$folder" "freestyle-secret-username")
id_freestyle_secret_ssh_key=$(start_test "$folder" "freestyle-secret-ssh-key")

validate_test "$folder" "freestyle-secret" "$id_freestyle_secret" "$GIT_ACCESS_TOKEN"
validate_test "$folder" "freestyle-secret-username" "$id_freestyle_secret_username" "$GIT_ACCESS_TOKEN"
validate_test "$folder" "freestyle-secret-ssh-key" "$id_freestyle_secret_ssh_key" "$GIT_ACCESS_TOKEN"
