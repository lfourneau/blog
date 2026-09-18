# -*-Makefile-*-


CONFIG_FILES=./secrets/credentials.txt \
	     ./secrets/db_password.txt\
	     ./secrets/db_root_password.txt\
	     ./srcs/.env

all: $(CONFIG_FILES)
	@sudo mkdir -p ${HOME}/data/db
	@sudo mkdir -p ${HOME}/data/wordpress
	if ! grep "${USER}" /etc/hosts; then echo "127.0.0.1	${USER}.42.fr" | sudo tee -a /etc/hosts; fi
	cd ./srcs && docker compose up --build -d 
clean:
	@echo "Shutting down docker but keeping data"
	cd ./srcs && docker compose down > /dev/null
	@echo "The services are now down"

fclean:
	@echo "Shutting down docker and deleting all files"
	cd ./srcs && docker compose down --rmi all -v
	@sudo rm -rf ${HOME}/data/db 
	@sudo rm -rf ${HOME}/data/wordpress
	@echo "The deletetion and shutdown is complete"

re: fclean all

$(CONFIG_FILES):
	@echo "Fetching config files"	
	git clone https://github.com/lfourneau/inception_42_files.git
	mkdir -p secrets
	cp ./inception_42_files/* ./secrets/
	cp ./inception_42_files/.env ./srcs/.env
	rm -rf inception_42_files
	@echo "Config files installed"

