pipeline {
    agent any

    parameters {
        string(
            name: 'DOCKER_IMAGE',
            defaultValue: 'gorrelasreekanth/secureforge-ui',
            description: 'Docker Hub image (namespace/repo).'
        )
    }

    environment {
        TAG = "${env.BUILD_NUMBER}"
        MANIFESTS_REPO = 'github.com/sreekanthgorrela96/argo-example.git'
        MANIFESTS_BRANCH = 'main'
        KUSTOMIZE_DEPLOYMENT_PATH = 'k8s-manifests/base/deployment.yaml'
        
        // Jenkins Credentials IDs
        DOCKER_CREDS_ID = 'docker-hub-creds'
        GIT_CREDS_ID = 'github-token-creds'
    }

    stages {
        stage('Initialize & Validate') {
            steps {
                script {
                    env.IMAGE_NAME = params.DOCKER_IMAGE?.trim() ?: 'gorrelasreekanth/secureforge-ui'
                    // Basic sanity check to ensure build doesn't run on placeholder values
                    if (env.IMAGE_NAME.contains('your-docker-repo') || env.IMAGE_NAME.startsWith('PLEASE_SET')) {
                        error "Invalid DOCKER_IMAGE: ${env.IMAGE_NAME}. Please set a real namespace/repo."
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${TAG} ."
            }
        }

        stage('Push to Docker Hub') {
            steps {
                // withCredentials is used instead of docker.withRegistry to avoid plugin dependency errors
                withCredentials([usernamePassword(credentialsId: "${env.DOCKER_CREDS_ID}", usernameVariable: 'HUB_USER', passwordVariable: 'HUB_PASS')]) {
                    sh """
                        echo "${HUB_PASS}" | docker login -u "${HUB_USER}" --password-stdin
                        docker push ${IMAGE_NAME}:${TAG}
                        docker tag ${IMAGE_NAME}:${TAG} ${IMAGE_NAME}:latest
                        docker push ${IMAGE_NAME}:latest
                        docker logout
                    """
                }
            }
        }

        stage('Update GitOps Manifest') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${env.GIT_CREDS_ID}", usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
                    sh """
                        set -e
                        # Clean up previous runs
                        rm -rf manifest-checkout
                        
                        # Use x-access-token (GitHub) or oauth2 (GitLab) for token auth
                        # We use the token directly in the URL for the most reliable push
                        git clone --depth 1 --branch ${MANIFESTS_BRANCH} https://x-access-token:${GIT_TOKEN}@${MANIFESTS_REPO} manifest-checkout
                        
                        cd manifest-checkout
                        
                        # Use sed to update the specific image line
                        sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${TAG}|g" ${KUSTOMIZE_DEPLOYMENT_PATH}
                        
                        git config user.name "jenkins-bot"
                        git config user.email "jenkins@secureforge.com"
                        
                        git add ${KUSTOMIZE_DEPLOYMENT_PATH}
                        
                        # Only commit if there is a change
                        if git diff --staged --quiet; then
                            echo "No changes in manifest. Skipping push."
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
        always {
            // Important: keep the workspace clean to save disk space on the Jenkins node
            cleanWs()
        }
        success {
            echo "Deployment successful: ${IMAGE_NAME}:${TAG} is now live."
        }
        failure {
            echo "Pipeline failed. Please check the logs for Docker or Git auth issues."
        }
    }
}
