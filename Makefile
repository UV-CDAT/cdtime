.PHONY: conda-info conda-list setup-build setup-tests conda-rerender \
	conda-build conda-upload conda-dump-env conda-cp-output get_testdata \
	run-tests run-coveralls

SHELL = /bin/bash

os = $(shell uname)
pkg_name = cdtime
build_script = conda-recipes/build_tools/conda_build.py

test_pkgs = numpy cdat_info libcdms libdrs_f testsrunner
last_stable ?= 3.1.2

conda_env ?= base
workdir ?= $(PWD)/workspace
branch ?= $(shell git rev-parse --abbrev-ref HEAD)
extra_channels ?= cdat/label/nightly conda-forge
conda ?= $(or $(CONDA_EXE),$(shell find /opt/*conda*/bin $(HOME)/*conda* -type f -iname conda))
artifact_dir ?= $(PWD)/artifacts
conda_env_filename ?= spec-file
build_version ?= 3.7

ifneq ($(coverage),)
coverage = -c tests/coverage.json --coverage-from-egg
endif

# TODO change back to master
conda_recipes_branch ?= build_tool_update.2

conda_base = $(patsubst %/bin/conda,%,$(conda))
conda_activate = $(conda_base)/bin/activate

ifdef $(artifact_dir)
conda_build_extra = --copy_conda_package $(artifact_dir)/
endif

ifndef $(local_repo)
local_repo = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
endif

conda-info:
	source $(conda_activate) $(conda_env); conda info

conda-list:
	source $(conda_activate) $(conda_env); conda list

setup-build:
ifeq ($(wildcard $(workdir)/conda-recipes),)
	git clone -b $(conda_recipes_branch) https://github.com/CDAT/conda-recipes $(workdir)/conda-recipes
else
	cd $(workdir)/conda-recipes; git pull
endif

setup-tests:
	source $(conda_activate) base; conda create -y -n $(conda_env) --use-local \
		$(foreach x,$(extra_channels),-c $(x)) $(pkg_name) $(foreach x,$(test_pkgs),"$(x)") $(foreach x,$(extra_pkgs),"$(x)")

conda-rerender: setup-build 
	python $(workdir)/$(build_script) -w $(workdir) -l $(last_stable) -B 0 -p $(pkg_name) \
		-b $(branch) --do_rerender --conda_env $(conda_env) --ignore_conda_missmatch \
		--conda_activate $(conda_activate)

conda-build:
	mkdir -p $(artifact_dir)

	python $(workdir)/$(build_script) -w $(workdir) -p $(pkg_name) --build_version $(build_version) \
		--do_build --conda_env $(conda_env) --extra_channels $(extra_channels) \
		--conda_activate $(conda_activate) $(conda_build_extra)

conda-upload:
	source $(conda_activate) $(conda_env); \
		output=$$(conda build --output $(workdir)/$(pkg_name)-feedstock); \
		anaconda -t $(conda_upload_token) upload -u $(user) -l $(label) $${output} --force

conda-dump-env:
	mkdir -p $(artifact_dir)

	source $(conda_activate) $(conda_env); conda list --explicit > $(artifact_dir)/$(conda_env_filename).txt

run-tests:
	source $(conda_activate) $(conda_env); python run_tests.py -H -v2 $(coverage)

run-coveralls:
	source $(conda_activate) $(conda_env); coveralls;