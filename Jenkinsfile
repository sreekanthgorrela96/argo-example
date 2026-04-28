pipeline {
  agent any

  environment {
    IMAGE_NAME = 'your-docker-repo/secureforge-ui'
    TAG = "${env.BUILD_NUMBER}"
    MANIFESTS_REPO = 'https://github.com/your-org/k8s-manifests.git'
    MANIFESTS_BRANCH = 'main'
    KUSTOMIZE_DEPLOYMENT_PATH = 'k8s-manifests/base/deployment.yaml'
  }

  stages {
    stage('Build') {
      steps {
        sh 'docker build -t ${IMAGE_NAME}:${TAG} .'
      }
    }

    stage('Push') {
      steps {
        sh 'docker push ${IMAGE_NAME}:${TAG}'
      }
    }

    stage('Update manifest repo') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'git-manifests-creds', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
          sh '''
            set -e
            CLONE_URL=$(echo "${MANIFESTS_REPO}" | sed "s#^https://#https://${GIT_USER}:${GIT_TOKEN}@#")
            rm -rf manifest-checkout
            git clone --depth 1 --branch "${MANIFESTS_BRANCH}" "$CLONE_URL" manifest-checkout
            cd manifest-checkout
            sed -i "s|^[[:space:]]*image:.*|          image: ${IMAGE_NAME}:${TAG}|" "${KUSTOMIZE_DEPLOYMENT_PATH}"
            git config user.name "jenkins"
            git config user.email "jenkins@example.com"
            git add "${KUSTOMIZE_DEPLOYMENT_PATH}"
            if git diff --staged --quiet; then
              echo "No manifest changes; skipping commit."
              exit 0
            fi
            git commit -m "ci: deploy secureforge-ui ${TAG}"
            git push origin "HEAD:${MANIFESTS_BRANCH}"
          '''
        }
      }
    }
  }
}
