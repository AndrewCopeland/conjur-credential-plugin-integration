# conjur-credential-plugin-integration
Testing the conjur jenkins credential plugin integration


## Setup
`setup.sh dap` will install and configure  dap and jenkins.
- install conjur
- load `policy.yml` into conjur
- build jenkins image with conjur ssl cert
- run jenkins image
- fetch the conjur-credentials-plugin and compile plugin into hpi
- load plugin into jenkins
- attach `jenkins/` directory into jenkins container (predefined jenkins jobs and configurations)
- restart jenkins
- set jenkins credential to the conjur api key
- execute `test.sh`

## Testing
`test.sh` will run the integration tests defined within this file.
- starts the jenkins jobs
- wait for jobs to finish and then get console output
- validate the expected credential from the console output of the job

## Development
`compile_and_push_plugin.sh` will compile local code changes and load new plugin into jenkins.
- code is compiled from the `conjur-credentials-plugin` directory
- load newly compiled plugin
- restart jenkins
