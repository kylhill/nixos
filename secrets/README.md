# Secrets lifecycle

The repository uses an operator age identity for editing and a separate host
identity for `pang14` activation. `.sops.yaml` commits their public recipients;
`secrets/pang14.yaml` commits encrypted system values, and `secrets/home.yaml`
commits encrypted user-scoped values shared by development Home Manager
profiles. Private identities never belong in Git, the Nix store, shell
history, logs, or chat.

## Routine editing

Use the existing, securely backed-up operator identity. Do not generate a new
identity merely to edit this repository.

```bash
nix develop
sops secrets/pang14.yaml
sops filestatus secrets/pang14.yaml
sops secrets/home.yaml
sops filestatus secrets/home.yaml
```

Keep the document schema unchanged unless the consuming Nix modules change.
The current keys are:

```text
user/password-hash
wifi/tacomafia-lan-password
wireguard/private-key
wireguard/preshared-key
ssh/private-key
ssh/public-key
syncoid-pang14-to-syntax
```

The current `secrets/home.yaml` keys are:

```text
grafana/service-account-token
```

Before committing, inspect the encrypted diff and confirm that `sops
filestatus` reports the file as encrypted. Never use `sops -d` in routine
validation or paste decrypted values into a command line.

Development Home Manager profiles decrypt `secrets/home.yaml` with the
operator identity at `~/.config/sops/age/keys.txt`. Provision that identity
outside this repository before activating the profile. MCP clients receive the
Grafana token through a runtime wrapper; the plaintext value is not written to
the Nix store or generated MCP configuration.

## Initial bootstrap or intentional key rotation

The following procedure is only for creating this setup from scratch or an
explicit recipient rotation. For rotation, preserve at least one working
recipient until the re-encrypted file has been verified and all affected hosts
have their new identity; changing `.sops.yaml` alone does not re-encrypt an
existing file.

1. Enter the repository development shell:

   ```bash
   nix develop
   ```

2. Generate identities only when suitable backed-up identities do not already
   exist. Choose secure paths and restrictive permissions:

   ```bash
   install -d -m 0700 ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   age-keygen -o /secure/location/pang14-host.txt
   age-keygen -y ~/.config/sops/age/keys.txt
   age-keygen -y /secure/location/pang14-host.txt
   ```

3. Put only the two public recipients in `.sops.yaml`. Back up both private
   identities before creating or rekeying the encrypted file. When rotating an
   existing file, run `sops updatekeys secrets/pang14.yaml` while an old
   recipient is still available, then verify access with the new operator key.

4. Create or edit the encrypted file:

   ```bash
   sops secrets/pang14.yaml
   ```

   Enter the password hash, Wi-Fi password, WireGuard keys, and shared SSH key
   pair using this structure. Generate the password hash with
   `openssl passwd -6`. Never paste private values into chat or an unencrypted
   file.

   ```yaml
   user:
     password-hash: "$6$..."
   wifi:
     tacomafia-lan-password: "..."
   wireguard:
     private-key: "..."
     preshared-key: "..."
   ssh:
     private-key: |
       -----BEGIN OPENSSH PRIVATE KEY-----
       ...
       -----END OPENSSH PRIVATE KEY-----
     public-key: "ssh-ed25519 AAAA... kyleh@shared"
   syncoid-pang14-to-syntax: |
     -----BEGIN OPENSSH PRIVATE KEY-----
     ...
     -----END OPENSSH PRIVATE KEY-----
   ```

   Keep OpenSSH private keys as YAML block scalars so their line breaks and
   final newline are preserved.

5. Verify the recovered private key before wiping the old installation:

   ```bash
   sudo sh -c 'umask 077; wg pubkey < /path/to/recovered-private-key'
   ```

   It must produce:

   ```text
   aSwGLb+DVJhHVJVyCdvFE4R6vuLvpVxPZqaOFszoljg=
   ```

6. Add only `.sops.yaml` and the encrypted `secrets/pang14.yaml` to Git. Verify
   recipient changes by reopening the file with the intended operator key and
   by checking `sops filestatus`; never commit private identities.

## Host installation and recovery

During installation, provision the backed-up host identity only after Disko
has mounted `rpool/var`. The guarded installer verifies both the dataset and
the expected public recipient before copying the private identity:

```bash
sudo ./scripts/install-host-key /secure/location/pang14-host.txt
```

Do not reboot until `/mnt/var/lib/sops-nix/key.txt` exists and the script has
reported the expected pang14 recipient.

After activation, sops-nix reads that persistent identity and writes runtime
secrets with the ownership and modes declared in `modules/nixos/`. A missing or
wrong host identity prevents secret provisioning and may leave the user account
locked because its password hash cannot be installed.

## Post-activation verification

The shared SSH key is decrypted during activation to
`/home/kyleh/.ssh/id_ed25519`, owned by `kyleh` with mode `0600`. The public
key is installed alongside it with mode `0644`. After activation, confirm the
two halves match without displaying the private key:

```bash
ssh-keygen -y -f ~/.ssh/id_ed25519 > /tmp/id_ed25519.derived.pub
diff -u <(cut -d ' ' -f 1-2 /tmp/id_ed25519.derived.pub) \
  <(cut -d ' ' -f 1-2 ~/.ssh/id_ed25519.pub)
```
