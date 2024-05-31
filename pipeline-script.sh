name: Hprofile Actions
on: workflow_dispatch   # [push, workflow_dispatch]
env:
  AWS_REGION: us-east-1
jobs: 
  Testing:
    runs-on: ubuntu-latest
    steps:
      - name: code checkout
        uses: actions/checkout@v4

      - name: Maven test
        run: mvn test
        
      - name: Checkstyle
        run: mvn checkstyle:checkstyle

      - name: Set Java 11
        uses: actions/setup-java@v2
        with:
          distribution: 'adopt'
          java-version: '11'

      - name: Setup SonarQube
        uses: warchant/setup-sonar-scanner@v7
      
      # Run sonar-scanner
      - name: SonarQube Scan
        run: sonar-scanner 
           -Dsonar.host.url=${{ secrets.SONAR_URL }} 
           -Dsonar.login=${{ secrets.SONAR_TOKEN }}   
           -Dsonar.organization=${{ secrets.SONAR_ORGANIZATION }} 
           -Dsonar.projectKey=${{ secrets.SONAR_PROJECT_KEY }}  
           -Dsonar.sources=src/  
           -Dsonar.junit.reportsPath=target/surefire-report/ 
           -Dsonar.jacoco.reportsPath=target/jacoco.exec   
           -Dsonar.java.checkstyle.reportsPath=target/checkstyle-result.xml  
           -Dsonar.java.binaries=target/test-classes/com/visualpathit/account

      # Check the Quality Gate status.
      - name: SonarQube Quality Gate check
        id: sonarqube-quality-gate-check
        uses: sonarsource/sonarqube-quality-gate-action@master
        # Force to fail step after specific time.
        timeout-minutes: 5
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_URL }} #OPTIONAL

  BUILD_AND_PUBLISH:
    needs: Testing
    runs-on: ubuntu-latest
    steps:
      - name: code checkout
        uses: actions/checkout@v4  
    
#      - name: Update application.properties file
#        run: |
#          sed -i "s/^jdbc.username.*$/jdbc.username\=${{ secrets.RDS_USER }}/" src/main/resources/application.properties
#          sed -i "s/^jdbc.password.*$/jdbc.password\=${{ secrets.RDS_PASS }}/" src/main/resources/application.properties
#          sed -i "s/db01/${{ secrets.RDS_ENDPOINT }}/" src/main/resources/application.properties

      - name: upload image to ECR
        uses: appleboy/docker-ecr-action@master
        with:
          access_key: ${{ secrets.AWS_ACCESS_KEY_ID }}
          secret_key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          registry: ${{ secrets.REGISTRY }}
          repo: docker
          region: ${{ env.AWS_REGION }}
          tags: ${{ github.run_number }}                #latest,${{ github.run_number }}
          daemon_off: false
          dockerfile: ./Dockerfile
          context: ./
      
      - name: Update Image tag
        run: |
          sed -i "s|image:.*|image: 637423293208.dkr.ecr.us-east-1.amazonaws.com/docker:${{ github.run_number }} |" ./java.yaml

               
  DEPLOY:
    # needs: BUILD_AND_PUBLISH
    runs-on: ubuntu-latest
    steps:
      - name: code checkout
        uses: actions/checkout@v4  

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: update kube config
        run: aws eks update-kubeconfig --region us-east-1 --name demo-cluster
      
      - name: Install eksctl
        run: |
          curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
          sudo mv /tmp/eksctl /usr/local/bin
          eksctl version

      - name: Run bash.sh
        run: |
          chmod +x ./bash.sh
          ./bash.sh  

      - name: Deploy to EKS cluster
        run: |

          kubectl apply -f EKS/

