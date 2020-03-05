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
export TEAM_SECRET="default"

# 1 is compile from repo, 0 is use local file 'CONJUR_PLUGIN_PATH'
export BUILD_HPI_FROM_REPO=true
export CREDENTIAL_PLUGIN_REPO="https://github.com/cyberark/conjur-credentials-plugin.git"
export CREDENTIAL_PLUGIN_BRANCH="JIT-Creds"

export MOUNT_AUTHN_JENKINS=true
export GIT_AUTHN_JENKINS="https://github.com/AndrewCopeland/conjur-authn-jenkins"
export GIT_PLUGIN="git@latest"

