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
   age-keygen -o /secure/location/pang14.age
   age-keygen -y ~/.config/sops/age/keys.txt
   age-keygen -y /secure/location/pang14.age
   ```

3. Copy `.sops.yaml.example` to `.sops.yaml`, replace both public recipients,
   and commit `.sops.yaml`. Back up both private identities before continuing.

4. Open the new encrypted file:

   ```bash
   sops secrets/pang14.yaml
   ```

   Enter the three keys shown in `pang14.yaml.example`. Generate the password
   hash with `openssl passwd -6`. Recover the WireGuard private key and PSK
   locally; never paste them into chat or an unencrypted file.

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
