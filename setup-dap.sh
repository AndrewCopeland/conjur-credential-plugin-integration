source config.sh
source utils.sh

echo "download & install conjur"
docker pull $IMAGE_NAME

authn_jenkins=""
if [ $MOUNT_AUTHN_JENKINS = true ]; then
  echo "mounting authn-jenkins"
  git clone $GIT_AUTHN_JENKINS
  cd "$(repo_name $GIT_AUTHN_JENKINS)"
  authn_jenkins="-v $(pwd)/authn_jenkins:/opt/conjur/possum/app/domain/authentication/authn_jenkins -e CONJUR_AUTHENTICATORS=authn,authn-jenkins/prod"
  cd ..
  echo "authn-jenkins mount: $authn_jenkins"
fi

docker container run -d --name $CONJUR_NAME --network conjur --security-opt=seccomp:unconfined -p 443:443 -p 5432:5432 -p 1999:1999 $authn_jenkins $IMAGE_NAME
docker exec $CONJUR_NAME evoke configure master --accept-eula --hostname $CONJUR_NAME --admin-password $ADMIN_PASSWORD $CONJUR_ACCOUNT_NAME

echo "configure conjur with default policies and secret values"
header=$(conjur_authenticate)
api_key=$(append_policy root ./policy.yml | jq .. | tail -n 2 | head -n 1 | sed 's/"//g')
set_variable "git/access-token" "$GIT_ACCESS_TOKEN"
set_variable "git/ssh-key" "$GIT_SSH_KEY"

echo "API_KEY: $api_key"
