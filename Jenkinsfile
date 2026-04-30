pipeline {
    agent any

    parameters {
        string(
            name: 'DOCKER_IMAGE',
            defaultValue: 'gorrelasreekanth/secureforge-ui',
            description: 'Docker Hub image name (namespace/repo).'
        )
    }

    environment {
        TAG = "${env.BUILD_NUMBER}"
        MANIFESTS_REPO = 'github.com/sreekanthgorrela96/argo-example.git'
        MANIFESTS_BRANCH = 'main'
        KUSTOMIZE_DEPLOYMENT_PATH = 'k8s-manifests/base/deployment.yaml'
        
        // Credential IDs defined in Jenkins
        DOCKER_CREDS_ID = 'docker-hub-creds'
        GIT_CREDS_ID = 'git-manifests-creds'
    }

    stages {
        stage('Initialize & Validate') {
            steps {
                script {
                    // Set and validate the image name from parameters
                    env.IMAGE_NAME = params.DOCKER_IMAGE?.trim() ?: 'gorrelasreekanth/secureforge-ui'
                    
                    if (env.IMAGE_NAME.contains('PLEASE_SET') || env.IMAGE_NAME.contains('your-docker-repo')) {
                        error "Invalid DOCKER_IMAGE parameter: ${env.IMAGE_NAME}"
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                // Standard build command
                sh "docker build -t ${IMAGE_NAME}:${TAG} ."
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    // Authenticates, pushes, and logs out automatically
                    docker.withRegistry('https://index.docker.io/v1/', DOCKER_CREDS_ID) {
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                        sh "docker tag ${IMAGE_NAME}:${TAG} ${IMAGE_NAME}:latest"
                        sh "docker push ${IMAGE_NAME}:latest"
                    }
                }
            }
        }

        stage('Update GitOps Manifest') {
            steps {
                withCredentials([usernamePassword(credentialsId: GIT_CREDS_ID, usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
                    sh """
                        set -e
                        # Clean up and clone the manifest repository using the PAT token
                        rm -rf manifest-checkout
                        git clone --depth 1 --branch ${MANIFESTS_BRANCH} https://${GIT_USER}:${GIT_TOKEN}@${MANIFESTS_REPO} manifest-checkout
                        
                        cd manifest-checkout
                        
                        # Update the image tag in the deployment yaml
                        # Using '|' as a delimiter in sed because IMAGE_NAME contains '/'
                        sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${TAG}|g" ${KUSTOMIZE_DEPLOYMENT_PATH}
                        
                        # Git configuration
                        git config user.name "jenkins-bot"
                        git config user.email "jenkins@secureforge.com"
                        
                        # Add, check for changes, and push
                        git add ${KUSTOMIZE_DEPLOYMENT_PATH}
                        
                        if git diff --staged --quiet; then
                            echo "No changes detected in manifest. Skipping push."
                        else
                            git commit -m "chore: update ${IMAGE_NAME} to tag ${TAG} [skip ci]"
                            git push origin ${MANIFESTS_BRANCH}
                        fi
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Deployment successful: ${IMAGE_NAME}:${TAG} has been pushed and manifest updated."
        }
        cleanup {
            // Removes cloned repos and build artifacts from the workspace
            cleanWs()
        }
    }
}
