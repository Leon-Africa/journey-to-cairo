#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e


print_header() {
  echo "======================================="
  echo "$1"
  echo "======================================="
}

# Install StarkNet CLI tools via curl
print_header "Installing StarkNet CLI tools (scarb, snforge, sncast)"
curl --proto '=https' --tlsv1.2 -sSf https://sh.starkup.sh | sh
scarb --version
snforge --version
sncast --version

# Verify or install asdf
print_header "Checking asdf installation"
if ! command -v asdf &> /dev/null; then
  echo "asdf not found, installing..."
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.12.0
  echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
  echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
  . ~/.asdf/asdf.sh
else
  echo "asdf is already installed"
fi
asdf --version

# Install the asdf Starknet Devnet plugin and set it up
print_header "Installing Starknet Devnet via asdf"
asdf plugin add starknet-devnet || echo "Starknet Devnet plugin already added"
asdf install starknet-devnet latest
asdf global starknet-devnet latest
asdf reshim starknet-devnet
starknet-devnet --version

# Install Node.js using nvm
print_header "Installing and configuring Node.js (v22.15.0) via nvm"
if ! command -v nvm &> /dev/null; then
  echo "nvm not found, installing..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  \. "$HOME/.nvm/nvm.sh"
else
  echo "nvm is already installed"
fi

nvm install 22
nvm use 22
node -v 
nvm current 
npm -v 


print_header "Installing global npm packages (corepack, ohyes)"
npm install -g corepack ohyes

echo "======================================="
echo "Setup completed successfully!"
echo "Verify the installed versions above."
echo "======================================="