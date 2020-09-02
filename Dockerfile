FROM openjdk:14-jdk-alpine AS development

WORKDIR /app

ENV HOME=/app MAVEN_HOME=/usr/share/maven

# Install development tools, such as Git, nodejs (for visual studio remote container), etc:
RUN apk add --no-cache git libstdc++ openvpn

# Download and install maven using the settings file in the nvm wrapper directory:
COPY .mvn/wrapper/maven-wrapper.properties /app/.mvn/wrapper/
RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && cat /app/.mvn/wrapper/maven-wrapper.properties \
     | grep distributionUrl \
     | sed 's/distributionUrl=//' \
     | sed 's/.zip/.tar.gz/' > /tmp/.maven-url \
  && wget -O /tmp/apache-maven.tar.gz $(cat /tmp/.maven-url) \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz /tmp/.maven-url \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

# Change the maven local repository path to "/usr/share/maven/repository":
RUN mkdir -p /usr/share/maven/repository \
 && sed -i 's/\/path\/to\/local\/repo/\/usr\/share\/maven\/repository/' \
    /usr/share/maven/conf/settings.xml \
 && sed -i 's/<localRepository/-->\n  <localRepository/' \
    /usr/share/maven/conf/settings.xml \
 && sed -i 's/\/localRepository>/\/localRepository> <!--/' \
    /usr/share/maven/conf/settings.xml

# Copy the project's dependency list:
COPY pom.xml /app/

# Download the project's dependencies:
RUN mvn dependency:sources dependency:resolve-plugins

# ==============================================================================

FROM development AS testing

COPY . /app

CMD [ "mvn", "test" ]

# ==============================================================================

FROM testing AS builder

RUN mvn install -Dmaven.test.skip=true

# ==============================================================================

FROM openjdk:14-jdk-alpine AS release

COPY --from=builder /app/target/maven-docker-demo-0.0.1-SNAPSHOT.jar .

CMD [ "java", "-jar", "maven-docker-demo-0.0.1-SNAPSHOT.jar" ]