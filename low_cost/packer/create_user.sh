#!/bin/bash

username=diaspora

set -eo pipefail

# Add diaspora user
sudo useradd -m -s /bin/bash ${username}
sudo sh -c "echo '${username} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${username}-user"
