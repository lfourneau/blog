FROM debian:bookworm

EXPOSE 443

ARG USR_INF

ENV USR_INF=$USR_INF

RUN apt-get update && apt-get -y install openssl gettext 

RUN apt-get update && apt-get -y install curl procps gnupg2 ca-certificates lsb-release debian-archive-keyring
RUN curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

#check the authenticity of the package (see nginx documentation)
RUN gpg --dry-run --quiet --no-keyring --import --import-options \
	import-show /usr/share/keyrings/nginx-archive-keyring.gpg \
	| grep -q 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 

RUN echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
	https://nginx.org/packages/debian `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list

RUN printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | tee /etc/apt/preferences.d/99nginx

RUN apt-get update && apt-get -y install nginx

COPY ./tools/set-up.sh ./tools/set-up.sh
COPY ./conf/nginx.conf /etc/nginx/nginx.conf

CMD ["bash", "./tools/set-up.sh"]
