Certificates can be generated using `gencerts.sh` script in `certificates` directory.

CA cert will be created automatically if it doesn't exist. All certificates are placed under `certificates/generated`.
Usage:
`./gencerts.sh ca apiserver` - creates api server certificates
`./gencerts.sh ca kubelet <KUBELET_IP>` - creates certificates for specified kubelet ip
`./gencerts.sh ca admin` - creates certificates for admin user. Default: 'kube-admin'.
`./gencerts.sh ca user <NAME>` - creates certificates for specified user name.

`ca-merged.crt` can be used for apache ssl reverse proxy to establish trusted connection between api server and proxy.

Config directory contains base RBAC roles needed to i.e. allow kubelet to be registered as node. Certs and `kubelect.cfg` have to be copied over to the node and passed to kubelet. Example arguments to start secure cluster with RBAC enabled can be found in `kube-components-args.sh`.

Example yamls are configured to use some preconfigured node taints.

## TODO
 - Describe how to use taints.
 - Better documentation!
