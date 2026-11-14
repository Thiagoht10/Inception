COMPOSE = docker compose -f srcs/docker-compose.yml

all: up

up:
	mkdir -p "$(HOME)/data/wordpress" "$(HOME)/data/mariadb"
	$(COMPOSE) up -d --build

build:
	$(COMPOSE) build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --remove-orphans

fclean:
	$(COMPOSE) down -v --rmi all --remove-orphans

re: fclean all

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

.PHONY: all up build down clean fclean re logs ps
