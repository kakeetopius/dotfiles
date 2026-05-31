Dotfiles managed by [chezmoi](https://chezmoi.io)

### Setup

- Install chezmoi and initialise dotfiles

```bash
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply kakeetopius
```

- Install ansible with any package manager. Or with pip

```bash
python3 -m pip install --user ansible
```

- Setup environment with ansible.

```bash
cd Dev/dev-setup
```

```bash
ansible-playbook -i hosts.yml setup-pb.yml --ask-become-password
```
