.DEFAULT_GOAL := help

export SERVICE

.PHONY: help provision build up down update start stop exec restart
help:
	@echo 'Targets: start stop provision build up down update exec SERVICE=name restart SERVICE=name'

provision build up down update start stop exec restart:
	@bash scripts/host.sh $@
