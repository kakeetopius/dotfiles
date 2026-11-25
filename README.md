Dotfiles managed by [chezmoi](https://chezmoi.io)

### Setup

- Install chezmoi and download the dotfiles

```bash
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init kakeetopius
```

- Install ansible with any package manager. Or with pip

```bash
python3 -m pip install --user ansible
```

- Setup the computer with ansible.

```bash
chezmoi cd
cd Dev/pc-setup
ansible-playbook setup-pb.yml -K --ask-vault-pass
```

- Apply the configurations

```bash
chezmoi apply
```
