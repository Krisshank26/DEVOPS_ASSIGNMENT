FROM eclipse-temurin:21-jdk-alpine 

WORKDIR /app 

COPY App.java . 

RUN javac App.java 

EXPOSE 8080 

CMD ["java", "App" ] 