# Init

The initial userspace process bootstraps service management and receives
kernel-created root capabilities.

Init should delegate narrow authority to services instead of acting as a global
ambient authority source.

