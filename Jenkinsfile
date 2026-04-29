pipeline {
  agent any

  parameters {
    string(
      name: 'DOCKER_IMAGE',
      defaultValue: '',
      description: 'Required. Docker Hub image without tag, e.g. myhubuser/secureforge-ui (must be a repo you can push to).'
    )
  }

  environment {
    IMAGE_NAME = "${params.DOCKER_IMAGE ?: ''}"
    TAG = "${env.BUILD_NUMBER}"
    MANIFESTS_REPO = 'https://github.com/sreekanthgorrela96/argo-example.git'
    MANIFESTS_BRANCH = 'main'
    KUSTOMIZE_DEPLOYMENT_PATH = 'k8s-manifests/base/deployment.yaml'
  }

  stages {
    stage('Validate registry target') {
      steps {
        script {
          def img = env.IMAGE_NAME?.trim()
          if (!img) {
            error('DOCKER_IMAGE parameter is empty. Rebuild with DOCKER_IMAGE set (Job → Build with Parameters → DOCKER_IMAGE). Example: myhubuser/secureforge-ui')
          }
          if (img.startsWith('your-docker-repo/')) {
            error('DOCKER_IMAGE is still the docs placeholder "your-docker-repo/...". Replace with your Docker Hub namespace, e.g. myhubuser/secureforge-ui')
          }
          if (img.contains('.docker.io') || img.startsWith('docker.io/')) {
            error('DOCKER_IMAGE must be name/repo only (no docker.io/ prefix). Example: myhubuser/secureforge-ui')
          }
        }
      }
    }

    stage('Agent debug') {
      steps {
        sh '''#!/bin/bash
          set +e
          # #region agent log
          TS=$(date +%s)000
          DC=false
          test -f "$HOME/.docker/config.json" && DC=true
          PLACEHOLDER=false
          case "$IMAGE_NAME" in your-docker-repo/*) PLACEHOLDER=true ;; esac
          JSON=$(printf '%s' "{\"sessionId\":\"559bfe\",\"runId\":\"pre-build\",\"hypothesisId\":\"H1\",\"location\":\"Jenkinsfile:AgentDebug\",\"message\":\"registry_context\",\"data\":{\"IMAGE_NAME\":\"${IMAGE_NAME}\",\"TAG\":\"${TAG}\",\"HOME\":\"${HOME}\",\"dockerConfigPresent\":${DC},\"imageLooksPlaceholder\":${PLACEHOLDER}},\"timestamp\":${TS}}")
          curl -sS -X POST "http://host.docker.internal:7680/ingest/09e9ae1e-7728-44fe-940c-5aaac9b313c9" \
            -H "Content-Type: application/json" \
            -H "X-Debug-Session-Id: 559bfe" \
            -d "$JSON" || true
          echo "$JSON" >> "${WORKSPACE}/debug-559bfe.log"
          echo "DEBUG_MARKER IMAGE_NAME=${IMAGE_NAME} TAG=${TAG} dockerConfig=${DC}"
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
        withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
          sh '''#!/bin/bash
            set +e
            TS=$(date +%s)000
            JSON=$(printf '%s' "{\"sessionId\":\"559bfe\",\"runId\":\"pre-push\",\"hypothesisId\":\"H2\",\"location\":\"Jenkinsfile:Push\",\"message\":\"before_login\",\"data\":{\"IMAGE_NAME\":\"${IMAGE_NAME}\",\"TAG\":\"${TAG}\"},\"timestamp\":${TS}}")
            curl -sS -X POST "http://host.docker.internal:7680/ingest/09e9ae1e-7728-44fe-940c-5aaac9b313c9" \
              -H "Content-Type: application/json" \
              -H "X-Debug-Session-Id: 559bfe" \
              -d "$JSON" || true
            echo "$JSON" >> "${WORKSPACE}/debug-559bfe.log"

            printf '%s\\n' "$REG_PASS" | docker login -u "$REG_USER" --password-stdin > /tmp/jenkins_dl_out.txt 2>&1
            DL=$?
            head -c 2048 /tmp/jenkins_dl_out.txt > /tmp/jenkins_dl_trim.txt
            B64=$(base64 -w0 /tmp/jenkins_dl_trim.txt 2>/dev/null || base64 /tmp/jenkins_dl_trim.txt | tr -d '\\n')
            JSON2=$(printf '%s' "{\"sessionId\":\"559bfe\",\"runId\":\"post-login\",\"hypothesisId\":\"H2-H3\",\"location\":\"Jenkinsfile:docker_login\",\"message\":\"docker_login_result\",\"data\":{\"exitCode\":${DL},\"dockerLoginOutputB64\":\"${B64}\"},\"timestamp\":$(date +%s)000}")
            curl -sS -X POST "http://host.docker.internal:7680/ingest/09e9ae1e-7728-44fe-940c-5aaac9b313c9" \
              -H "Content-Type: application/json" \
              -H "X-Debug-Session-Id: 559bfe" \
              -d "$JSON2" || true
            echo "$JSON2" >> "${WORKSPACE}/debug-559bfe.log"
            echo "DEBUG_MARKER docker_login_exit=${DL}"
            cat /tmp/jenkins_dl_out.txt
            if [ "$DL" -ne 0 ]; then
              exit "$DL"
            fi

            docker push "${IMAGE_NAME}:${TAG}"
            PE=$?
            JSON3=$(printf '%s' "{\"sessionId\":\"559bfe\",\"runId\":\"post-push\",\"hypothesisId\":\"H4\",\"location\":\"Jenkinsfile:docker_push\",\"message\":\"docker_push_exit\",\"data\":{\"exitCode\":${PE},\"image\":\"${IMAGE_NAME}:${TAG}\"},\"timestamp\":$(date +%s)000}")
            curl -sS -X POST "http://host.docker.internal:7680/ingest/09e9ae1e-7728-44fe-940c-5aaac9b313c9" \
              -H "Content-Type: application/json" \
              -H "X-Debug-Session-Id: 559bfe" \
              -d "$JSON3" || true
            echo "$JSON3" >> "${WORKSPACE}/debug-559bfe.log"
            echo "DEBUG_MARKER docker_push_exit=${PE}"
            exit "$PE"
            # #endregion agent log
          '''
        }
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
