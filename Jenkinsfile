pipeline {
	agent any

	environment {
        GITHUB_KNOWN_HOSTS = "|1|9jdFWI7J5bs9QKEWctRqNg2cO2Y=|KjcVFV8qS/3DPnLZOQLweHOx+lA= ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"

		SSH_PRIVKEY = credentials('jenkins')
    }

		stage('Prepare environment') {
			steps {
				script {
                    sh """
                    	echo "Setting up the known_hosts file"
						install -d .ssh -m 0700
						echo '${GITHUB_KNOWN_HOSTS}' | tee .ssh/known_hosts > /dev/null
                    """
                }
			}
		}

}