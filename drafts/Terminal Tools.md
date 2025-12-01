# Terminal Tools

As I've been working I've been trying to find some nice little TUIs that are nice for system administration and other such things. This is a general list of things I've found use for, which I also want to remember because it's easy to forget them.

## pvw

Simple port monitor: https://github.com/allyring/pvw. Common use is `pvw -aon` which shows processes using ports with their process names, owners, address and port. Used this to try to figure out why a docker image was complaining that a port was already in use. The port was still not listed here frustratingly, but gave anm easy diagnostic.


