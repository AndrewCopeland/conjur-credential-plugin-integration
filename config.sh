set -e

export IMAGE_NAME="captainfluffytoes/dap:11.1"
export CONJUR_NAME="conjur-master"
export ADMIN_PASSWORD="Cyberark1"
export CONJUR_ACCOUNT_NAME="conjur"
export HOST_USERNAME="host/test-jenkins"
export CONJUR_PLUGIN_PATH="/Users/acopeland/git/AndrewCopeland/conjur-credential-plugin-integration/conjur-credentials-plugin/target/Conjur.hpi"
export CONJUR_URL="https://127.0.0.1"
export CONJUR_GIT_REPO="https://github.com/AndrewCopeland/conjur"
export JENKINS_URL="http://127.0.0.1:8080"
export JENKINS_USERNAME="conjur"
export JENKINS_PASSWORD="Cyberark1"

export GIT_ACCESS_TOKEN="default"
export GIT_SSH_KEY="default"

# 1 is compile from repo, 0 is use local file
export BUILD_HPI_FROM_REPO=1
export CREDENTIAL_PLUGIN_REPO="https://github.com/cyberark/conjur-credentials-plugin.git"
export CREDENTIAL_PLUGIN_BRANCH="JIT-Creds"

