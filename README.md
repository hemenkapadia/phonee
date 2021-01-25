phonee - Phony Enterprise Environment
=====================================

`phonee` is a tool to help simulate a Phony Enterprise Environment.



Notes to be better formatted.

- Will use the [Legacy Reserved TLD] `.test` to create a local domain `phonee.test`.
- `phonee` commands adhere to the below structure
  - `phonee [component] [action] [id] [options]`
- `components` could either be `[network|ca|cert|ldap|kerberos|hadoop|....more to be added]`
- For each of these components predefined actions are available
  - `org` supports actions `[create|info]`
  - `ca` supports actions `[create|info|install_root]`
  - `cert` supports actions `[create|info]` 


TODO
- Dependencies does not install docker currently.
  - Phonee assumes docker is installed on the system.
  - It also assumes that `$USER` is added to the `docker` group
































[Legacy Reserved TLD]:  https://tools.ietf.org/id/draft-chapin-rfc2606bis-00.html#legacy