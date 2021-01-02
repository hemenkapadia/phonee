# Resources

Root directory for any resources that are generated or needed by any of the scripts in phonee.

Following directories are expected in `resources`
  * `certificate_authority` - Generated on execution of `01-CA-TLSCerts.sh`. Will contain certificates and keys for `root_ca` (the self created Certificate Authority), `intermediate_ca` (the intermediate CA that signs all leaf certificates) and `server_wildcard_cert` (a wildcard leaf certificate). The certificate chains from `leaf > intermediate` and `leaf > intermediate > root` are also created in the `server_wildcard_cert` directory.