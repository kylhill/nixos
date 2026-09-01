# Secrets bootstrap

The repository uses an operator age identity for editing and a separate host
identity for `pang14`. Private identities never belong in Git or the Nix store.

1. Enter the repository development shell:

   ```bash
   nix develop
   ```

2. Generate or select a securely backed-up operator identity and generate the
   host identity in a secure temporary location:

   ```bash
   install -d -m 0700 ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   age-keygen -o /secure/location/pang14-host.txt
   age-keygen -y ~/.config/sops/age/keys.txt
   age-keygen -y /secure/location/pang14-host.txt
   ```

3. Copy `.sops.yaml.example` to `.sops.yaml`, replace both public recipients,
   and commit `.sops.yaml`. Back up both private identities before continuing.

4. Open the new encrypted file:

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
     private-key: |-
       -----BEGIN OPENSSH PRIVATE KEY-----
       ...
       -----END OPENSSH PRIVATE KEY-----
     public-key: "ssh-ed25519 AAAA... kyleh@shared"
   ```

   Keep the OpenSSH private key as a YAML block scalar so its line breaks are
   preserved.

5. Verify the recovered private key before wiping the old installation:

   ```bash
   sudo sh -c 'umask 077; wg pubkey < /path/to/recovered-private-key'
   ```

   It must produce:

   ```text
   aSwGLb+DVJhHVJVyCdvFE4R6vuLvpVxPZqaOFszoljg=
   ```

6. Add only `.sops.yaml` and the encrypted `secrets/pang14.yaml` to Git. A
   successful `sops filestatus secrets/pang14.yaml` must report that it is
   encrypted.

During installation, provision the backed-up host identity only after Disko
has mounted `rpool/var`. The guarded installer verifies both the dataset and
the expected public recipient before copying the private identity:

```bash
sudo ./scripts/install-host-key /secure/location/pang14-host.txt
```

Do not reboot until `/mnt/var/lib/sops-nix/key.txt` exists and the script has
reported the expected pang14 recipient.

The shared SSH key is decrypted during activation to
`/home/kyleh/.ssh/id_ed25519`, owned by `kyleh` with mode `0600`. The public
key is installed alongside it with mode `0644`. After activation, confirm the
two halves match without displaying the private key:

```bash
ssh-keygen -y -f ~/.ssh/id_ed25519 > /tmp/id_ed25519.derived.pub
diff -u <(cut -d ' ' -f 1-2 /tmp/id_ed25519.derived.pub) \
  <(cut -d ' ' -f 1-2 ~/.ssh/id_ed25519.pub)
```
