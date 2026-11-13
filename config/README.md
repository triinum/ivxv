# Local configuration mount

Mount this directory into microservice containers at `/etc/ivxv`.

Place IVXV trust, election, and technical configuration containers here
(as used by `ivxv.ee/common/collector/command`), plus per-instance
sensitive material. Without these files the services exit after config checks.
