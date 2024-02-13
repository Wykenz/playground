pipeline {
	agent any

	environment {
	GITHUB_KNOWN_HOSTS = "|1|9jdFWI7J5bs9QKEWctRqNg2cO2Y=|KjcVFV8qS/3DPnLZOQLweHOx+lA= ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"

	SSH_PRIVKEY = credentials('jenkins')
	}
	stages {
		stage('Hello world') {
			steps {
				echo 'Hello world!'
			}
		}
		stage('Prepare environment') {
			steps {
				echo 'Setting up the known_hosts file'
				sh 'install -d .ssh -m 0700'
				sh 'echo "${GITHUB_KNOWN_HOSTS}" > .ssh/known_hosts'
			}
		}

	}
}