source config.sh
set +e
rm -rf conjur
rm -rf conjur-policy-parser/
rm -rf tmp
rm -f jenkins/conjur-$CONJUR_ACCOUNT_NAME.pem
rm -rf conjur-credentials-plugin
rm -rf conjur-authn-jenkins