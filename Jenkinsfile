pipeline {
    agent any

    parameters {
        string(
            name: 'DOCKER_IMAGE',
            defaultValue: 'gorrelasreekanth/secureforge-ui',
            description: 'Docker Hub image (namespace/repo); must match docker-hub-creds.'
        )
    }

    environment {
        TAG = "${env.BUILD_NUMBER}"
        MANIFESTS_REPO = 'https://github.com/sreekanthgorrela96/argo-example.git'
        MANIFESTS_BRANCH = 'main'
        KUSTOMIZE_DEPLOYMENT_PATH = 'k8s-manifests/base/deployment.yaml'
        DOCKER_CREDS_ID = 'docker-hub-creds'
        GIT_CREDS_ID = 'github-token-creds'
    }

    stages {
        stage('Initialize & Validate') {
            steps {
                script {
                    env.IMAGE_NAME = params.DOCKER_IMAGE?.trim() ?: 'gorrelasreekanth/secureforge-ui'
                    if (env.IMAGE_NAME.contains('PLEASE_SET') ||
                            env.IMAGE_NAME.contains('your-docker-repo') ||
                            env.IMAGE_NAME.startsWith('yourdockerhubuser/')) {
                        error "Invalid DOCKER_IMAGE: ${env.IMAGE_NAME}"
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
                script {
                    docker.withRegistry('https://index.docker.io/v1/', "${env.DOCKER_CREDS_ID}") {
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                        sh "docker tag ${IMAGE_NAME}:${TAG} ${IMAGE_NAME}:latest"
                        sh "docker push ${IMAGE_NAME}:latest"
                    }
                }
            }
        }

        stage('Update GitOps Manifest') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${env.GIT_CREDS_ID}", usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
                    sh '''
                        set -e
                        CLONE_URL=$(echo "${MANIFESTS_REPO}" | sed "s#^https://#https://${GIT_USER}:${GIT_TOKEN}@#")
                        rm -rf manifest-checkout
                        git clone --depth 1 --branch "${MANIFESTS_BRANCH}" "$CLONE_URL" manifest-checkout
                        cd manifest-checkout
                        sed -i "s|^[[:space:]]*image:.*|          image: ${IMAGE_NAME}:${TAG}|" "${KUSTOMIZE_DEPLOYMENT_PATH}"
                        git config user.name "jenkins-bot"
                        git config user.email "jenkins@secureforge.com"
                        git add "${KUSTOMIZE_DEPLOYMENT_PATH}"
                        if git diff --staged --quiet; then
                            echo "No manifest changes."
                            exit 0
                        fi
                        git commit -m "ci: deploy ${IMAGE_NAME}:${TAG}"
                        git push origin "HEAD:${MANIFESTS_BRANCH}"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Deployment successful: ${IMAGE_NAME}:${TAG}"
        }
    }
}
