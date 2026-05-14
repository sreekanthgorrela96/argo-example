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
        GIT_CREDS_ID = 'github-token-creds'
    }

    stages {
        stage('Initialize & Validate') {
            steps {
                script {
                    env.IMAGE_NAME = params.DOCKER_IMAGE?.trim() ?: 'gorrelasreekanth/secureforge-ui'
                    if (env.IMAGE_NAME.contains('your-docker-repo') ||
                            env.IMAGE_NAME.contains('yourdockerhubuser/') ||
                            env.IMAGE_NAME.startsWith('PLEASE_SET')) {
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
                withCredentials([usernamePassword(credentialsId: "${env.DOCKER_CREDS_ID}", usernameVariable: 'HUB_USER', passwordVariable: 'HUB_PASS')]) {
                    sh """
                        set -e
                        echo "\${HUB_PASS}" | docker login -u "\${HUB_USER}" --password-stdin
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
                    sh '''
                        set -e
                        if [ -z "$GIT_TOKEN" ] || [ "$GIT_TOKEN" = "$GIT_CREDS_ID" ]; then
                          echo "ERROR: GIT_TOKEN is empty or equals the Jenkins credential ID ($GIT_CREDS_ID)."
                          echo "Fix credential: type Username with password; Password = GitHub PAT (not the ID string)."
                          exit 2
                        fi
                        case "$GIT_TOKEN" in ghp_*|github_pat_*) ;; *)
                          echo "WARN: Password does not look like a GitHub PAT; continuing."
                        ;; esac

                        rm -rf manifest-checkout
                        AUTH_REMOTE="https://x-access-token:${GIT_TOKEN}@${MANIFESTS_REPO}"
                        git clone --depth 1 --branch "${MANIFESTS_BRANCH}" "$AUTH_REMOTE" manifest-checkout

                        cd manifest-checkout
                        NEW_IMG="${IMAGE_NAME}:${TAG}"
                        ESC_IMG=$(printf '%s' "${NEW_IMG}" | sed 's/[\\/&|]/\\&/g')
                        if ! grep -q '# secureforge-ci-image' "${KUSTOMIZE_DEPLOYMENT_PATH}"; then
                          echo "ERROR: ${KUSTOMIZE_DEPLOYMENT_PATH} must contain an image line ending with # secureforge-ci-image"
                          exit 1
                        fi
                        sed -i "s|^[[:space:]]*image:.*# secureforge-ci-image.*|          image: ${ESC_IMG}  # secureforge-ci-image|" "${KUSTOMIZE_DEPLOYMENT_PATH}"
                        if ! grep -Fq "${NEW_IMG}" "${KUSTOMIZE_DEPLOYMENT_PATH}"; then
                          echo "ERROR: expected image ${NEW_IMG} not found after sed."
                          exit 1
                        fi

                        git config user.name "jenkins-bot"
                        git config user.email "jenkins@secureforge.com"
                        git add "${KUSTOMIZE_DEPLOYMENT_PATH}"

                        if git diff --staged --quiet; then
                            echo "No manifest changes."
                            exit 0
                        fi

                        git commit -m "ci: deploy ${IMAGE_NAME}:${TAG}"
                        git remote set-url origin "${AUTH_REMOTE}"

                        PUSH_OK=0
                        for i in 1 2 3; do
                          if GIT_TERMINAL_PROMPT=0 git push origin "HEAD:${MANIFESTS_BRANCH}"; then
                            PUSH_OK=1
                            break
                          fi
                          echo "git push failed (attempt ${i}/3); retrying..."
                          sleep $((i * 5))
                        done
                        if [ "${PUSH_OK}" -ne 1 ]; then
                          echo "ERROR: git push failed after retries."
                          exit 1
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
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
