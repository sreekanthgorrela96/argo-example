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
                        # PAT must be the Password of a "Username with password" credential — not the credential ID.
                        if [ -z "$GIT_TOKEN" ] || [ "$GIT_TOKEN" = "$GIT_CREDS_ID" ]; then
                          echo "ERROR: GIT_TOKEN is empty or equals the credential ID ($GIT_CREDS_ID)."
                          echo "In Jenkins: Credentials -> update $GIT_CREDS_ID -> Password must be your GitHub PAT (ghp_... or github_pat_...), not the ID string."
                          exit 2
                        fi
                        case "$GIT_TOKEN" in ghp_*|github_pat_*) ;; *)
                          echo "WARN: Password does not look like a GitHub PAT. Continuing anyway."
                        ;; esac
                        GITHUB_REPO=$(echo "${MANIFESTS_REPO}" | sed -n 's#^https://github.com/##p')
                        if [ -z "$GITHUB_REPO" ]; then
                          echo "MANIFESTS_REPO must be https://github.com/owner/repo.git"
                          exit 1
                        fi
                        AUTH_REMOTE="https://x-access-token:${GIT_TOKEN}@github.com/${GITHUB_REPO}"
                        rm -rf manifest-checkout
                        git clone --depth 1 --branch "${MANIFESTS_BRANCH}" "$AUTH_REMOTE" manifest-checkout
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
                        # Ensure push uses PAT (some Git versions strip credentials from clone URL in config)
                        git remote set-url origin "${AUTH_REMOTE}"
                        GIT_TERMINAL_PROMPT=0 git push origin "HEAD:${MANIFESTS_BRANCH}"
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
