.DEFAULT_GOAL := help

export SERVICE

.PHONY: help provision build up down update start start-logs logs stop exec restart
help:
	@echo 'Targets: start (detached) start-logs (attached) logs (follow) stop provision build up down update exec SERVICE=name restart SERVICE=name'

provision build up down update start start-logs logs stop exec restart:
	@bash scripts/host.sh $@
