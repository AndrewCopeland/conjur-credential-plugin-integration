source config.sh

echo "download & install conjur"
docker pull $IMAGE_NAME
docker container run -d --name $CONJUR_NAME --network conjur --security-opt=seccomp:unconfined -p 443:443 -p 5432:5432 -p 1999:1999 $IMAGE_NAME
docker exec $CONJUR_NAME evoke configure master --accept-eula --hostname $CONJUR_NAME --admin-password $ADMIN_PASSWORD $CONJUR_ACCOUNT_NAME

echo "configure conjur with default policies and secret values"
pip3 install conjur-client
api_key=$(conjur-cli -a $CONJUR_ACCOUNT_NAME \
         -u admin \
         -p $ADMIN_PASSWORD \
         --insecure \
         -l https://localhost \
         policy apply root policy.yml | jq .. | tail -n 2 | head -n 1 | sed 's/"//g')

if [ "$api_key" == "{}" ]; then
  echo "ERROR: Could not get api_key for generated host"
  return 1
fi

# populate the secret values
conjur-cli -a $CONJUR_ACCOUNT_NAME \
         -u admin \
         -p $ADMIN_PASSWORD \
         --insecure \
         -l https://localhost \
         variable set git/access-token $GIT_ACCESS_TOKEN


conjur-cli -a $CONJUR_ACCOUNT_NAME \
         -u admin \
         -p $ADMIN_PASSWORD \
         --insecure \
         -l https://localhost \
         variable set git/ssh-key $GIT_SSH_KEY

echo "API_KEY: $api_key"
