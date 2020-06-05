FROM mcr.microsoft.com/powershell:latest

LABEL maintainer=brian.crouse@outlook.com

RUN apt-get update -y && apt-get install net-tools vim netcat dnsutils iputils-ping -y

COPY src /app

RUN chmod +x /app/docker-entrypoint.sh

WORKDIR /app

EXPOSE 4349

ENTRYPOINT ["/app/docker-entrypoint.sh"]