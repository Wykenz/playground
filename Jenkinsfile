pipeline {
	agent {
		label 'bob5'
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