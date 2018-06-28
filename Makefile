ENV ?= local
CONFIG ?= config.yaml
ETH_PASSPHRASE ?= \"\"

# NOTE: if running outside a container, assume all required environment variables are configured properly.

# Default target
run: # printing "date" is important due to the logic CloudWatch uses to distinguish log files
	date; python -W ignore::DeprecationWarning qsp_protocol_node/qsp_protocol_node.py -p "$(ETH_PASSPHRASE)" $(ENV) $(CONFIG)

setup:
	pyenv uninstall -f 3.6.4 ; \
	ln -s -f $(shell git rev-parse --show-toplevel)/pre-commit $(shell git rev-parse --show-toplevel)/.git/hooks/pre-commit ; \
	chmod +x $(shell git rev-parse --show-toplevel)/.git/hooks/pre-commit ; \
	pyenv install 3.6.4 ; \
	pip install -r requirements.txt

test:
	pip install web3[tester] ; \
	PYTHONPATH=./tests:./qsp_protocol_node pytest --cov=qsp_protocol_node -s -v --disable-pytest-warnings --cov-config .coveragerc --cov-report term-missing --cov-report html tests/

clean:
	find . | egrep "^.*/(__pycache__|.*\.pyc)$$" | xargs rm -rf

run-docker:
	make clean && docker build -t qsp-protocol-node . && docker run -it \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v /tmp:/tmp \
		-e AWS_ACCESS_KEY_ID="$(shell aws --profile default configure get aws_access_key_id)" \
		-e AWS_SECRET_ACCESS_KEY="$(shell aws --profile default configure get aws_secret_access_key)" \
		-e AWS_DEFAULT_REGION="us-east-1" \
		-e ETH_PASSPHRASE="$(ETH_PASSPHRASE)" \
		qsp-protocol-node sh -c "make run"

test-docker:
	make clean && docker build -t qsp-protocol-node . && docker run -it \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v /tmp:/tmp \
		-e AWS_ACCESS_KEY_ID="$(shell aws --profile default configure get aws_access_key_id)" \
		-e AWS_SECRET_ACCESS_KEY="$(shell aws --profile default configure get aws_secret_access_key)" \
		-e AWS_DEFAULT_REGION="us-east-1" \
		qsp-protocol-node sh -c "make test"

test-ci:
	docker build --cache-from $(CACHE_IMAGE) -t qsp-protocol-node . && docker run -t \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v /tmp:/tmp \
		-v $(PWD)/tests/coverage:/app/tests/coverage \
		-e AWS_ACCESS_KEY_ID="$(AWS_ACCESS_KEY_ID)" \
		-e AWS_SECRET_ACCESS_KEY="$(AWS_SECRET_ACCESS_KEY)" \
		-e AWS_SESSION_TOKEN="$(AWS_SESSION_TOKEN)" \
		-e AWS_DEFAULT_REGION="us-east-1" \
		qsp-protocol-node sh -c "make test"
