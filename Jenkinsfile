pipeline {
  agent any

  parameters {
    string(
      name: 'DOCKER_IMAGE',
      defaultValue: 'your-docker-repo/secureforge-ui',
      description: 'Registry image name without tag (e.g. dockerhubuser/secureforge-ui). Must be a namespace you can push to.'
    )
  }

  environment {
    IMAGE_NAME = "${params.DOCKER_IMAGE ?: 'your-docker-repo/secureforge-ui'}"
    TAG = "${env.BUILD_NUMBER}"
    MANIFESTS_REPO = 'https://github.com/sreekanthgorrela96/argo-example.git'
    MANIFESTS_BRANCH = 'main'
    KUSTOMIZE_DEPLOYMENT_PATH = 'k8s-manifests/base/deployment.yaml'
  }

  stages {
    stage('Agent debug') {
      steps {
        sh '''#!/bin/bash
          set +e
          # #region agent log
          TS=$(date +%s)000
          DC=false
          test -f "$HOME/.docker/config.json" && DC=true
          PLACEHOLDER=false
          echo "$IMAGE_NAME" | grep -Eq '^(your-docker-repo/|REPLACE_)' && PLACEHOLDER=true
          JSON=$(printf '%s' "{\"sessionId\":\"559bfe\",\"hypothesisId\":\"H1-H3\",\"location\":\"Jenkinsfile:AgentDebug\",\"message\":\"registry_context\",\"data\":{\"IMAGE_NAME\":\"${IMAGE_NAME}\",\"TAG\":\"${TAG}\",\"HOME\":\"${HOME}\",\"dockerConfigPresent\":${DC},\"imageLooksPlaceholder\":${PLACEHOLDER}},\"timestamp\":${TS}}")
          curl -sS -X POST "http://host.docker.internal:7680/ingest/09e9ae1e-7728-44fe-940c-5aaac9b313c9" \
            -H "Content-Type: application/json" \
            -H "X-Debug-Session-Id: 559bfe" \
            -d "$JSON" || true
          echo "$JSON" >> "${WORKSPACE}/debug-559bfe.log"
          # #endregion agent log
          exit 0
        '''
      }
    }

    stage('Build') {
      steps {
        sh 'docker build -t ${IMAGE_NAME}:${TAG} .'
      }
    }

    stage('Push') {
      steps {
        sh '''#!/bin/bash
          set +e
          # #region agent log
          TS=$(date +%s)000
          JSON=$(printf '%s' "{\"sessionId\":\"559bfe\",\"hypothesisId\":\"H2\",\"location\":\"Jenkinsfile:Push\",\"message\":\"before_push\",\"data\":{\"IMAGE_NAME\":\"${IMAGE_NAME}\",\"TAG\":\"${TAG}\"},\"timestamp\":${TS}}")
          curl -sS -X POST "http://host.docker.internal:7680/ingest/09e9ae1e-7728-44fe-940c-5aaac9b313c9" \
            -H "Content-Type: application/json" \
            -H "X-Debug-Session-Id: 559bfe" \
            -d "$JSON" || true
          echo "$JSON" >> "${WORKSPACE}/debug-559bfe.log"
          # #endregion agent log
          exit 0
        '''
        withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
          sh '''
            set -e
            echo "$REG_PASS" | docker login -u "$REG_USER" --password-stdin
          '''
        }
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
