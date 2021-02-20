#!/bin/bash

# Packer provisioning script for Ubuntu 20.04 tested on AMI ami-0ff4c8fb495a5a50d
set -eo pipefail
cd ~

# Install dependencies
sudo apt-get update -y
sudo apt-get install -y build-essential git curl gsfonts imagemagick libmagickwand-dev nodejs redis-server libssl-dev \
  libcurl4-openssl-dev libxml2-dev libxslt1-dev libpq-dev cmake awscli \
  python3 python3-pip ruby-mustache nginx s3fs

# Install CloudFormation Helper scripts
sudo pip3 install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-py3-latest.tar.gz

# Install RVM
curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
curl -L https://get.rvm.io | bash -s -- --version ${RVM_VERSION}

# Set up RVM
source ~/.rvm/scripts/rvm
rvm install ${RUBY_VERSION}

# Download diaspora
git clone -b master https://github.com/diaspora/diaspora.git
cd diaspora
git checkout tags/${DIASPORA_VERSION}
cp config/database.yml.example config/database.yml
cp config/diaspora.yml.example config/diaspora.yml

# Copy mustahce templates
cp /tmp/database.yml.mustache config/database.yml.mustache
cp /tmp/diaspora.yml.mustache config/diaspora.yml.mustache
cp /tmp/nginx.global.mustache config/nginx.global.mustache
cp /tmp/nginx.server.mustache config/nginx.server.mustache

# Install Ruby libraries
gem install bundler
script/configure_bundler
bin/bundle install --full-index

# Install CloudFormation Helper scripts
sudo apt-get update
sudo apt-get -y install python3 python3-pip ruby-mustache
pip3 install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-py3-latest.tar.gz
