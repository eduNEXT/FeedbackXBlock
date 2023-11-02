.PHONY: docs upgrade test quality install

REPO_NAME := FeedbackXBlock
DOCKER_NAME := feedbackxblock

# For opening files in a browser. Use like: $(BROWSER)relative/path/to/file.html
BROWSER := python -m webbrowser file://$(CURDIR)/


PACKAGE_NAME := feedback
EXTRACT_DIR := $(PACKAGE_NAME)/locale/en/LC_MESSAGES
EXTRACTED_DJANGO := $(EXTRACT_DIR)/django-partial.po
EXTRACTED_DJANGOJS := $(EXTRACT_DIR)/djangojs-partial.po
EXTRACTED_TEXT := $(EXTRACT_DIR)/text.po
JS_TARGET := public/js/translations
TRANSLATIONS_DIR := $(PACKAGE_NAME)/translations

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@awk -F ':.*?## ' '/^[a-zA-Z]/ && NF==2 {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

install-test:
	pip install -q -r requirements/test.txt

install-dev:
	pip install -q -r requirements/dev.txt

install: install-test

quality:  ## Run the quality checks
	pycodestyle --max-line-length=120 --config=.pep8 feedback
	pylint --rcfile=pylintrc feedback
	python setup.py -q sdist
	twine check dist/*

test:  ## Run the tests
	mkdir -p var
	rm -rf .coverage
	DJANGO_SETTINGS_MODULE=feedback.settings.test python -m coverage run --rcfile=.coveragerc  -m pytest

covreport:  ## Show the coverage results
	python -m coverage report -m --skip-covered

upgrade: export CUSTOM_COMPILE_COMMAND=make upgrade
upgrade: ## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -q -r requirements/pip-tools.txt
	pip-compile --upgrade --allow-unsafe -o requirements/pip.txt requirements/pip.in
	pip-compile --upgrade -o requirements/pip-tools.txt requirements/pip-tools.in
	pip install -q -r requirements/pip.txt
	pip install -q -r requirements/pip-tools.txt
	pip-compile --upgrade -o requirements/base.txt requirements/base.in
	pip-compile --upgrade -o requirements/dev.txt requirements/dev.in
	pip-compile --upgrade -o requirements/test.txt requirements/test.in
	pip-compile --upgrade -o requirements/quality.txt requirements/quality.in
	pip-compile --upgrade -o requirements/tox.txt requirements/tox.in
	pip-compile --upgrade -o requirements/ci.txt requirements/ci.in
	pip-compile --upgrade -o requirements/docs.txt requirements/docs.in


requirements: ## install development environment requirements
	pip install -r requirements/pip.txt
	pip install -qr requirements/pip-tools.txt
	pip install -r requirements/dev.txt

dev.clean:
	-docker rm $(DOCKER_NAME)-dev
	-docker rmi $(DOCKER_NAME)-dev

dev.build:
	docker build -t $(DOCKER_NAME)-dev $(CURDIR)

dev.run: dev.clean dev.build ## Clean, build and run test image
	docker run -p 8000:8000 -v $(CURDIR):/usr/local/src/$(REPO_NAME) --name $(DOCKER_NAME)-dev $(DOCKER_NAME)-dev

## Localization targets

extract_translations: symlink_translations ## extract strings to be translated, outputting .po files
	cd $(PACKAGE_NAME) && i18n_tool extract
	mv $(EXTRACTED_DJANGO) $(EXTRACTED_TEXT)
	if [ -f "$(EXTRACTED_DJANGOJS)" ]; then cat $(EXTRACTED_DJANGOJS) >> $(EXTRACTED_TEXT); rm $(EXTRACTED_DJANGOJS); fi

compile_translations: symlink_translations ## compile translation files, outputting .mo files for each supported language
	cd $(PACKAGE_NAME) && i18n_tool generate
	# python manage.py compilejsi18n --namespace $(PACKAGE_NAME)i18n --output $(JS_TARGET)

detect_changed_source_translations:
	cd $(PACKAGE_NAME) && i18n_tool changed

dummy_translations: ## generate dummy translation (.po) files
	cd $(PACKAGE_NAME) && i18n_tool dummy

build_dummy_translations: dummy_translations compile_translations ## generate and compile dummy translation files

validate_translations: build_dummy_translations detect_changed_source_translations ## validate translations

pull_translations: ## pull translations from transifex
	cd $(PACKAGE_NAME) && i18n_tool transifex pull

push_translations: extract_translations ## push translations to transifex
	cd $(PACKAGE_NAME) && i18n_tool transifex push

symlink_translations:
	if [ ! -d "$(TRANSLATIONS_DIR)" ]; then ln -s locale/ $(TRANSLATIONS_DIR); fi

install_transifex_client: ## Install the Transifex client
	# Instaling client will skip CHANGELOG and LICENSE files from git changes
	# so remind the user to commit the change first before installing client.
	git diff -s --exit-code HEAD || { echo "Please commit changes first."; exit 1; }
	curl -o- https://raw.githubusercontent.com/transifex/cli/master/install.sh | bash
	git checkout -- LICENSE README.md ## overwritten by Transifex installer

html: docs  ## An alias for the docs target.

docs: ## generate Sphinx HTML documentation, including API docs
	SPHINXOPTS="-W" make -C docs html
	$(BROWSER)docs/build/html/index.html

docs-%: ## Passthrough docs make commands
	SPHINXOPTS="-W" make -C docs $*
