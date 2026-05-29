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
        
        DOCKER_CREDS_ID = 'docker-hub-creds'
        GIT_CREDS_ID = 'github-token2'
    }

    stages {
        stage('Initialize & Validate') {
            steps {
                script {
                    env.IMAGE_NAME = params.DOCKER_IMAGE?.trim() ?: 'gorrelasreekanth/secureforge-ui'
                    if (env.IMAGE_NAME.contains('your-docker-repo') || env.IMAGE_NAME.startsWith('PLEASE_SET')) {
                        error "Invalid DOCKER_IMAGE: ${env.IMAGE_NAME}. Please set a real namespace/repo."
                    }
                }
            }
        }

        stage('Checkout App Code') {
            steps {
                // Explicitly pull down your application code from GitHub
                checkout scm
            }
        }

        stage('Scan for Secrets') {
            steps {
                echo "Scanning repository for hardcoded passwords/tokens..."
                // Runs TruffleHog container to check your checked-out codebase for leaks
                sh 'docker run --rm -v "$(pwd):/pwd" trufflesecurity/trufflehog:latest github --repo="https://github.com/sreekanthgorrela96/Gocdtest" --only-verified || true'
            }
        }

        stage('Lint Dockerfile') {
            steps {
                sh 'docker run --rm -i hadolint/hadolint < Dockerfile'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${TAG} ."
            }
        }

        stage('Security Scan Image') {
            steps {
                sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity CRITICAL --exit-code 1 ${IMAGE_NAME}:${TAG}"
            }
        }

        stage('Push to Docker Hub') {
            steps {
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
                        rm -rf manifest-checkout
                        git clone --depth 1 --branch ${MANIFESTS_BRANCH} https://x-access-token:${GIT_TOKEN}@${MANIFESTS_REPO} manifest-checkout
                        cd manifest-checkout
                        
                        sed -i "s|^[[:space:]]*image:.*|          image: ${IMAGE_NAME}:${TAG}|" ${KUSTOMIZE_DEPLOYMENT_PATH}
                        grep -Fq "image: ${IMAGE_NAME}:${TAG}" ${KUSTOMIZE_DEPLOYMENT_PATH} || (echo "ERROR: image line not updated" && exit 1)
                        
                        git config user.name "jenkins-bot"
                        git config user.email "jenkins@secureforge.com"
                        
                        git add ${KUSTOMIZE_DEPLOYMENT_PATH}
                        
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
            cleanWs()
            sh "docker rmi ${IMAGE_NAME}:${TAG} ${IMAGE_NAME}:latest || true"
        }
        success {
            echo "Deployment successful: ${IMAGE_NAME}:${TAG} is now live."
        }
        failure {
            echo "Pipeline failed. Please check the logs for Docker or Git auth issues."
        }
    }
}
